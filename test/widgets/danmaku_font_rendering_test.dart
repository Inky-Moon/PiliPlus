import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:canvas_danmaku/scroll_danmaku_painter.dart';
import 'package:canvas_danmaku/special_danmaku_painter.dart';
import 'package:canvas_danmaku/static_danmaku_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('font changes invalidate images and reach every painter', (tester) async {
    late DanmakuController<void> controller;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'GlobalAppFont'),
        home: SizedBox(
          width: 600,
          height: 400,
          child: DanmakuScreen<void>(
            size: const Size(600, 400),
            option: const DanmakuOption(fontFamily: 'DanmakuA'),
            createdController: (value) => controller = value,
          ),
        ),
      ),
    );
    expect(controller.addDanmaku(DanmakuContentItem<void>('scroll')), isTrue);
    expect(
      controller.addDanmaku(DanmakuContentItem<void>('top', type: DanmakuItemType.top)),
      isTrue,
    );
    controller.pause();
    final scroll = controller.scrollDanmaku.expand((items) => items).single;
    final top = controller.staticDanmaku.nonNulls.single;

    void expectPainterFonts(String? family) {
      final painters = tester.widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter);
      expect(painters.whereType<ScrollDanmakuPainter>().single.fontFamily, family);
      expect(painters.whereType<StaticDanmakuPainter>().single.fontFamily, family);
      expect(painters.whereType<SpecialDanmakuPainter>().single.fontFamily, family);
    }

    expectPainterFonts('DanmakuA');
    for (final option in const [
      DanmakuOption(fontFamily: 'DanmakuB'),
      DanmakuOption(fontFamily: 'DanmakuB', fontSize: 20, fontWeight: 6),
      DanmakuOption(fontFamily: 'DanmakuC', lineHeight: 1.8),
      DanmakuOption(),
    ]) {
      expect(scroll.image, isNotNull);
      expect(top.image, isNotNull);
      controller.updateOption(option);
      expect(scroll.image, isNull);
      expect(top.image, isNull);
      await tester.pump();
      expectPainterFonts(option.fontFamily);
      expect(scroll.image, isNotNull);
      expect(top.image, isNotNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
