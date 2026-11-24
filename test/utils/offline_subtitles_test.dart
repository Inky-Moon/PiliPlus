import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/models_new/video/video_play_info/subtitle.dart';
import 'package:PiliPlus/utils/subtitle_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List payload(String text) => Uint8List.fromList(utf8.encode(jsonEncode({
  'body': [
    {'from': 0, 'to': 1, 'content': text},
  ],
})));

void main() {
  late Directory temp;
  final first = Subtitle(id: 3, lan: 'zh', subtitleUrl: 'first');
  final second = Subtitle(id: 5, lan: 'en', subtitleUrl: 'second');

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pili-offline-subs-');
  });
  tearDown(() => temp.delete(recursive: true));

  test('waits for all tracks before publishing files and metadata', () async {
    final started = Completer<void>();
    final pending = Completer<Uint8List?>();
    final saving = SubtitleUtils.cacheSubtitles(
      temp.path,
      [first, second],
      fetch: (url) async {
        if (url == 'first') return payload('first');
        started.complete();
        return pending.future;
      },
    );
    await started.future;
    expect(File(first.toPath(temp.path)).existsSync(), isFalse);
    pending.complete(payload('second'));

    final saved = await saving;
    final restored = LocalSubtitle.fromCache(
      [for (final track in saved) track.toJson()],
      temp.path,
    )!;
    expect(restored.map((s) => s.id), [3, 5]);
    expect(await File(restored.first.path).readAsBytes(), payload('first'));
    expect(await File(restored.last.path).readAsBytes(), payload('second'));
    expect(LocalSubtitle.fromCache(null, temp.path), isNull);
  });

  test('partial refresh preserves the existing offline track', () async {
    await SubtitleUtils.cacheSubtitles(
      temp.path,
      [first],
      fetch: (_) async => payload('original'),
    );
    for (final invalid in [null, Uint8List.fromList(utf8.encode('{}'))]) {
      await expectLater(
        SubtitleUtils.cacheSubtitles(
          temp.path,
          [first, second],
          fetch: (url) async => url == 'first' ? payload('new') : invalid,
        ),
        throwsFormatException,
      );
    }
    expect(await File(first.toPath(temp.path)).readAsBytes(), payload('original'));
    expect(File(second.toPath(temp.path)).existsSync(), isFalse);
  });
}
