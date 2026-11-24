import 'dart:async';

import 'package:PiliPlus/models_new/live/live_trace/data.dart';
import 'package:PiliPlus/utils/live_trace_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const response = LiveTraceResp(
    timestamp: 1,
    interval: 3,
    secretKey: '',
    secretRule: [],
  );

  testWidgets('a slow response cannot overlap or restart a stopped session', (tester) async {
    final session = LiveTraceSession();
    final pending = Completer<LiveTraceResp?>();
    var calls = 0;
    final done = session.run(
      canSend: () => true,
      send: (_) {
        calls++;
        return pending.future;
      },
    );
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 1);
    session.stop();
    pending.complete(response);
    await done;
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 1);
  });

  testWidgets('follows the returned interval while reporting is enabled', (tester) async {
    final session = LiveTraceSession();
    final sent = <LiveTraceResp?>[];
    var enabled = true;
    final done = session.run(
      canSend: () => enabled,
      send: (previous) async {
        sent.add(previous);
        return response;
      },
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(sent, [null]);
    await tester.pump(const Duration(seconds: 1));
    expect(sent, [null, response]);
    enabled = false;
    await tester.pump(const Duration(seconds: 3));
    await done;
    expect(sent, [null, response]);
  });
}
