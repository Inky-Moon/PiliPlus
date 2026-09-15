import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('danmaku-font-test-');
    appSupportDirPath = path.join(temp.path, 'support');
    Hive.init(path.join(temp.path, 'hive'));
    GStorage.setting = await Hive.openBox<dynamic>('setting');
  });

  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('legacy cache font survives cache deletion and global font reset', () async {
    final cache = await Directory(path.join(temp.path, 'cache')).create();
    final source = await File('assets/fonts/digital_id_num.ttf').copy(
      path.join(cache.path, 'font.ttf'),
    );
    final bytes = await source.readAsBytes();
    await GStorage.setting.putAll({
      SettingBoxKey.danmakuFontPath: source.path,
      SettingBoxKey.danmakuFontFamily: 'stale-process-family',
    });

    await FontUtils.loadCustomFont();
    final savedPath = DanmakuOptions.danmakuFontPath!;
    expect(path.dirname(savedPath), path.join(appSupportDirPath, 'danmaku_fonts'));
    expect(await File(savedPath).readAsBytes(), bytes);
    expect(GStorage.setting.get(SettingBoxKey.danmakuFontPath), savedPath);
    expect(GStorage.setting.containsKey(SettingBoxKey.danmakuFontFamily), isFalse);

    await cache.delete(recursive: true);
    await FontUtils.clearFonts();
    DanmakuOptions.danmakuFontFamily = null;
    await FontUtils.loadCustomFont();
    expect(DanmakuOptions.danmakuFontFamily, startsWith('CustomDanmakuFont_'));
    expect(DanmakuOptions.danmakuFontPath, savedPath);
    expect(await File(savedPath).readAsBytes(), bytes);

    final family = DanmakuOptions.danmakuFontFamily;
    expect(await FontUtils.loadNewFont(source.path), isFalse);
    expect(DanmakuOptions.danmakuFontFamily, family);
    expect(GStorage.setting.get(SettingBoxKey.danmakuFontPath), savedPath);

    await FontUtils.resetDanmakuFont();
    await FontUtils.loadCustomFont();
    expect(DanmakuOptions.danmakuFontPath, isNull);
    expect(DanmakuOptions.danmakuFontFamily, isNull);
    expect(GStorage.setting.containsKey(SettingBoxKey.danmakuFontPath), isFalse);
  });
}
