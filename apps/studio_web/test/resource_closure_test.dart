import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart' show Namespace;

void main() {
  test('ACTUAL Chrome pure resource graph keeps integrity/format/execution distinct and preserves opaque library/LUT metadata', () {
    final base = ProjectDocument.empty(
      namespace: Namespace('studio', 'local', 'browser'),
      projectId: 'resources',
      title: 'Readonly',
    ).toJson();
    final hash = rawBytesHash(utf8.encode('not an executable font'));
    base['blobs'] = [
      {
        'hash': hash,
        'bytes': '22',
        'mime': 'font/ttf',
        'packagePath': 'fonts/font.ttf',
        'role': 'font',
      },
    ];
    base['fontRefs'] = [
      {
        'id': 'font',
        'family': 'Metadata only',
        'style': 'Regular',
        'hash': hash,
        'licenseRef': null,
        'embedAllowed': false,
        'fallbackFamilies': <String>[],
      },
    ];
    base['defaultFontRef'] = 'font';
    final doc = ProjectDocument.fromJson(base),
        report = projectResourceClosure(doc);
    expect(report['registeredClosure'], true);
    expect(report['renderExecutable'], false);
    expect(report['resources'][0]['formatQualification'], 'notRun');
    base['extensions'] = {
      'vendor.library': {'id': 'opaque', 'version': 7, 'lutHash': hash},
    };
    final opaque = ProjectDocument.fromJson(base),
        blocked = projectResourceClosure(opaque);
    expect(blocked['registeredClosure'], false);
    expect(blocked['issues'][0]['code'], 'UNRESOLVED_EXTENSION_CLOSURE');
    expect(opaque.toJson()['extensions'], base['extensions']);
  });
}
