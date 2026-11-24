import 'dart:convert' show jsonDecode, utf8;
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:PiliPlus/models_new/video/video_play_info/subtitle.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/extension/file_ext.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:dio/dio.dart' show Options;
import 'package:path/path.dart' as path;

enum SubtitleFormat implements EnumWithLabel {
  json('JSON'),
  vtt('WEBVTT'),
  srt('SRT');

  @override
  final String label;
  const SubtitleFormat(this.label);
}

abstract final class SubtitleUtils {
  static const String _json = '.json';
  static const String _bcc = '.bcc';
  static bool isJson(String fileName) {
    final name = fileName.toLowerCase();
    return name.endsWith(_json) ||
        name.endsWith(_bcc) ||
        name.endsWith(PathUtils.subtitleExt);
  }

  // FilePicker expects extension names without a leading dot.
  static const exts = ['json', 'vtt', 'srt', 'ass', 'bcc', 'subtitle'];

  static String _vttTimecode(num seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    seconds %= 3600;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    seconds %= 60;
    final sms = seconds.toStringAsFixed(3).padLeft(6, '0');
    return "$h:$m:$sms";
  }

  static String json2Vtt(List list) {
    final sb = StringBuffer('WEBVTT\n\n')
      ..writeAll(
        list.map(
          (item) =>
              '${_vttTimecode(item['from'])} --> ${_vttTimecode(item['to'])}\n${item['content'].trim()}',
        ),
        '\n\n',
      );
    return sb.toString();
  }

  static String _srtTimecode(num seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    seconds %= 3600;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    seconds %= 60;
    final s = seconds.toInt();
    final ms = ((seconds - s) * 1000).round().toString().padLeft(3, '0');
    return '$h:$m:${s.toString().padLeft(2, '0')},$ms';
  }

  static String json2Srt(List list) {
    final sb = StringBuffer()
      ..writeAll(
        list.mapIndexed(
          (i, e) =>
              '${i + 1}\n${_srtTimecode(e['from'])} --> ${_srtTimecode(e['to'])}\n${e['content'].trim()}',
        ),
        '\n\n',
      );
    return sb.toString();
  }

  static Future<Uint8List?> getSubtitle(String url) async {
    final res = await Request.dio.get<Uint8List>(
      url.http2https,
      options: Options(
        responseType: .bytes,
        headers: Constants.baseHeaders,
        extra: {'account': const NoAccount()},
      ),
    );
    if (res.statusCode != 200) return null;
    return Uint8List.fromList(
      Request.responseBytesDecoder(res.data!, res.headers.map),
    );
  }

  static Future<List<LocalSubtitle>> cacheSubtitles(
    String entryDirPath,
    List<Subtitle> subtitles, {
    Future<Uint8List?> Function(String) fetch = getSubtitle,
  }) async {
    final tracks = [for (final sub in subtitles) sub.toLocal(entryDirPath)];
    if (tracks.isEmpty) return tracks;
    if (tracks.map((track) => track.path).toSet().length != tracks.length) {
      throw const FormatException('字幕文件 ID 重复');
    }
    final dir = await File(tracks.first.path).parent.create(recursive: true);
    final staging = await dir.createTemp('.subtitles-');
    try {
      for (final (index, sub) in subtitles.indexed) {
        final url = sub.subtitleUrl;
        if (url == null || url.isEmpty) {
          throw const FormatException('缺少字幕地址');
        }
        final bytes = await fetch(url);
        if (bytes == null || bytes.isEmpty) throw const FormatException('字幕为空');
        final document = jsonDecode(utf8.decode(bytes));
        if (document is! Map || document['body'] is! List) {
          throw const FormatException('离线字幕缺少正文');
        }
        final file = File(path.join(staging.path, '$index'));
        await file.writeAsBytes(bytes, flush: true);
      }
      // Existing tracks stay readable throughout a refresh or a failed fetch.
      for (final (index, track) in tracks.indexed) {
        await File(path.join(staging.path, '$index')).rename(track.path);
      }
      return tracks;
    } finally {
      await staging.tryDel(recursive: true);
    }
  }
}
