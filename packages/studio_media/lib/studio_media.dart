import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

part 'audio_pipeline.dart';

typedef _CallNative = Pointer<Utf8> Function(
  Uint64,
  Pointer<Utf8>,
  Pointer<Utf8>,
);
typedef _CallDart = Pointer<Utf8> Function(int, Pointer<Utf8>, Pointer<Utf8>);

/// Explicit Linux software FFmpeg adapter. It never invokes an ffmpeg process.
/// The only process CLI usage in this repository is fixture generation/inspection.
final class NativeMedia {
  NativeMedia.open(this.libraryPath, this.namespace)
    : _lib = DynamicLibrary.open(libraryPath),
      _owns = true {
    final ns = namespace.key.toNativeUtf8();
    try {
      handle = _lib
          .lookupFunction<
            Uint64 Function(Pointer<Utf8>),
            int Function(Pointer<Utf8>)
          >('sm_create')(ns);
    } finally {
      malloc.free(ns);
    }
    if (handle == 0) throw const StudioException('NATIVE_ENGINE_CREATE');
    if (_lib.lookupFunction<Uint32 Function(), int Function()>(
          'sm_abi_version',
        )() !=
        1) {
      throw const StudioException('NATIVE_ABI_MISMATCH');
    }
  }
  NativeMedia._attach(this.libraryPath, this.namespace, this.handle)
    : _lib = DynamicLibrary.open(libraryPath),
      _owns = false;
  final String libraryPath;
  final Namespace namespace;
  final DynamicLibrary _lib;
  final bool _owns;
  late final int handle;
  bool _closed = false;
  Map<String, dynamic> _consume(Pointer<Utf8> pointer) {
    if (pointer == nullptr) {
      throw const StudioException('NATIVE_ALLOCATION_FAILED');
    }
    try {
      final result = jsonDecode(pointer.toDartString()) as Map<String, dynamic>;
      if (result['ok'] != true) {
        throw StudioException(result['code'] as String? ?? 'NATIVE_ERROR');
      }
      return result['value'] as Map<String, dynamic>;
    } finally {
      _lib.lookupFunction<
        Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)
      >('sm_string_free')(pointer);
    }
  }

  Map<String, dynamic> _call(String symbol, String argument) {
    if (_closed) throw const StudioException('NATIVE_ENGINE_CLOSED');
    final ns = namespace.key.toNativeUtf8(), arg = argument.toNativeUtf8();
    try {
      return _consume(
        _lib.lookupFunction<_CallNative, _CallDart>(symbol)(handle, ns, arg),
      );
    } finally {
      malloc.free(ns);
      malloc.free(arg);
    }
  }

  Map<String, dynamic> get capabilities => _consume(
    _lib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
      'sm_capabilities',
    )(),
  );
  Map<String, dynamic> probe(File file) =>
      _call('sm_probe', file.absolute.path);
  Future<Map<String, dynamic>> probeAsync(File file) {
    final path = libraryPath,
        ns = namespace,
        h = handle,
        source = file.absolute.path;
    return Isolate.run(
      () => NativeMedia._attach(path, ns, h).probe(File(source)),
    );
  }

  Future<Map<String, dynamic>> previewAsync(
    File file,
    Q time, {
    bool indexed = true,
    int? opacityQ16,
    Map<String, double>? transform2d,
    Map<String, Map<String, double>>? rasterEffects,
    Map<String, dynamic>? secondary,
    int mixQ16 = 0,
    Map<String, dynamic>? lumaWipe,
  }) {
    if (capabilities['sourcePreview128'] != true) {
      throw const StudioException('PREVIEW_ADAPTER_UNAVAILABLE');
    }
    if (lumaWipe != null) {
      if (secondary == null || capabilities['lumaWipeCpuV1'] != true) {
        throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE');
      }
    } else if (secondary != null && capabilities['linearDissolveV1'] != true) {
      throw const StudioException('DISSOLVE_ADAPTER_UNAVAILABLE');
    }
    if (rasterEffects != null && capabilities['staticRasterV1'] != true) {
      throw const StudioException('RASTER_ADAPTER_UNAVAILABLE');
    }
    if (transform2d != null && capabilities['staticTransform2dV1'] != true) {
      throw const StudioException('TRANSFORM_ADAPTER_UNAVAILABLE');
    }
    if (opacityQ16 != null &&
        (capabilities['linearOpacityV1'] != true ||
            opacityQ16 < 0 ||
            opacityQ16 > 65536)) {
      throw const StudioException('OPACITY_ADAPTER_UNAVAILABLE');
    }
    final path = libraryPath, ns = namespace, h = handle;
    final recipe = jsonEncode({
      'path': file.absolute.path,
      'time': time.toJson(),
      'indexed': indexed,
      'opacityQ16': ?opacityQ16,
      'transform2d': ?transform2d,
      'rasterEffects': ?rasterEffects,
      'secondary': ?secondary,
      if (secondary != null && lumaWipe == null) 'mixQ16': mixQ16,
      'lumaWipe': ?lumaWipe,
    });
    return Isolate.run(
      () => NativeMedia._attach(path, ns, h)._call('sm_preview', recipe),
    );
  }

  Map<String, dynamic> render(Map<String, dynamic> recipe) =>
      _call('sm_export', jsonEncode(recipe));
  Future<Map<String, dynamic>> renderAsync(Map<String, dynamic> recipe) {
    final path = libraryPath,
        ns = namespace,
        h = handle,
        json = jsonEncode(recipe);
    return Isolate.run(
      () => NativeMedia._attach(path, ns, h)._call('sm_export', json),
    );
  }

  int get cancelEpoch {
    final ns = namespace.key.toNativeUtf8();
    try {
      return _lib.lookupFunction<
        Uint64 Function(Uint64, Pointer<Utf8>),
        int Function(int, Pointer<Utf8>)
      >('sm_cancel_epoch')(handle, ns);
    } finally {
      malloc.free(ns);
    }
  }

  Future<Map<String, dynamic>> decodeAudioAsync(Map<String, dynamic> recipe) {
    if (capabilities['pcm48kStereoV1'] != true) {
      throw const StudioException('AUDIO_ADAPTER_UNAVAILABLE');
    }
    final p = libraryPath,
        ns = namespace,
        h = handle,
        json = jsonEncode(recipe);
    return Isolate.run(
      () => NativeMedia._attach(p, ns, h)._call('sm_decode_audio', json),
    );
  }

  Future<Map<String, dynamic>> prepareAudioAsync(Map<String, dynamic> recipe) {
    if (capabilities['pcm48kStereoV1'] != true ||
        capabilities['aacMux48kV1'] != true) {
      throw const StudioException('AUDIO_ADAPTER_UNAVAILABLE');
    }
    final p = libraryPath,
        ns = namespace,
        h = handle,
        json = jsonEncode(recipe),
        epoch = cancelEpoch;
    return Isolate.run(
      () => _prepareAudio(
        NativeMedia._attach(p, ns, h),
        jsonDecode(json) as Map<String, dynamic>,
        epoch,
      ),
    );
  }

  Future<Map<String, dynamic>> buildPreviewProxyAsync(
    File source,
    File output,
  ) {
    if (capabilities['rgba128PtsProxyV1'] != true) {
      throw const StudioException('PROXY_ADAPTER_UNAVAILABLE');
    }
    final p = libraryPath, ns = namespace, h = handle;
    final recipe = jsonEncode({
      'path': source.absolute.path,
      'outputPath': output.absolute.path,
    });
    return Isolate.run(
      () => NativeMedia._attach(p, ns, h)._call('sm_build_proxy', recipe),
    );
  }

  /// Actual local PulseAudio service, not a submitted-sample or wall clock.
  Map<String, dynamic> playback(Map<String, dynamic> command) {
    if (capabilities['pulseServicePlaybackV1'] != true) {
      throw const StudioException('AUDIO_SINK_ADAPTER_UNAVAILABLE');
    }
    return _call('sm_playback', jsonEncode(command));
  }

  void cancel() {
    _control('sm_cancel');
  }

  void _control(String function) {
    if (_closed) throw const StudioException('NATIVE_ENGINE_CLOSED');
    final ns = namespace.key.toNativeUtf8();
    try {
      if (_lib.lookupFunction<
            Int32 Function(Uint64, Pointer<Utf8>),
            int Function(int, Pointer<Utf8>)
          >(function)(handle, ns) !=
          0) {
        throw const StudioException('NATIVE_HANDLE_REJECTED');
      }
    } finally {
      malloc.free(ns);
    }
  }

  void close() {
    if (!_closed) {
      if (_owns) _control('sm_close');
      _closed = true;
    }
  }
}

