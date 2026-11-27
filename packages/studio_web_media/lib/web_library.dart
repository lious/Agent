import 'package:studio_contracts/studio_contracts.dart';

import 'web_media_port.dart';

/// Safari/Firefox features stay closed until that browser is qualified.
const browserFeatureUnverified = 'BROWSER_FEATURE_UNVERIFIED';

/// Native libav/FFmpeg is not a stand-in for the Web JS+WebCodecs path.
const nativeFfmpegNotWebDefault = 'NATIVE_FFMPEG_NOT_WEB_DEFAULT';

enum WebLibraryRole { demux, mux, demuxAndMux }

enum WebBrowser { chrome, edge, safari, firefox }

/// Public facts for one JS demux/mux lockfile candidate. This is not a
/// production pin, not a downloaded package, and not a 60s qualification.
final class WebLibraryCandidate {
  WebLibraryCandidate({
    required this.id,
    required this.npmPackage,
    required this.version,
    required this.license,
    required this.role,
    required this.homepage,
    required this.repository,
    required this.apiFacts,
    this.isFfmpegWasm = false,
    this.isNativeFfmpeg = false,
    this.deprecated = false,
  }) {
    requireId(id);
    requireId(npmPackage);
    if (version.isEmpty || license.isEmpty) {
      throw const StudioException('INVALID_ID', 'library');
    }
    if (apiFacts.isEmpty) {
      throw const StudioException('INVALID_ID', 'apiFacts');
    }
  }

  final String id, npmPackage, version, license, homepage, repository;
  final WebLibraryRole role;
  final List<String> apiFacts;
  final bool isFfmpegWasm, isNativeFfmpeg, deprecated;

  bool get productionPinned => false;
}

/// Official V-007 candidate pair recorded from public npm facts on
/// 2026-11-28 (Asia/Shanghai). Versions are candidate facts, not a
/// production lock, and not a runtime audit.
final mp4boxCandidate = WebLibraryCandidate(
  id: 'mp4box',
  npmPackage: 'mp4box',
  version: '2.6.0',
  license: 'BSD-3-Clause',
  role: WebLibraryRole.demux,
  homepage: 'https://github.com/gpac/mp4box.js',
  repository: 'https://github.com/gpac/mp4box.js',
  apiFacts: const [
    'MP4Box.createFile',
    'onReady',
    'appendBuffer',
    'setExtractionOptions',
    'onSamples',
    'seek',
  ],
);

final mediabunnyCandidate = WebLibraryCandidate(
  id: 'mediabunny',
  npmPackage: 'mediabunny',
  version: '1.66.5',
  license: 'MPL-2.0',
  role: WebLibraryRole.demuxAndMux,
  homepage: 'https://mediabunny.dev/',
  repository: 'https://github.com/Vanilagy/mediabunny',
  apiFacts: const [
    'Input',
    'BlobSource',
    'Output',
    'Mp4OutputFormat',
    'BufferTarget',
  ],
);

/// Deprecated as of 2025-07 and superseded by mediabunny. Not a V-007
/// lockfile candidate.
final deprecatedMp4Muxer = WebLibraryCandidate(
  id: 'mp4-muxer',
  npmPackage: 'mp4-muxer',
  version: '5.2.2',
  license: 'MIT',
  role: WebLibraryRole.mux,
  homepage: 'https://github.com/Vanilagy/mp4-muxer',
  repository: 'https://github.com/Vanilagy/mp4-muxer',
  apiFacts: const ['Muxer', 'EncodedVideoChunk', 'EncodedAudioChunk'],
  deprecated: true,
);

final officialWebLibraryCandidates = [mp4boxCandidate, mediabunnyCandidate];

/// One row of the V-007 feature matrix. Unverified browsers stay closed.
final class WebFeatureRow {
  const WebFeatureRow({
    required this.browser,
    required this.feature,
    required this.firstBatchTarget,
    required this.admitted,
    required this.qualified,
  });

