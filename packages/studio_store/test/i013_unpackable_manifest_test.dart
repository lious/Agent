import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:test/test.dart';

/// Increment 2.50 official I-013 leftover 「不可打包资源显式manifest」.
/// packMode=linked and missingExternalRefs list unpackable Asset IDs.
/// proxyOnly is only a sourceCompleteness value, not a packMode.
/// This file does not invent job archival, does not rewrite
/// i013_credentials_deleted_body_test.dart, files_test.dart, or the
/// Increment 1.93 I-014 suite, does not merge schema v10, and does not
/// change Project user_version.
Namespace get ns => Namespace('studio', 'local', 'i013-linked-manifest');

const assetId = '01a21091-0dd7-7ab3-881f-1f870ad6f1c3';
const locatorId = 'locator-1913-ids-only';

Matcher error(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

ProjectDocument localVideo({String? externalLocator}) {
  final json = jsonDecode(
    File('fixtures/project/local-video.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  if (externalLocator != null) {
    json['assets'][0]['externalLocator'] = externalLocator;
  }
  return ProjectDocument.fromJson(json);
}

List<int> zipOf(Map<String, List<int>> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.add(ArchiveFile.bytes(e.key, e.value));
  }
  return ZipEncoder().encode(a);
}

Map<String, List<int>> zipEntries(File file) => {
  for (final f in ZipDecoder().decodeBytes(file.readAsBytesSync()))
    f.name: List<int>.from(f.content),
};

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i013-linked-');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('linked mode publishes packMode=linked with an explicit missingExternalRefs manifest, does not pack the original, and is not selfContained', () async {
    final project = localVideo(externalLocator: locatorId);
    expect(project.toJson()['assets'][0]['id'], assetId);
    final dest = File('${dir.path}/linked.zip');
    await ProjectArchive().save(
      project,
      BlobStore(Directory('${dir.path}/cas'), ns),
      dest,
      options: const ArchiveOptions(mode: ArchiveExportMode.linked),
    );
    expect(dest.existsSync(), isTrue);
    final opened = ProjectArchive().open(dest);
    expect(opened.packMode, 'linked');
    expect(opened.missingExternalRefs, [assetId]);
    expect(opened.sourceCompleteness, 'externalRefs');
    expect(opened.sourceCompleteness, isNot('selfContained'));
    expect(opened.needsRelink, isTrue);
    expect(opened.originals, isEmpty);
    expect(opened.project.hash, project.hash);
    expect(opened.project.toJson()['assets'][0]['externalLocator'], locatorId);
    final entries = zipEntries(dest);
    expect(entries.keys.where((k) => k.startsWith('originals/')), isEmpty);
    final manifest = jsonDecode(
      utf8.decode(entries['manifest.json']!),
    ) as Map<String, dynamic>;
    expect(manifest['packMode'], 'linked');
    expect(manifest['missingExternalRefs'], [assetId]);
    expect(manifest['sessionArchive'], isNull);
    expect(manifest['includedGroups'], isEmpty);
  });

  test('proxies mode uses packMode=linked rather than proxyOnly; a planted proxyOnly packMode is refused; an empty ZIP does not become selfContained', () async {
    final project = localVideo();
    final dest = File('${dir.path}/proxies.zip');
    await ProjectArchive().save(
      project,
      BlobStore(Directory('${dir.path}/cas'), ns),
      dest,
      options: const ArchiveOptions(mode: ArchiveExportMode.proxies),
    );
    final opened = ProjectArchive().open(dest);
    expect(opened.packMode, 'linked');
    expect(opened.missingExternalRefs, [assetId]);
    expect(opened.sourceCompleteness, 'incomplete');
    expect(opened.sourceCompleteness, isNot('selfContained'));
    expect(opened.needsRelink, isTrue);
    expect(
      zipEntries(dest).keys.where((k) => k.startsWith('originals/')),
      isEmpty,
    );

    final entries = zipEntries(dest);
    final manifest = jsonDecode(
      utf8.decode(entries['manifest.json']!),
    ) as Map<String, dynamic>;
    manifest['packMode'] = 'proxyOnly';
    entries['manifest.json'] = utf8.encode(jsonEncode(manifest));
    entries['checksums.json'] = utf8.encode(
      jsonEncode({
        'files': [
          for (final e in entries.entries.where(
            (e) => e.key != 'checksums.json',
          ))
            {
              'path': e.key,
              'hash': rawBytesHash(e.value),
              'bytes': e.value.length.toString(),
            },
        ],
      }),
    );
    expect(
      () => ProjectArchive().verifyBytes(zipOf(entries)),
      error('ARCHIVE_VERSION_UNSUPPORTED'),
    );
    // The published proxies package is unchanged.
    final original = ProjectArchive().open(dest);
    expect(original.packMode, 'linked');
    expect(original.missingExternalRefs, [assetId]);
  });

  test('default originals save still refuses a locator and does not publish; a linked package is not selfContained and does not carry model weights', () async {
    await expectLater(
      ProjectArchive().save(
        localVideo(externalLocator: locatorId),
        BlobStore(Directory('\${dir.path}/cas'), ns),
        File('\${dir.path}/default.zip'),
      ),
      error('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(File('\${dir.path}/default.zip').existsSync(), isFalse);

    final linked = File('\${dir.path}/linked-no-weights.zip');
    await ProjectArchive().save(
      localVideo(externalLocator: locatorId),
      BlobStore(Directory('\${dir.path}/cas'), ns),
      linked,
      options: const ArchiveOptions(mode: ArchiveExportMode.linked),
    );
    final opened = ProjectArchive().open(linked);
    expect(opened.packMode, 'linked');
    expect(opened.omissions, isEmpty);
    expect(
      zipEntries(linked).keys.any(
        (k) =>
            k.contains('model') ||
            k.contains('weight') ||
            k.endsWith('.gguf') ||
            k.contains('lora'),
      ),
      isFalse,
    );
    expect(opened.sourceCompleteness, isNot('selfContained'));
    expect(opened.needsRelink, isTrue);
  });
}
