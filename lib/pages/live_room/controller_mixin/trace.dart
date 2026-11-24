part of 'package:PiliPlus/pages/live_room/controller.dart';

mixin _LiveTraceMixin on GetxController, _LiveDataMixin {
  LiveTraceSession? _liveTraceSession;
  bool _liveTraceRequested = true;

  bool get _canTrace =>
      _liveTraceRequested &&
      !isClosed &&
      plPlayerController.visible &&
      plPlayerController.playerStatus.isPlaying &&
      heartbeat.isLogin &&
      !Pref.historyPause;

  void _startLiveTraceTimer() {
    _liveTraceRequested = true;
    _initLiveTraceIfNeeded();
  }

  void _stopLiveTraceTimer() {
    _liveTraceRequested = false;
    _liveTraceSession?.stop();
    _liveTraceSession = null;
  }

  Future<void> _initLiveTraceIfNeeded() async {
    if (_liveTraceSession != null || !_canTrace || !isLoaded.value) return;
    final roomInfo = roomInfoH5.rawValue?.roomInfo;
    final ruid = this.ruid;
    final parentAreaId = roomInfo?.parentAreaId;
    final areaId = roomInfo?.areaId;
    if (ruid == null || parentAreaId == null || areaId == null) return;

    final session = LiveTraceSession();
    _liveTraceSession = session;
    try {
      final cookies = await heartbeat.cookieJar.loadForRequest(
        Uri.parse(HttpString.baseUrl),
      );
      if (_liveTraceSession != session) return;
      final liveBuvid = cookies
          .firstWhereOrNull((cookie) => cookie.name == 'LIVE_BUVID')
          ?.value;
      if (liveBuvid == null) throw StateError('liveTrace: missing LIVE_BUVID');

      final request = LiveTraceReq(
        parentAreaId: parentAreaId,
        areaId: areaId,
        roomId: roomId,
        liveBuvid: liveBuvid,
        ruid: ruid,
      );
      await session.run(
        canSend: () => _canTrace,
        send: (previous) async {
          final res = previous == null
              ? await LiveHttp.liveTraceE(traceReq: request, heartbeat: heartbeat)
              : await LiveHttp.liveTraceX(
                  traceReq: request,
                  traceResp: previous,
                  heartbeat: heartbeat,
                );
          if (!res.isSuccess && _liveTraceSession == session) {
            Utils.reportError('live trace error: $res');
          }
          return res.dataOrNull;
        },
      );
    } catch (e, s) {
      if (_liveTraceSession == session) Utils.reportError(e, s);
    } finally {
      if (_liveTraceSession == session) _liveTraceSession = null;
    }
  }
}