/// Convert actual native stream facts into the unchanged ProjectDocument schema.
Map<String, dynamic> streamDocument(
  Map<String, dynamic> raw, {
  required String assetId,
}) {
  final video = raw['type'] == 'video';
  if (video && raw['rotation'] == true) {
    throw const StudioException('ROTATION_POLICY_REQUIRED');
  }
  if (video && raw['hasAlpha'] != false) {
    throw const StudioException('ALPHA_POLICY_REQUIRED');
  }
  final tb = raw['timeBase'], dtb = raw['durationTimeBase'], fps = raw['fps'];
  return {
    'id': '$assetId:stream-${raw['index']}',
    'type': raw['type'],
    'codec': raw['codec'],
    'profile': raw['profile'],
    'width': video ? raw['width'] : null,
    'height': video ? raw['height'] : null,
    'pixelFormat': video ? raw['pixelFormat'] : null,
    'timeBase': Q.of(tb['n'] as int, tb['d'] as int).toJson(),
    'startPTS': raw['startPTS'],
    'duration': Q(
      BigInt.parse(raw['durationTicks'] as String) *
          BigInt.from(dtb['n'] as int),
      BigInt.from(dtb['d'] as int),
    ).toJson(),
    'nominalFrameRate': video && fps['n'] > 0 && fps['d'] > 0 ? fps : null,
    'variableFrameRate': raw['variableFrameRate'] ?? true,
    'rotationDeg': 0,
    'color': video
        ? {
            'primaries': raw['primaries'],
            'transfer': raw['transfer'],
            'matrix': raw['matrix'],
            'range': raw['range'],
            'bitDepth': raw['bitDepth'],
            'alpha': 'none',
          }
        : null,
    'sampleRate': video ? null : raw['sampleRate'],
    'channels': video ? null : raw['channels'],
    'channelLayout': video ? null : raw['channelLayout'],
  };
}
