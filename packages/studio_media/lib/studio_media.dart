import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

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
