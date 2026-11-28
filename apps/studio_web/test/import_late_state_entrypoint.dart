// TEST ENTRYPOINT ONLY: PUBLIC deterministic seed 1..32, never publisher provisioning.
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
      policyForOwner: (p, n) => policy(p, n),
      transitions: List.unmodifiable([
        AppImportFixtureTransition('profile', [
          AppImportFixtureChange(
            profileForOwner: (p) => AppProfile(
              appId: p.appId,
              region: p.region,
              features: p.features,
              version: p.version,
            ),
          ),
        ]),
        AppImportFixtureTransition('epoch', [
          AppImportFixtureChange(
            policyForOwner: (p, n) => policy(p, n, epoch: 2),
          ),
        ]),
        AppImportFixtureTransition('key-removal', [
          AppImportFixtureChange(
            policyForOwner: (p, n) => policy(p, n, removeKey: true),
          ),
        ]),
        AppImportFixtureTransition('installed', [
          AppImportFixtureChange(installed: {'media.analyze'}),
        ]),
        AppImportFixtureTransition('session', [
          AppImportFixtureChange(session: {'media.analyze'}),
        ]),
        AppImportFixtureTransition('branch', [
          AppImportFixtureChange(branch: {'media.analyze'}),
        ]),
        AppImportFixtureTransition('owner', [
          AppImportFixtureChange(projectId: 'fixture-other-project'),
        ]),
        AppImportFixtureTransition('aba', [
          AppImportFixtureChange(session: {'media.analyze'}),
          AppImportFixtureChange(session: {}),
        ]),
        AppImportFixtureTransition('forward-valid', [
          AppImportFixtureChange(nowSeconds: 1001),
        ]),
        AppImportFixtureTransition('forward-expired', [
          AppImportFixtureChange(nowSeconds: 10000),
        ]),
        AppImportFixtureTransition('backward', [
          AppImportFixtureChange(nowSeconds: 999),
        ]),
        AppImportFixtureTransition('confidence', [
          AppImportFixtureChange(clockConfident: false),
        ]),
        AppImportFixtureTransition('rollback', [
          AppImportFixtureChange(clockRollback: true),
        ]),
      ]),
    ),
  ),
);
