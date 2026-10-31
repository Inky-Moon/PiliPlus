import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:archive/archive.dart';

/// Portable font payloads for the fork's multi-font and independent danmaku setup.
abstract final class FontArchive {
  static const manifestName = 'app_fonts.json';
  static const danmakuName = 'danmaku_font.otf';

  static List<ArchiveFile> exportFiles() {
    final files = <ArchiveFile>[];
    final manifest = <String, String>{};
    for (final entry in FontUtils.customFonts.entries) {
      if (!File(entry.value).existsSync()) continue;
      // Keep the selected app font readable by upstream's single-font archives.
      final name = entry.key == Pref.appFont
          ? FontUtils.kFontName
          : 'app_fonts/${manifest.length}.otf';
      manifest[entry.key] = name;
      files.add(ArchiveFile.stream(name, InputFileStream(entry.value)));
    }
    files.add(ArchiveFile.string(manifestName, jsonEncode(manifest)));
    final danmakuPath = Pref.danmakuFontPath;
    if (danmakuPath != null && File(danmakuPath).existsSync()) {
      files.add(ArchiveFile.stream(danmakuName, InputFileStream(danmakuPath)));
    }
    return files;
  }

  /// The caller validates the archive size before importing any settings/files.
  static Future<String> restore(Archive archive) async {
    FontUtils.reloadCustomFonts();
    final warnings = StringBuffer();
    final Map<String, String> fonts;
    final manifest = archive.find(manifestName);
    if (manifest != null) {
      fonts = Map<String, String>.from(jsonDecode(utf8.decode(manifest.content)));
    } else {
      // Upstream backups contain only the active app font, without a manifest.
      final family = Pref.appFont;
      fonts = {
        if (family != null && archive.find(FontUtils.kFontName) != null)
          family: FontUtils.kFontName,
      };
    }
    for (final entry in fonts.entries) {
      try {
        final file = archive.find(entry.value);
        if (file == null || !file.isFile) {
          throw FormatException('缺少字体文件');
        }
        await FontUtils.importAppFont(entry.key, file.content);
      } catch (e) {
        warnings.writeln('${entry.key}：$e');
      }
    }
    final danmaku = archive.find(danmakuName);
    if (danmaku != null) {
      try {
        if (!await FontUtils.importDanmakuFont(danmaku.content)) {
          throw FormatException('无法加载弹幕字体');
        }
      } catch (e) {
        warnings.writeln('$danmakuName：$e');
      }
    }
    return warnings.toString();
  }
}
