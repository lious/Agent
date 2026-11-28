/// Retains the existing native backend unchanged. No new native qualification.
library;

import 'sodium_verifier.dart';
export 'sodium_verifier.dart';

// Native deployment validation remains at loadTrusted, as before.
void ensureImportBackend(SodiumVerifier backend) {}
