// TEST ONLY: actual factory observation; PUBLIC deterministic signing seed 1..32.
import 'package:material_ui/material_ui.dart';
import 'package:studio_assets/studio_signed_skill_import_web.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_web/main.dart';
import 'package:studio_web/import_fixture_composition.dart';

BuildTimeSignaturePolicy policy(
  AppProfile profile,
  Namespace namespace, {
  int epoch = 1,
  bool removeKey = false,
}) => BuildTimeSignaturePolicy({
  'policyVersion': 'filmcraft-import-v1',
  'policyEpoch': epoch,
  'appId': profile.appId,
  'namespace': namespace.toJson(),
  'threshold': 1,
  'trustedSigners': removeKey
      ? []
      : [
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
});

void main() => runApp(
  WebStudioApp.testImport(
    importFixture: AppImportFixtureConfiguration(
      nowSeconds: 1000,
      clockConfident: true,
      observeRepositoryForTest: true,
      lifecycleTestControls: true,
      policyForOwner: (p, n) => policy(p, n),
      transitions: List.unmodifiable([
        AppImportFixtureTransition('session', [
          AppImportFixtureChange(session: {'media.analyze'}),
        ]),
      ]),
    ),
  ),
);
