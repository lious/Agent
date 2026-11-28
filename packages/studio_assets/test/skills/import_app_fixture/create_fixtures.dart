// TEST ONLY: deterministic public seed bytes 1..32, never publisher credentials.
import 'dart:convert';
import 'dart:io';

import 'package:studio_assets/craft/signed_import/strict_json.dart';
import 'package:studio_assets/studio_signed_skill_import.dart';

import '../signed_import/fixture.dart' as f;

void main(List<String> args) {
  final out = Directory(args.single)..createSync(recursive: true);
  final root = Directory.current.path;
  Directory.current = '$root/packages/studio_assets';
  final lock = jsonDecode(
    File('third_party/sodium/backend-lock.json').readAsStringSync(),
  );
  SodiumVerifier.loadTrusted(lock['devBinary'], lock['devBinarySha256']);
  final signer = f.FixtureSigner(1);
  Directory.current = root;
  try {
    final pack = f.PackFixture();
    pack.film['namespace'] = {
      'appId': 'studio',
      'tenantId': 'local',
      'workspaceId': 'web',
    };
    pack.film['title'] =
        'PUBLIC_FIXTURE_355_LITERAL <script>not executable</script>';
    final bytes = pack.envelope([signer]);
    File('${out.path}/signed.json').writeAsBytesSync(bytes);
    final body = base64.decode(jsonDecode(utf8.decode(bytes))['payload']);
    final payload = jsonDecode(utf8.decode(body));
    final film = (payload['files'] as List).firstWhere(
      (x) => x['path'] == 'film-skill.json',
    );
    final expected = {
      'seedProvenance': 'PUBLIC deterministic bytes 1..32; FixtureSigner(1)',
      'signer': signer.trusted(),
      'nowSeconds': 1000,
      'policyEpoch': 1,
      'threshold': 1,
      'envelopeHash': digest(bytes),
      'payloadHash': digest(body),
      'contentHash': film['sha256'],
      'permissionDiffHash': digest(
        utf8.encode(
          jsonEncode({
            'requiredTools': ['media.analyze'],
            'missingTools': ['media.analyze'],
          }),
        ),
      ),
      'requiredTools': ['media.analyze'],
      'licenseWarnings': [
        'LICENSE_DECLARATION_UNVERIFIED',
        'LICENSE_EVIDENCE_MISSING',
      ],
      'namespace': pack.film['namespace'],
    };
    File('${out.path}/expected.json').writeAsStringSync(jsonEncode(expected));
    print(jsonEncode(expected));
  } finally {
    signer.dispose();
  }
}
