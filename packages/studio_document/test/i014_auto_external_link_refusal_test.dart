import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

/// Increment 1.93 official I-014 remainingAcceptance wording
/// 「自动外链均拒」 at the already-admitted local-editing and resource-closure
/// bound. A non-null asset.externalLocator is refused for writable admission
/// (`FEATURE_NOT_IMPLEMENTED`) and reported as `EXTERNAL_MEDIA_UNRESOLVED`;
/// the locator is not resolved or fetched. This file does not rewrite
/// files_test.dart or officialize zip slip / bomb / symlink refusals.
Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

const locatorId = 'locator-1914-unresolved';
const sentinelBody = 'I014-SENTINEL-1914';

ProjectDocument fixture() => ProjectDocument.fromJson(
  jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
      as Map<String, dynamic>,
);

ProjectDocument withExternalLocator(ProjectDocument project, String id) {
  final json = project.toJson();
  json['assets'][0]['externalLocator'] = id;
  return ProjectDocument.fromJson(json);
}

void main() {
  late Directory dir;
  late File sentinel;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i014-external-link-');
    sentinel = File('${dir.path}/sentinel.bin')..writeAsStringSync(sentinelBody);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('writable admission refuses a non-null externalLocator and does not resolve it', () {
    final baseline = fixture();
    expect(baseline.toJson()['assets'][0]['externalLocator'], isNull);
    requireLocalEditingWritable(baseline);

    final before = sentinel.statSync();
    final project = withExternalLocator(baseline, locatorId);
    expect(project.toJson()['assets'][0]['externalLocator'], locatorId);

    expect(
      () => requireLocalEditingWritable(project),
      code('FEATURE_NOT_IMPLEMENTED'),
    );
    final issues = projectResourceClosure(project)['issues'] as List;
    expect(
      issues.any((issue) => issue['code'] == 'EXTERNAL_MEDIA_UNRESOLVED'),
      isTrue,
    );

    // The admitted locator field is an Id, not a fetch target. Closure and
    // writable admission must not open sidecar files as a resolution of it.
    expect(sentinel.readAsStringSync(), sentinelBody);
    final after = sentinel.statSync();
    expect(after.size, before.size);
    expect(after.modified, before.modified);
  });
}
