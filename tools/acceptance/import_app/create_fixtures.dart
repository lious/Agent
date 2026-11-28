// PUBLIC unsigned fixtures generated for the actual Web App namespace before
// serialization; no signed namespace rewriting and no publisher roots.
import 'dart:io';

import '../../../packages/studio_assets/test/skills/signed_import/fixture.dart';

void main(List<String> args) {
  final root = Directory(args.single)..createSync(recursive: true);
  final f = PackFixture();
  f.film['namespace'] = {
    'appId': 'studio',
    'tenantId': 'local',
    'workspaceId': 'web',
  };
  f.film['title'] = 'Literal <script>not executable</script>';
  File('${root.path}/unsigned.json').writeAsBytesSync(f.envelope([]));
}
