import 'dart:ffi';
import 'dart:io' show Directory, File;
import 'dart:ui' show loadFontFromList;

import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/android/bindings.g.dart';
import 'package:PiliPlus/utils/fontconfig.g.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:jni/jni.dart';
import 'package:path/path.dart' as path;
import 'package:win32/win32.dart';

abstract final class FontUtils {
  static final _fonts = <String>{};
  static bool _initialized = false;
  static int _danmakuFontGeneration = 0;

  static const _kFontExts = ['ttf', 'ttc', 'otf'];
  static final _kFontDir = path.join(appSupportDirPath, 'font');
  // Keep danmaku fonts separate from both temporary files and global app fonts.
  static final _danmakuFontDir = path.join(appSupportDirPath, 'danmaku_fonts');
  static final _loadedFonts = <String>{};
  static final customFonts = Pref.customAppFont;

  static Future<void>? init() {
    final fontFamily = Pref.appFont;
    if (fontFamily != null && customFonts.containsKey(fontFamily)) {
      return loadFontIfNecessary(fontFamily);
    }
    return null;
  }

  static void removeFont(String fontFamily) {
    final path = customFonts.remove(fontFamily);
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        file.delete();
      }
      GStorage.setting.put(SettingBoxKey.customAppFont, customFonts);
    }
  }

  static Future<void> clearFonts() {
    customFonts.clear();
    _loadedFonts.clear();
    final dir = Directory(_kFontDir);
    return Future.wait([
      if (dir.existsSync()) dir.delete(recursive: true),
      GStorage.setting.deleteAll({
        SettingBoxKey.appFont,
        SettingBoxKey.customAppFont,
      }),
    ]);
  }

  static Future<void>? loadFontIfNecessary(String fontFamily) {
    if (_loadedFonts.contains(fontFamily)) return null;
    return _loadFont(fontFamily);
  }

  @pragma('vm:notify-debugger-on-exception')
  static Future<void> _loadFont(String fontFamily) async {
    try {
      _loadedFonts.add(fontFamily);
      final bytes = await File(customFonts[fontFamily]!).readAsBytes();
      await loadFontFromList(bytes, fontFamily: fontFamily);
    } catch (_) {}
  }

  @pragma('vm:notify-debugger-on-exception')
  static Future<String?> pickFonts() async {
    try {
      final files = await FilePicker.pickFiles(
        type: .custom,
        allowedExtensions: _kFontExts,
      );
      if (files.isNotEmpty) {
        final dir = Directory(_kFontDir);
        if (!dir.existsSync()) {
          await dir.create(recursive: true);
        }
        final futures = <Future<void>>[];
        final newFonts = <String, String>{};
        for (var file in files) {
          final now = DateTime.now().millisecondsSinceEpoch.toString();
          final name = file.xFile.name;
          final saveTo = path.join(_kFontDir, '$now-$name');

          futures.add(file.xFile.saveTo(saveTo));
          newFonts['$now/${Utils.getFileName(file.xFile.path.replaceAll('\\', '/'), fileExt: false)}'] =
              saveTo;
        }
        await Future.wait(futures);
        customFonts.addAll(newFonts);
        await GStorage.setting.put(SettingBoxKey.customAppFont, customFonts);

        final firstFont = newFonts.keys.first;
        await loadFontIfNecessary(firstFont);
        return firstFont;
      }
    } catch (_) {
      if (kDebugMode) rethrow;
    }
    return null;
  }

  static Set<String> getFont() {
    if (_initialized) return _fonts;
    _initialized = true;
    if (!switch (defaultTargetPlatform) {
      .android => _initAndroid(),
      .windows => _initWindows(),
      .linux => _initLinux(),
      _ => true,
    }) {
      // TODO: ios/macos CTFontManagerCopyAvailableFontFamilyNames
      SmartDialog.showToast('加载系统字体失败');
    }
    return _fonts;
  }

  static int _enumFontCallback(
    Pointer<LOGFONT> lpelfe,
    Pointer<TEXTMETRIC> lpntme,
    int fontType,
    int lParam,
  ) {
    final familyName = lpelfe.ref.lfFaceName;
    if (familyName.startsWith('@')) return 1;
    _fonts.add(lpelfe.ref.lfFaceName);
    return 1;
  }

  @pragma('vm:prefer-inline')
  static bool _initWindows() {
    final hdc = GetDC(null);

    final logfont = calloc<LOGFONT>();
    logfont.ref.lfCharSet = DEFAULT_CHARSET;
    logfont.ref.lfFaceName = '';

    try {
      final result = EnumFontFamiliesEx(
        hdc,
        logfont,
        Pointer.fromFunction(_enumFontCallback, 0),
        const LPARAM(0),
        0,
      );

      return result != 0;
    } finally {
      calloc.free(logfont);
      ReleaseDC(null, hdc);
    }
  }

  @pragma('vm:prefer-inline')
  static bool _initLinux() {
    final FontConfig fc;
    try {
      fc = FontConfig(DynamicLibrary.open('libfontconfig.so.1'));
    } catch (e) {
      if (kDebugMode) debugPrint('无法加载 Fontconfig 库: $e');
      return false;
    }

    final config = fc.FcInitLoadConfigAndFonts();
    if (config == nullptr) {
      if (kDebugMode) debugPrint('Fontconfig 初始化失败');
      return false;
    }

    final fontSet = fc.FcConfigGetFonts(config, FcSetName.FcSetSystem);
    if (fontSet == nullptr) {
      if (kDebugMode) debugPrint('无法获取系统字体集');
      fc.FcConfigDestroy(config);
      return false;
    }

    final nfont = fontSet.ref.nfont;
    final family = FC_FAMILY.toNativeUtf8().cast<Char>();
    for (int i = 0; i < nfont; i++) {
      final pattern = fontSet.ref.fonts[i];
      if (pattern == nullptr) continue;

      final outPtr = calloc<Pointer<UnsignedChar>>();

      try {
        final result = fc.FcPatternGetString(pattern, family, 0, outPtr);

        if (result == 0) {
          final strPtr = outPtr.value;
          if (strPtr != nullptr) {
            _fonts.add(strPtr.cast<Utf8>().toDartString());
          }
        }
      } finally {
        calloc.free(outPtr);
      }
    }
    calloc.free(family);
    fc.FcConfigDestroy(config);

    return true;
  }

  @pragma('vm:prefer-inline')
  static bool _initAndroid() {
    final fontFamilies = AndroidHelper.fontFamilies();
    if (fontFamilies != null) {
      try {
        final length = fontFamilies.length;
        for (var i = 0; i < length; i++) {
          _fonts.add(fontFamilies[i]!.toDartString(releaseOriginal: true));
        }
        return true;
      } finally {
        fontFamilies.release();
      }
    }
    return false;
  }

  /// Load custom danmaku font at startup
  static Future<void> loadCustomFont() async {
    final savedPath = Pref.danmakuFontPath;
    DanmakuOptions.danmakuFontPath = savedPath;
    // Font registrations belong to this process, not to saved settings.
    DanmakuOptions.danmakuFontFamily = null;
    if (savedPath != null && savedPath.isNotEmpty) {
      // Migrate readable legacy picker/cache paths on the first launch.
      await loadNewFont(savedPath);
    }
  }

  /// Import and register a font, persisting only a durable file path.
  static Future<bool> loadNewFont(String sourcePath) async {
    try {
      final fontData = await File(sourcePath).readAsBytes();
      final generation = ++_danmakuFontGeneration;
      final id = '${DateTime.now().microsecondsSinceEpoch}_$generation';
      var savedPath = sourcePath;
      if (!path.equals(path.dirname(sourcePath), _danmakuFontDir)) {
        await Directory(_danmakuFontDir).create(recursive: true);
        savedPath = path.join(
          _danmakuFontDir,
          '${id}_${path.basename(sourcePath)}',
        );
        await File(savedPath).writeAsBytes(fontData, flush: true);
      }

      final familyName = 'CustomDanmakuFont_$id';
      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(Future.value(ByteData.sublistView(fontData)));
      await fontLoader.load();

      await GStorage.setting.put(SettingBoxKey.danmakuFontPath, savedPath);
      await GStorage.setting.delete(SettingBoxKey.danmakuFontFamily);
      DanmakuOptions.danmakuFontPath = savedPath;
      DanmakuOptions.danmakuFontFamily = familyName;
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load new font: $e');
      return false;
    }
  }

  static Future<void> resetDanmakuFont() async {
    await GStorage.setting.deleteAll([
      SettingBoxKey.danmakuFontPath,
      SettingBoxKey.danmakuFontFamily,
    ]);
    DanmakuOptions.danmakuFontPath = null;
    DanmakuOptions.danmakuFontFamily = null;
  }
}
