/// Opt-in Dart-JS main-browser-realm import-to-preview, not product UI wiring.
/// The App must first serve signed_import_bootstrap.js under the locked CSP/SRI
/// profile. No backend, repository or unsigned fallback is published on failure.
library;

import 'craft/signed_import/importer.dart';
import 'craft/signed_import/backend.dart';
export 'craft/signed_import/importer.dart';
export 'craft/signed_import/backend.dart' show SodiumVerifier;

Future<FilmSkillRepository> createWebSignedSkillRepository(
  ImportAppSnapshot Function() currentApp,
  ImportUserActionPort userActions,
) async {
  final backend = await SodiumVerifier.initialize();
  // Keep the live callback, never a pre-await AppProfile/policy/grant snapshot.
  return FilmSkillRepository(backend, currentApp, userActions);
}
