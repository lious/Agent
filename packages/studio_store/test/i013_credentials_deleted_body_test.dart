import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

/// Increment 1.92 official I-013 remainingAcceptance clause
/// 「凭据/已删正文不入包」 on the already-admitted embedded ProjectArchive.
/// Official packages carry the frozen current snapshot and declared blobs
/// only; sessionArchive stays null; superseded document body and
/// credentials/sessions/command journal are not zip entries. This file
/// does not rewrite files_test.dart, save_test.dart, or 1.84–1.91 suites.
Namespace get ns => Namespace('studio', 'local', 'i013-archive');

const deletedBody = 'DeletedBody-1913-secret';
const visibleTitle = 'VisibleTitle-1913';

Matcher error(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

List<int> zip(Map<String, List<int>> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.add(ArchiveFile.bytes(e.key, e.value));
  }
  return ZipEncoder().encode(a);
}

bool entryContains(List<int> bytes, String text) =>
    utf8.decode(bytes, allowMalformed: true).contains(text);

Map<String, List<int>> zipEntries(File file) => {
  for (final f in ZipDecoder().decodeBytes(file.readAsBytesSync()))
    f.name: List<int>.from(f.content),
};

void main() {
  late Directory dir;
  late String path;
  late DocumentRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i013-archive-');
    path = '${dir.path}/workspace.sqlite';
    repo = DocumentRepository.open(path, ns);
    repo.create(
      ProjectDocument.empty(namespace: ns, projectId: 'p1', title: deletedBody),
    );
  });
  tearDown(() {
    repo.close();
    dir.deleteSync(recursive: true);
  });

  test('a current-revision archive excludes superseded body, sessions, and credentials', () async {
    final writer = repo.acquireWriter('p1', 'owner', expectedEpoch: 0);
    repo.rename(
      writer: writer,
      commandId: 'c1',
      receiptKey: 'r1',
      expectedRevision: BigInt.zero,
      title: visibleTitle,
    );
    final current = repo.read('p1')!;
    expect(current.title, visibleTitle);
    expect(current.revision, BigInt.one);
    // The store still holds the superseded body in an earlier snapshot;
    // the package must not.
    final db = sqlite3.open(path);
    final stored = db
        .select('SELECT json FROM snapshots')
        .map((row) => row['json'] as String)
        .join('\n');
    db.dispose();
    expect(stored, contains(deletedBody));
    expect(stored, contains(visibleTitle));

    final archiveFile = File('${dir.path}/project.archive');
    await ProjectArchive().save(
      current,
      BlobStore(Directory('${dir.path}/cas'), ns),
      archiveFile,
    );
    final opened = ProjectArchive().open(archiveFile);
    expect(opened.project.hash, current.hash);
    expect(opened.project.title, visibleTitle);
    expect(opened.project.revision, BigInt.one);

    final entries = zipEntries(archiveFile);
    final manifest = jsonDecode(
      utf8.decode(entries['manifest.json']!),
    ) as Map<String, dynamic>;
    expect(manifest['sessionArchive'], isNull);
    expect(manifest['packMode'], 'embedded');
    expect(manifest['revision'], '1');
    expect(manifest['snapshotHash'], current.hash);
    expect(
      entries.keys,
      unorderedEquals({
        'manifest.json',
        'checksums.json',
        'snapshots/${current.hash.substring(7)}.json',
      }),
    );
    for (final name in entries.keys) {
      expect(
        name,
        isNot(
          contains(
            RegExp(
              r'session|credential|token|lease|approval|secret|command',
              caseSensitive: false,
            ),
          ),
        ),
      );
    }
    for (final bytes in entries.values) {
      expect(entryContains(bytes, deletedBody), isFalse);
    }
    expect(
      entryContains(
        entries['snapshots/${current.hash.substring(7)}.json']!,
        visibleTitle,
      ),
      isTrue,
    );
  });

  test('a planted sessionArchive is refused and does not authorize credentials into the package', () async {
    final current = repo.read('p1')!;
    final archiveFile = File('${dir.path}/project.archive');
    await ProjectArchive().save(
      current,
      BlobStore(Directory('${dir.path}/cas'), ns),
      archiveFile,
    );
    final entries = zipEntries(archiveFile);
    final manifest = jsonDecode(
      utf8.decode(entries['manifest.json']!),
    ) as Map<String, dynamic>;
    manifest['sessionArchive'] = {
      'policy': 'headersOnly',
      'credentials': 'planted-download-token',
      'sessions': ['deleted-body'],
    };
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
      () => ProjectArchive().verifyBytes(zip(entries)),
      error('ARCHIVE_VERSION_UNSUPPORTED'),
    );
    // The original published package is unchanged and still has no session archive.
    final original = ProjectArchive().open(archiveFile);
    expect(original.project.hash, current.hash);
    final originalManifest = jsonDecode(
      utf8.decode(zipEntries(archiveFile)['manifest.json']!),
    ) as Map<String, dynamic>;
    expect(originalManifest['sessionArchive'], isNull);
  });
}
