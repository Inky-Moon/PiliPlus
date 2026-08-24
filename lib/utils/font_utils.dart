import 'dart:ffi';
import 'dart:io';

import 'package:PiliPlus/utils/android/bindings.g.dart';
import 'package:PiliPlus/utils/fontconfig.g.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:jni/jni.dart';
import 'package:win32/win32.dart';

import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';

abstract final class FontUtils {
  static final _fonts = <String>{};
  static bool _initialized = false;
  static bool _customFontLoaded = false;
  static String? _loadedCustomFontPath;

  /// Get built-in system fonts (Upstream implementation)
  static Set<String> getFont() {
    if (_initialized) return _fonts;
    _initialized = true;
    if (!((Platform.isAndroid && _initAndroid()) ||
        (Platform.isWindows && _initWindows()) ||
        (Platform.isLinux && _initLinux()))) {
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
    final path = Pref.danmakuFontPath;
    if (path == null || path.isEmpty) {
      DanmakuOptions.danmakuFontFamily = null;
      return;
    }

    if (_customFontLoaded && _loadedCustomFontPath == path) {
      // Already loaded
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      DanmakuOptions.danmakuFontFamily = null;
      return;
    }

    try {
      final fontData = await file.readAsBytes();
      final byteData = ByteData.view(fontData.buffer);
      // Generate unique family name to prevent caching old font
      final familyName = 'CustomDanmakuFont_${DateTime.now().millisecondsSinceEpoch}';
      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(Future.value(byteData));
      await fontLoader.load();
      DanmakuOptions.danmakuFontFamily = familyName;
      _loadedCustomFontPath = path;
      _customFontLoaded = true;
      return;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load custom font: $e');
      DanmakuOptions.danmakuFontFamily = null;
    }
  }

  /// Load custom danmaku font at runtime (when file picker is used)
  static Future<bool> loadNewFont(String path) async {
    final file = File(path);
    if (!file.existsSync()) return false;

    try {
      final fontData = await file.readAsBytes();
      final byteData = ByteData.view(fontData.buffer);
      // Generate a new random family name to avoid caching issues when swapping fonts
      final familyName = 'CustomDanmakuFont_${DateTime.now().millisecondsSinceEpoch}';
      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(Future.value(byteData));
      await fontLoader.load();
      
      DanmakuOptions.danmakuFontFamily = familyName;
      _loadedCustomFontPath = path;
      _customFontLoaded = true;
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load new font: $e');
      return false;
    }
  }
}
