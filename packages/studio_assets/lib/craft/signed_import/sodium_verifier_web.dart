/// Typed main-realm adapter for the integrity-locked App-owned bootstrap.
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';

@JS('studioSignedImportV1')
external _Bridge? get _globalBridge;
@JS('studioSignedImportBootstrapRejected')
external JSAny? get _bootstrapRejected;

extension type _Bridge(JSObject _) implements JSObject {
  external JSPromise<JSAny?> initialize();
  external JSAny? healthy();
  external JSAny? validPublicKey(JSUint8Array key);
  external JSAny? verify(
    JSUint8Array message,
    JSUint8Array signature,
    JSUint8Array key,
  );
}

Never _failure() =>
    throw const StudioException('SKILL_IMPORT_POLICY', 'backend');
bool _strictBool(JSAny? value) {
  if (value == null || !value.isA<JSBoolean>()) _failure();
  return (value as JSBoolean).toDart;
}

JSUint8Array _copy(List<int> bytes) => Uint8List.fromList(bytes).toJS;

/// Only the trusted, SRI-enforcing App bootstrap can publish this final backend.
/// No factory accepts arbitrary JS objects or caller-supplied verification code.
final class SodiumVerifier {
  SodiumVerifier._(this._bridge);
  final _Bridge _bridge;

  static Future<SodiumVerifier> initialize() async {
    try {
      final bridge = _globalBridge;
      if (bridge == null || _bootstrapRejected != null) _failure();
      if (!_strictBool(await bridge.initialize().toDart)) _failure();
      final result = SodiumVerifier._(bridge);
      result._check();
      return result;
    } catch (_) {
      _failure();
    }
  }

  void _check() {
    try {
      if (_bootstrapRejected != null ||
          _globalBridge != _bridge ||
          !_strictBool(_bridge.healthy())) {
        _failure();
      }
    } catch (_) {
      _failure();
    }
  }

  bool validPublicKey(List<int> key) {
    _check();
    if (key.length != 32 || key.any((b) => b < 0 || b > 255)) return false;
    try {
      return _strictBool(_bridge.validPublicKey(_copy(key)));
    } catch (_) {
      _failure();
    }
  }

  bool verify(Uint8List message, List<int> signature, List<int> key) {
    _check();
    if (signature.length != 64 ||
        key.length != 32 ||
        signature.any((b) => b < 0 || b > 255) ||
        key.any((b) => b < 0 || b > 255)) {
      return false;
    }
    try {
      return _strictBool(
        _bridge.verify(_copy(message), _copy(signature), _copy(key)),
      );
    } catch (_) {
      _failure();
    }
  }
}

void ensureImportBackend(SodiumVerifier backend) => backend._check();
