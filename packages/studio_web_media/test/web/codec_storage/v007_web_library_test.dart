import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_web_media/studio_web_media.dart';
import 'package:test/test.dart';

/// Increment 2.49 official V-007 first slice: two JS demux/mux lockfile
/// candidates, license/API facts, and a browser feature matrix. This
/// file does not claim a 60s WebCodecs/OPFS roundtrip, does not pin a
/// production lock, does not vendor or download JS packages, does not
/// import native FFmpeg as a fake general Web path, does not default
/// to ffmpeg.wasm, does not mark I-037 or I-038 complete, and does not
/// rewrite the Increment 2.37 I-020 suite or the frozen I-036
/// fts5Enabled==false assertions.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

void main() {
  test('the official catalog records exactly two lockfile candidates with version and license facts, excludes ffmpeg.wasm and native FFmpeg, and does not pin or claim a 60s roundtrip', () {
    final compiler = WebLibraryCompiler();
    final program = compiler.catalog();
    expect(program.candidates, hasLength(2));
    expect(program.candidates.map((c) => c.id), [
      mp4boxCandidate.id,
      mediabunnyCandidate.id,
    ]);
    final mp4box = program.candidates.singleWhere((c) => c.id == 'mp4box');
    expect(mp4box.npmPackage, 'mp4box');
    expect(mp4box.version, '2.6.0');
    expect(mp4box.license, 'BSD-3-Clause');
    expect(mp4box.role, WebLibraryRole.demux);
    expect(
      mp4box.apiFacts,
      containsAll(['MP4Box.createFile', 'onSamples', 'seek']),
    );
    expect(mp4box.isFfmpegWasm, isFalse);
    expect(mp4box.isNativeFfmpeg, isFalse);
    expect(mp4box.productionPinned, isFalse);

    final mediabunny = program.candidates.singleWhere(
      (c) => c.id == 'mediabunny',
    );
    expect(mediabunny.npmPackage, 'mediabunny');
    expect(mediabunny.version, '1.66.5');
    expect(mediabunny.license, 'MPL-2.0');
    expect(mediabunny.role, WebLibraryRole.demuxAndMux);
    expect(
      mediabunny.apiFacts,
      containsAll(['Input', 'Output', 'Mp4OutputFormat']),
    );
    expect(mediabunny.isFfmpegWasm, isFalse);
    expect(mediabunny.isNativeFfmpeg, isFalse);
    expect(mediabunny.productionPinned, isFalse);

    expect(program.candidates.any((c) => c.id == 'mp4-muxer'), isFalse);
    expect(deprecatedMp4Muxer.deprecated, isTrue);
    expect(program.roundtripQualified, isFalse);
    expect(program.productionPinned, isFalse);
    expect(program.nativeFfmpegImported, isFalse);
    expect(program.ffmpegWasmDefault, isFalse);
    expect(program.packageDownloaded, isFalse);
    expect(program.submitted, isFalse);
    expect(program.documentWrites, 0);
    expect(compiler.documentWrites, 0);
  });

  test('Chrome and Edge are first-batch targets but stay unqualified; Safari and Firefox unverified features are BROWSER_FEATURE_UNVERIFIED and do not submit', () {
    final compiler = WebLibraryCompiler();
    final matrix = compiler.catalog().featureMatrix;
    expect(
      matrix
          .where(
            (r) =>
                r.browser == WebBrowser.chrome || r.browser == WebBrowser.edge,
          )
          .every((r) => r.firstBatchTarget && !r.qualified && !r.admitted),
      isTrue,
    );
    expect(
      matrix
          .where(
            (r) =>
                r.browser == WebBrowser.safari ||
                r.browser == WebBrowser.firefox,
          )
          .every((r) => !r.firstBatchTarget && !r.admitted && !r.qualified),
      isTrue,
    );

    final admitted = compiler.admit(
      WebLibraryAdmissionRequest(
        libraryId: 'mediabunny',
        browser: WebBrowser.chrome,
        feature: 'mp4-h264-aac',
      ),
    );
    expect(admitted.admittedLibrary, 'mediabunny');
    expect(admitted.admittedBrowser, WebBrowser.chrome);
    expect(admitted.roundtripQualified, isFalse);
    expect(admitted.productionPinned, isFalse);
    expect(admitted.submitted, isFalse);
    expect(admitted.documentWrites, 0);

    expect(
      () => compiler.admit(
        WebLibraryAdmissionRequest(
          libraryId: 'mediabunny',
          browser: WebBrowser.safari,
        ),
      ),
      code(browserFeatureUnverified),
    );
    expect(
      () => compiler.admit(
        WebLibraryAdmissionRequest(
          libraryId: 'mp4box',
          browser: WebBrowser.firefox,
        ),
      ),
      code(browserFeatureUnverified),
    );
    expect(compiler.documentWrites, 0);
  });

  test('ffmpeg.wasm, native FFmpeg as a Web general path, an unsupported codec, and missing durable storage are refused and do not submit or download a package', () {
    final compiler = WebLibraryCompiler();
    expect(
      () => compiler.admit(
        WebLibraryAdmissionRequest(
          libraryId: 'ffmpeg-wasm',
          browser: WebBrowser.chrome,
          useFfmpegWasm: true,
        ),
      ),
      code(ffmpegWasmNotDefault),
    );
    expect(
      () => compiler.admit(
        WebLibraryAdmissionRequest(
          libraryId: 'native-ffmpeg',
          browser: WebBrowser.chrome,
          useNativeFfmpeg: true,
        ),
      ),
      code(nativeFfmpegNotWebDefault),
    );
    expect(
      () => compiler.admit(
        WebLibraryAdmissionRequest(
          libraryId: 'mediabunny',
          browser: WebBrowser.edge,
          codecSupported: false,
        ),
      ),
      code(codecUnsupported),
    );
    expect(
      () => compiler.admit(
        WebLibraryAdmissionRequest(
          libraryId: 'mp4box',
          browser: WebBrowser.chrome,
          persistentGranted: false,
        ),
      ),
      code(webStorageNotDurable),
    );
    expect(
      () => compiler.admit(
        WebLibraryAdmissionRequest(
          libraryId: 'mediabunny',
          browser: WebBrowser.chrome,
          evicted: true,
        ),
      ),
      code(webStorageNotDurable),
    );
    expect(compiler.documentWrites, 0);
    expect(compiler.catalog().packageDownloaded, isFalse);
  });
}
