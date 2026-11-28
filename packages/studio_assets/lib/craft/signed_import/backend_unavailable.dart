import 'dart:typed_data';

import 'package:studio_contracts/studio_contracts.dart';

Never _unavailable() =>
    throw const StudioException('SKILL_IMPORT_POLICY', 'backend/unavailable');

final class SodiumVerifier {
  SodiumVerifier._();
  static Future<SodiumVerifier> initialize() async => _unavailable();
  static SodiumVerifier loadTrusted(String binaryPath, String expectedSha256) =>
      _unavailable();
  bool validPublicKey(List<int> key) => _unavailable();
  bool verify(Uint8List message, List<int> signature, List<int> key) =>
      _unavailable();
}

void ensureImportBackend(SodiumVerifier backend) => _unavailable();
