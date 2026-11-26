import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

/// Increment 1.94 official I-015 remainingAcceptance wording
/// 「异常不穿C ABI」 on the already-admitted SDK-exported NativeMedia path.
/// After a native error the isolate can still open a new engine and probe
/// a legal local file. This file does not rewrite abi_test.cpp,
/// timeline_video_test.dart, or officialize the other I-015 leftovers.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String get library => Platform.environment['STUDIO_MEDIA_LIBRARY']!;

File get fixture => File(Platform.environment['STUDIO_TEST_VIDEO']!);

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i015-abi-');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a native probe error does not puncture the isolate; a new engine still probes', () async {
    final missing = File('${dir.path}/not-a-selected-file-1915');
    final first = NativeMedia.open(
      library,
      Namespace('studio', 'local', 'i015-abi-1915-a'),
    );
    try {
      expect(() => first.probe(missing), code('LOCAL_FILE_REQUIRED'));
      await expectLater(first.probeAsync(missing), code('LOCAL_FILE_REQUIRED'));
    } finally {
      first.close();
    }
    expect(() => first.probe(fixture), code('NATIVE_ENGINE_CLOSED'));

    final second = NativeMedia.open(
      library,
      Namespace('studio', 'local', 'i015-abi-1915-b'),
    );
    try {
      final probed = second.probe(fixture);
      expect(
        (probed['streams'] as List).any((stream) => stream['type'] == 'video'),
        isTrue,
      );
    } finally {
      second.close();
    }
  });
}
