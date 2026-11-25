import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_sdk/frame_proxy.dart';

void main() {
  test('REAL native generated CFR/VFR/nonzero-PTS proxies equal sequential decoder at20 exact points', () async {
    final root = Directory.systemTemp.createTempSync('native-frame-proxy-'),
        media = NativeMedia.open(
          Platform.environment['STUDIO_MEDIA_LIBRARY']!,
          Namespace('proxy', 'test', 'local'),
        );
    try {
      final input = File(Platform.environment['STUDIO_TEST_VIDEO']!),
          offset = File('${root.path}/offset.mp4'),
          vfr = File('${root.path}/vfr.mp4');
      expect(
        Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-i',
          input.path,
          '-c',
          'copy',
          '-output_ts_offset',
          '7',
          offset.path,
        ]).exitCode,
        0,
      );
      expect(
        Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-i',
          input.path,
          '-vf',
          "setpts='if(lt(N,45),N,45+(N-45)*2)/(30*TB)'",
          '-fps_mode',
          'vfr',
          '-c:v',
          'libx264',
          '-g',
          '15',
          '-an',
          vfr.path,
        ]).exitCode,
        0,
      );
      for (final source in [input, offset, vfr]) {
        final dir = Directory(
          '${root.path}/p-${source == input
              ? 0
              : source == offset
              ? 1
              : 2}',
        )..createSync();
        final facts = await media.buildPreviewProxyAsync(
          source,
          File('${dir.path}/frames.rgba'),
        );
        for (final bad in <Map<String, dynamic>>[
          {...facts, 'startPts': '9' * 1000},
          {
            ...facts,
            'frames': [null],
          },
          {
            ...facts,
            'frames': [
              {'pts': facts['startPts'], 'duration': '0'},
            ],
          },
          {...facts, 'width': 129},
          {...facts, 'bytes': -1},
        ]) {
          await expectLater(
            FrameProxy.admit(dir, bad),
            throwsA(isA<StudioException>()),
          );
        }
        final proxy = await FrameProxy.admit(dir, facts);
        try {
          expect(proxy.pts.length, 90);
          expect(proxy.bytes, 90 * 128 * 72 * 4);
          for (final n in [
            0,
            89,
            15,
            44,
            3,
            63,
            29,
            60,
            1,
            88,
            30,
            17,
            52,
            70,
            4,
            40,
            12,
            81,
            7,
            66,
          ]) {
            final time =
                Q(proxy.pts[n] - proxy.startPts, BigInt.one) * proxy.timeBase;
            expect(proxy.indexAt(time), n);
            final frame = await proxy.read(n),
                reference = SourcePreviewFrame(
                  await media.previewAsync(source, time, indexed: false),
                );
            expect(frame.pts, reference.pts);
            expect(rawBytesHash(frame.rgba), rawBytesHash(reference.rgba));
          }
          if (source == offset) {
            expect(proxy.startPts, greaterThan(BigInt.zero));
          }
          if (source == vfr) {
            expect(
              Q(
                    proxy.pts[proxy.indexAt(Q.of(8, 5))] - proxy.startPts,
                    BigInt.one,
                  ) *
                  proxy.timeBase,
              Q.of(47, 30),
            );
          }
          expect(
            () => proxy.indexAt(Q.of(-1)),
            throwsA(isA<StudioException>()),
          );
          expect(
            () => proxy.indexAt(Q.of(100)),
            throwsA(isA<StudioException>()),
          );
          final corrupt = proxy.file.readAsBytesSync();
          corrupt[0] ^= 1;
          proxy.file.writeAsBytesSync(corrupt);
          await expectLater(
            proxy.read(0),
            throwsA(
              isA<StudioException>().having(
                (e) => e.code,
                'code',
                'PROXY_FRAME_HASH_MISMATCH',
              ),
            ),
          );
        } finally {
          proxy.dispose();
        }
      }
    } finally {
      media.close();
      root.deleteSync(recursive: true);
    }
  });
  test('REAL proxy cancel removes partial native output and permits subsequent fresh build', () async {
    final root = Directory.systemTemp.createTempSync('cancel-frame-proxy-'),
        media = NativeMedia.open(
          Platform.environment['STUDIO_MEDIA_LIBRARY']!,
          Namespace('proxy', 'cancel', 'local'),
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
          Platform.environment['STUDIO_TEST_VIDEO']!,
          '-t',
          '33',
          '-c',
          'copy',
          longInput.path,
        ]).exitCode,
        0,
      );
      final output = File('${root.path}/frames.rgba');
      final pending = media.buildPreviewProxyAsync(longInput, output);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (!output.existsSync() || output.lengthSync() == 0) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Native proxy did not enter actual output phase');
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(
        output.lengthSync(),
        lessThan(990 * 128 * 72 * 4),
        reason: 'Cancellation qualification must observe real partially written output, not a completed file',
      );
      media.cancel();
      await expectLater(
        pending,
        throwsA(
          isA<StudioException>().having((e) => e.code, 'code', 'CANCELED'),
        ),
      );
      expect(
        output.existsSync(),
        isFalse,
        reason: 'partial native proxy must be removed',
      );
      final facts = await media.buildPreviewProxyAsync(
        File(Platform.environment['STUDIO_TEST_VIDEO']!),
        output,
      );
      expect(facts['frames'], hasLength(90));
      // The adopted cap is not a license to generate an unbounded staging file.
      output.deleteSync();
      final oversize = File('${root.path}/oversize.mp4');
      expect(
        Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-stream_loop',
          '24',
          '-i',
          Platform.environment['STUDIO_TEST_VIDEO']!,
          '-t',
          '70',
          '-c',
          'copy',
          oversize.path,
        ]).exitCode,
        0,
      );
      await expectLater(
        media.buildPreviewProxyAsync(oversize, output),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'PROXY_BYTE_LIMIT',
          ),
        ),
      );
      expect(output.existsSync(), isFalse);
    } finally {
      media.close();
      root.deleteSync(recursive: true);
    }
  });
}
