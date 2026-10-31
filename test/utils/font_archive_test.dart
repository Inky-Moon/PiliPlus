import 'dart:io';

import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/font_archive.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;

  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('font-archive-test-');
    appSupportDirPath = path.join(temp.path, 'support');
    Hive.init(path.join(temp.path, 'hive'));
    GStorage.setting = await Hive.openBox<dynamic>('setting');
  });

  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  test('round trip rebases all app fonts and the independent danmaku font', () async {
    final appBytes = await File('assets/fonts/digital_id_num.ttf').readAsBytes();
    final dmBytes = await File('assets/fonts/custom_icon.ttf').readAsBytes();
    const family = '../../archive/custom';
    await FontUtils.importAppFont(family, appBytes);
    await FontUtils.importAppFont('another/font', dmBytes);
    await GStorage.setting.put(SettingBoxKey.appFont, family);
    expect(await FontUtils.importDanmakuFont(dmBytes), isTrue);
    final oldDmPath = DanmakuOptions.danmakuFontPath!;
    final settings = {
      SettingBoxKey.appFont: family,
      SettingBoxKey.customAppFont: Map<String, String>.of(FontUtils.customFonts),
      SettingBoxKey.danmakuFontPath: oldDmPath,
    };

    final out = OutputMemoryStream();
    final zip = ZipEncoder()..startEncode(out);
    for (final file in FontArchive.exportFiles()) {
      zip.add(file);
    }
    zip.endEncode();
    final archive = ZipDecoder().decodeBytes(out.getBytes());
    expect(archive.find(FontUtils.kFontName), isNotNull);

    await FontUtils.clearFonts();
    await FontUtils.resetDanmakuFont();
    await File(oldDmPath).delete();
    await GStorage.setting.putAll(settings);
    expect(await FontArchive.restore(archive), isEmpty);
    expect(FontUtils.customFonts, hasLength(2));
    for (final fontPath in FontUtils.customFonts.values) {
      expect(path.dirname(fontPath), path.join(appSupportDirPath, 'font'));
    }
    expect(await File(FontUtils.customFonts[family]!).readAsBytes(), appBytes);
    final dmPath = DanmakuOptions.danmakuFontPath!;
    expect(dmPath, isNot(oldDmPath));
    expect(await File(dmPath).readAsBytes(), dmBytes);
    expect(GStorage.setting.containsKey(SettingBoxKey.danmakuFontFamily), isFalse);

    await FontUtils.clearFonts();
    expect(await File(dmPath).readAsBytes(), dmBytes);
    await FontUtils.loadCustomFont();
    expect(DanmakuOptions.danmakuFontFamily, startsWith('CustomDanmakuFont_'));
    out.closeSync();
  });

  test('imports upstream single-font archives into the multi-font model', () async {
    final bytes = await File('assets/fonts/digital_id_num.ttf').readAsBytes();
    final archive = Archive()
      ..addFile(ArchiveFile(FontUtils.kFontName, bytes.length, bytes));
    await GStorage.setting.put(SettingBoxKey.appFont, 'upstream/font');
    expect(await FontArchive.restore(archive), isEmpty);
    final fontPath = FontUtils.customFonts['upstream/font']!;
    expect(path.dirname(fontPath), path.join(appSupportDirPath, 'font'));
    expect(await File(fontPath).readAsBytes(), bytes);
  });
}