  final WebBrowser browser;
  final String feature;
  final bool firstBatchTarget, admitted, qualified;
}

/// DEV-PURE admission request. Compile does not download a package,
/// submit, or run a 60s browser roundtrip.
final class WebLibraryAdmissionRequest {
  WebLibraryAdmissionRequest({
    required this.libraryId,
    required this.browser,
    this.feature = 'mp4-h264-aac',
    this.codecSupported = true,
    this.persistentGranted = true,
    this.evicted = false,
    this.useFfmpegWasm = false,
    this.useNativeFfmpeg = false,
  }) {
    requireId(libraryId);
    requireId(feature);
  }

  final String libraryId, feature;
  final WebBrowser browser;
  final bool codecSupported,
      persistentGranted,
      evicted,
      useFfmpegWasm,
      useNativeFfmpeg;
}

/// V-007 catalog and feature-matrix result. A 60s WebCodecs/OPFS
/// roundtrip is not claimed.
final class WebLibraryProgram {
  WebLibraryProgram({
    required this.candidates,
    required this.featureMatrix,
    this.admittedLibrary,
    this.admittedFeature,
    this.admittedBrowser,
  });

  final List<WebLibraryCandidate> candidates;
  final List<WebFeatureRow> featureMatrix;
  final String? admittedLibrary, admittedFeature;
  final WebBrowser? admittedBrowser;

  int get documentWrites => 0;
  bool get submitted => false;
  bool get productionPinned => false;
  bool get roundtripQualified => false;
  bool get nativeFfmpegImported => false;
  bool get ffmpegWasmDefault => false;
  bool get packageDownloaded => false;
}

/// Official V-007 leftover compiler for lockfile candidates, license
/// facts, and the browser feature matrix. This is not a 60s
/// qualification, not a production pin, and not a JS package vendor.
final class WebLibraryCompiler {
  int documentWrites = 0;

  List<WebFeatureRow> officialFeatureMatrix() => [
    for (final feature in const ['webcodecs', 'mp4-h264-aac']) ...[
      for (final browser in WebBrowser.values)
        WebFeatureRow(
          browser: browser,
          feature: feature,
          firstBatchTarget:
              browser == WebBrowser.chrome || browser == WebBrowser.edge,
          admitted: false,
          qualified: false,
        ),
    ],
  ];

  WebLibraryProgram catalog() {
    documentWrites = 0;
    return WebLibraryProgram(
      candidates: officialWebLibraryCandidates,
      featureMatrix: officialFeatureMatrix(),
    );
  }

  WebLibraryProgram admit(WebLibraryAdmissionRequest request) {
    if (request.useFfmpegWasm || request.libraryId == 'ffmpeg-wasm') {
      throw const StudioException(ffmpegWasmNotDefault, 'library');
    }
    if (request.useNativeFfmpeg || request.libraryId == 'native-ffmpeg') {
      throw const StudioException(nativeFfmpegNotWebDefault, 'library');
    }
    if (!request.codecSupported) {
      throw const StudioException(codecUnsupported, 'codec');
    }
    if (!request.persistentGranted || request.evicted) {
      throw const StudioException(webStorageNotDurable, 'storage');
    }
    if (request.browser == WebBrowser.safari ||
        request.browser == WebBrowser.firefox) {
      throw StudioException(browserFeatureUnverified, request.browser.name);
    }
    final match = officialWebLibraryCandidates
        .where((c) => c.id == request.libraryId)
        .toList();
    if (match.isEmpty || match.first.deprecated || match.first.isFfmpegWasm) {
      throw StudioException('INVALID_ID', request.libraryId);
    }
    documentWrites = 0;
    return WebLibraryProgram(
      candidates: officialWebLibraryCandidates,
      featureMatrix: officialFeatureMatrix(),
      admittedLibrary: match.first.id,
      admittedFeature: request.feature,
      admittedBrowser: request.browser,
    );
  }
}
