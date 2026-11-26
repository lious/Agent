import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_media/studio_media.dart';
import 'package:test/test.dart';

/// Increment 1.94 official I-015 remainingAcceptance wording
/// 「异常不穿C ABI」 at the already-admitted NativeMedia FFI bound.
/// A C++ Error is returned as a typed StudioException; the same handle
/// remains usable; close does not leave a punctured ABI. This file does
/// not rewrite native/studio_media/tests/abi_test.cpp or the Flutter
/// timeline_video_test missing-file check. It does not officialize
/// 100-cycle handle close, path/network refusal, or retain/release pairing.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

Namespace get ns => Namespace('studio', 'local', 'i015-abi-1915');

String get library => Platform.environment['STUDIO_MEDIA_LIBRARY']!;

File get fixture => File(Platform.environment['STUDIO_TEST_VIDEO']!);

void main() {
  late Directory dir;
  late File missing;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i015-abi-');
    missing = File('${dir.path}/not-a-selected-file-1915');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a synchronous native probe error becomes a typed exception and leaves the handle usable', () {
    final media = NativeMedia.open(library, ns);
    try {
      expect(() => media.probe(missing), code('LOCAL_FILE_REQUIRED'));
      final probed = media.probe(fixture);
      expect(
        (probed['streams'] as List).any((stream) => stream['type'] == 'video'),
        isTrue,
      );
    } finally {
      media.close();
    }
    expect(() => media.probe(fixture), code('NATIVE_ENGINE_CLOSED'));
  });

  test('an asynchronous native probe error becomes a typed exception and leaves the handle usable', () async {
    final media = NativeMedia.open(library, ns);
    try {
      await expectLater(media.probeAsync(missing), code('LOCAL_FILE_REQUIRED'));
      final probed = await media.probeAsync(fixture);
      expect(
        (probed['streams'] as List).any((stream) => stream['type'] == 'video'),
        isTrue,
      );
    } finally {
      media.close();
    }
    expect(() => media.probe(fixture), code('NATIVE_ENGINE_CLOSED'));
  });
}
