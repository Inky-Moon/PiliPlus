import 'dart:io';
import 'package:flutter/services.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';

abstract final class FontUtils {
  static bool _fontLoaded = false;
  static String? _loadedFontPath;

  /// Call this when the app starts or when video player initializes
  static Future<void> loadCustomFont() async {
    final path = Pref.danmakuFontPath;
    if (path == null || path.isEmpty) {
      DanmakuOptions.danmakuFontFamily = null;
      return;
    }

    if (_fontLoaded && _loadedFontPath == path) {
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
      _loadedFontPath = path;
      _fontLoaded = true;
      return;
    } catch (e) {
      print('Failed to load custom font: $e');
      DanmakuOptions.danmakuFontFamily = null;
    }
  }

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
      _loadedFontPath = path;
      _fontLoaded = true;
      return true;
    } catch (e) {
      print('Failed to load new font: $e');
      return false;
    }
  }
}
