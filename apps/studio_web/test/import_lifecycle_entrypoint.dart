// LIFECYCLE TEST ENTRYPOINT ONLY. Public deterministic seed 1..32, not production roots.
import 'package:material_ui/material_ui.dart';

import 'import_held_source.dart';

import 'package:studio_assets/studio_signed_skill_import_web.dart';

import 'package:studio_web/main.dart';
import 'package:studio_web/import_fixture_composition.dart';

void main() => runApp(
  WebStudioApp.testImport(
    importFixture: AppImportFixtureConfiguration(
      lifecycleTestControls: true,
      chooseSourceForTest: const bool.fromEnvironment('STUDIO_IMPORT_HOLD_READ')
          ? chooseHeldFixtureSource
          : null,
      nowSeconds: 1000,
      clockConfident: true,
      policyForOwner: (profile, namespace) => BuildTimeSignaturePolicy({
        'policyVersion': 'filmcraft-import-v1',
        'policyEpoch': 1,
        'appId': profile.appId,
        'namespace': namespace.toJson(),
        'threshold': 1,
        'trustedSigners': [
          {
            'publicKeyBase64': 'ebVWLo/mVPlAeLES6KmLp5AfhTrmlb7X4OORC60ElmQ=',
            'keyFingerprint': 'sha256:65b60673d6ed884bf01c2c222d82ada0740f29ac3355d6a925c81f17f47a27b8',
            'role': 'filmCraftPublisher',
            'notBefore': 10,
            'notAfter': 10000,
            'revoked': false,
          },
        ],
        'maxEnvelopeBytes': 4194304,
        'maxPayloadBytes': 2097152,
        'maxFileBytes': 1048576,
      }),
    ),
  ),
);
