import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_media/studio_media.dart';
import 'package:test/test.dart';

/// Increment 1.95 official I-021 remainingAcceptance wording
/// 「取消epoch前帧不回流预览」 at the already-admitted NativeMedia preview
/// bound. An in-flight unindexed preview is refused as CANCELED when
/// cancel() advances the engine epoch; a later legal preview still
/// succeeds on the same handle and is not the canceled request. This
/// file does not rewrite abi_test.cpp or source_preview_test.dart.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  final library = Platform.environment['STUDIO_MEDIA_LIBRARY']!,
      fixture = Platform.environment['STUDIO_TEST_VIDEO']!;

  test('canceling an in-flight preview returns CANCELED and a later preview still succeeds', () async {
    final root = Directory.systemTemp.createTempSync('i021-cancel-preview-');
    final media = NativeMedia.open(
      library,
      Namespace('studio', 'local', 'i021-cancel-preview'),
    );
    try {
      final longInput = File('${root.path}/long.mp4');
      expect(
        Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-stream_loop',
          '10',
          '-i',
          fixture,
          '-t',
          '33',
          '-c',
          'copy',
          longInput.path,
        ]).exitCode,
        0,
      );
      final before = media.cancelEpoch;
      final pending = media.previewAsync(
        longInput,
        Q.of(30),
        indexed: false,
      );
      // Sequential decode of a late timestamp must actually start before
      // cancel is qualified. Yield so the isolate can enter sm_preview.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      media.cancel();
      expect(media.cancelEpoch, greaterThan(before));
      await expectLater(pending, code('CANCELED'));

      final later = await media.previewAsync(File(fixture), Q.of(0));
      expect(later['pts'], isNotNull);
      expect(later['rgba'], isNotEmpty);
    } finally {
      media.close();
      root.deleteSync(recursive: true);
    }
  });
}
