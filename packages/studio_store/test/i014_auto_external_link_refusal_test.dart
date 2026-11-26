import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:test/test.dart';

/// Increment 1.93 official I-014 remainingAcceptance wording
/// 「自动外链均拒」 on the already-admitted embedded ProjectArchive.save path.
/// A document with a non-null asset.externalLocator is refused as
/// FEATURE_NOT_IMPLEMENTED and does not publish a package. This file does
/// not rewrite files_test.dart or officialize zip slip / bomb / symlink
/// refusals. packMode=linked and populated missingExternalRefs are not
/// invented.
Namespace get ns => Namespace('studio', 'local', 'i014-external-link');

const locatorId = 'locator-1914-unresolved';

Matcher error(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

ProjectDocument withExternalLocator() {
  final json =
      jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
          as Map<String, dynamic>;
  json['assets'][0]['externalLocator'] = locatorId;
  return ProjectDocument.fromJson(json);
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i014-external-link-');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('ProjectArchive.save refuses an externalLocator and does not publish a package', () async {
    final project = withExternalLocator();
    expect(project.toJson()['assets'][0]['externalLocator'], locatorId);
    final dest = File('${dir.path}/out.zip');
    final store = BlobStore(Directory('${dir.path}/cas'), ns);
    await expectLater(
      ProjectArchive().save(project, store, dest),
      error('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(dest.existsSync(), false);
    expect(
      Directory(dir.path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.zip')),
      isEmpty,
    );
  });
}
