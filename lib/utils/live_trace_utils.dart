import 'dart:async' show Completer, Timer;
import 'dart:convert' show utf8, jsonEncode;

import 'package:PiliPlus/models_new/live/live_trace/data.dart';
import 'package:crypto/crypto.dart'
    show Hmac, md5, sha1, sha256, sha224, sha512, sha384, Hash;
import 'package:flutter/foundation.dart' show kDebugMode;

/// One viewing session. Only a completed heartbeat can schedule the next one.
class LiveTraceSession {
  bool _stopped = false;
  Timer? _timer;
  Completer<void>? _waiting;

  void stop() {
    _stopped = true;
    _timer?.cancel();
    final waiting = _waiting;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  Future<void> run({
    required bool Function() canSend,
    required Future<LiveTraceResp?> Function(LiveTraceResp?) send,
  }) async {
    LiveTraceResp? previous;
    while (!_stopped && canSend()) {
      previous = await send(previous);
      if (_stopped || previous == null || !canSend()) return;

      final interval = previous.interval > 0
          ? previous.interval
          : LiveTraceResp.kInterval;
      final waiting = Completer<void>();
      _waiting = waiting;
      _timer = Timer(Duration(seconds: interval), () => waiting.complete());
      await waiting.future;
      _waiting = null;
      _timer = null;
    }
  }
}

abstract final class LiveTraceUtils {
  static String? _hmacByRule(
    List<int> data,
    String secretKey,
    int rule,
  ) {
    final Hash hash;

    switch (rule) {
      case 0:
        hash = md5;
      case 1:
        hash = sha1;
      case 2:
        hash = sha256;
      case 3:
        hash = sha224;
      case 4:
        hash = sha512;
      case 5:
        hash = sha384;
      case _:
        if (kDebugMode) {
          throw UnsupportedError('secret_rule: $rule');
        }
        return null;
    }

    return Hmac(hash, utf8.encode(secretKey)).convert(data).toString();
  }

  static String? buildX25KnSignature({
    required LiveTraceReq traceReq,
    required LiveTraceResp traceResp,
    required int tsMs,
  }) {
    final payload = {
      'platform': 'web',
      'parent_id': traceReq.parentAreaId,
      'area_id': traceReq.areaId,
      'seq_id': traceReq.seqId,
      'room_id': traceReq.roomId,
      'buvid': traceReq.liveBuvid,
      'uuid': traceReq.liveUuid,
      'ets': traceResp.timestamp,
      'time': traceResp.interval,
      'ts': tsMs,
    };

    var current = utf8.encode(jsonEncode(payload));

    for (final rule in traceResp.secretRule) {
      final newVal = _hmacByRule(current, traceResp.secretKey, rule);
      if (newVal == null) return null;
      current = utf8.encode(newVal);
    }

    return utf8.decode(current);
  }
}
