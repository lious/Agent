/// Native-only Ed25519 port. No algorithm negotiation or pack-supplied library.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:studio_contracts/studio_contracts.dart';

typedef _VerifyC = Int32 Function(
  Pointer<Uint8>,
  Pointer<Uint8>,
  Uint64,
  Pointer<Uint8>,
);
typedef _VerifyD = int Function(
  Pointer<Uint8>,
  Pointer<Uint8>,
  int,
  Pointer<Uint8>,
);
typedef _PointC = Int32 Function(Pointer<Uint8>);
typedef _PointD = int Function(Pointer<Uint8>);

/// App-owned deployment dependency. Construct only from trusted App configuration,
/// never token/manifest/model input. Deployment must keep this file immutable;
/// the hash check is not a defense against an attacker controlling the App host.
final class SodiumVerifier {
  SodiumVerifier._(this._verify, this._point);
  final _VerifyD _verify;
  final _PointD _point;

  static SodiumVerifier loadTrusted(String binaryPath, String expectedSha256) {
    try {
      if (!Platform.isLinux ||
          FileSystemEntity.typeSync(binaryPath, followLinks: false) !=
              FileSystemEntityType.file ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedSha256) ||
          sha256.convert(File(binaryPath).readAsBytesSync()).toString() !=
              expectedSha256) {
        throw const StudioException('SKILL_IMPORT_POLICY', 'backend');
      }
      final lib = DynamicLibrary.open(binaryPath);
      final init = lib.lookupFunction<Int32 Function(), int Function()>(
        'sodium_init',
      );
      final version = lib
          .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
            'sodium_version_string',
          );
      if (init() < 0 || version().toDartString() != '1.0.22') {
        throw const StudioException('SKILL_IMPORT_POLICY', 'backend/version');
      }
      return SodiumVerifier._(
        lib.lookupFunction<_VerifyC, _VerifyD>('crypto_sign_verify_detached'),
        lib.lookupFunction<_PointC, _PointD>(
          'crypto_core_ed25519_is_valid_point',
        ),
      );
    } on StudioException {
      rethrow;
    } catch (_) {
      throw const StudioException('SKILL_IMPORT_POLICY', 'backend/load');
    }
  }

  /// The maintained backend checks canonical encoding, prime subgroup and torsion;
  /// no curve arithmetic or ad-hoc point blacklist is implemented by this wrapper.
  bool validPublicKey(List<int> key) {
    if (key.length != 32 || key.any((b) => b < 0 || b > 255)) return false;
    final p = calloc<Uint8>(32);
    try {
      p.asTypedList(32).setAll(0, key);
      return _point(p) == 1;
    } finally {
      calloc.free(p);
    }
  }

  bool verify(Uint8List message, List<int> signature, List<int> key) {
    if (signature.length != 64 ||
        key.length != 32 ||
        signature.any((b) => b < 0 || b > 255) ||
        key.any((b) => b < 0 || b > 255)) {
      return false;
    }
    final sig = calloc<Uint8>(64), pk = calloc<Uint8>(32);
    final msg = calloc<Uint8>(message.isEmpty ? 1 : message.length);
    try {
      sig.asTypedList(64).setAll(0, signature);
      pk.asTypedList(32).setAll(0, key);
      msg.asTypedList(message.length).setAll(0, message);
      return _point(pk) == 1 &&
          _point(sig) == 1 &&
          _verify(sig, msg, message.length, pk) == 0;
    } finally {
      calloc.free(sig);
      calloc.free(pk);
      calloc.free(msg);
    }
  }
}
