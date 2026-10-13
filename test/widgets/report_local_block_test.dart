import 'package:PiliPlus/common/widgets/dialog/report.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('local danmaku blocking accepts a non-numeric sender hash', (tester) async {
    const senderHash = '9af01c2e';
    final blockedHashes = <String>{};
    var reports = 0;
    var removals = 0;
    await tester.pumpWidget(GetMaterialApp(
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => autoWrapReportDialog(
            context,
            const {'': {1: '垃圾广告'}},
            (reason, content, banUid) async {
              reports++;
              return const Success(null);
            },
            onLocalBlock: () => blockedHashes.add(senderHash),
            onRemove: () => removals++,
          ),
          child: const Text('举报弹幕'),
        ),
      )),
    ));
    await tester.tap(find.text('举报弹幕'));
    await tester.pumpAndSettle();
    expect(find.textContaining('拉黑该用户'), findsOneWidget);
    await tester.tap(find.text('本地屏蔽'));
    await tester.pumpAndSettle();
    expect(blockedHashes, {senderHash});
    expect(removals, 1);
    expect(reports, 0);
    expect(find.text('本地屏蔽'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    Get.reset();
  });
}
