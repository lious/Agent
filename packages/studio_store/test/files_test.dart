import 'dart:io';
import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/atomic_file.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:test/test.dart';

Matcher error(String s) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', s));
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('studio-file-test-'));
  tearDown(() => dir.deleteSync(recursive: true));
  final ns = Namespace('test', 'local', 'ws');
  test('explicit CAS GC keeps pins/other namespaces, refuses symlinks and releases lock after failure', () async {
    final store = BlobStore(Directory('${dir.path}/managed'), ns);
    final other = BlobStore(
      Directory('${dir.path}/managed'),
      Namespace('other', 'local', 'ws'),
    );
    final pinned = Uint8List.fromList([1, 2, 3]),
        orphan = Uint8List.fromList([4, 5, 6]);
    await store.putVerifiedBytes(rawBytesHash(pinned), pinned);
    await other.putVerifiedBytes(rawBytesHash(orphan), orphan);
    final outside = File('${dir.path}/outside')
      ..writeAsStringSync('never delete');
    final link = Link('${store.directory.path}/${'f' * 64}')
      ..createSync(outside.path);
    await expectLater(
      store.withMaintenanceLease(
        () async => store.collectUnreferenced({rawBytesHash(pinned)}),
      ),
      error('CAS_GC_UNSAFE_ENTRY'),
    );
    expect(outside.readAsStringSync(), 'never delete');
    await store.resolve(rawBytesHash(pinned));
    link.deleteSync();
    await store.putVerifiedBytes(rawBytesHash(orphan), orphan);
    final active = File('${store.directory.path}/.import-active')
      ..writeAsStringSync('stage');
    final result = await store.withMaintenanceLease(
      () async => store.collectUnreferenced({rawBytesHash(pinned)}),
    );
    expect(result, {'files': 1, 'bytes': 3});
    expect(active.existsSync(), isTrue);
    await store.resolve(rawBytesHash(pinned));
    await other.resolve(rawBytesHash(orphan));
  });
  test('actual CAS deduplicates, rejects wrong relink, preserves source and rejects corruption', () async {
    final source = File('${dir.path}/selected')..writeAsBytesSync([1, 2, 3]);
    final store = BlobStore(Directory('${dir.path}/cas'), ns);
    final one = await store.importFile(
      LocalFileGrant.fromUserSelection(source),
    );
    final two = await store.importFile(
      LocalFileGrant.fromUserSelection(source),
    );
    expect(one.hash, two.hash);
    expect(store.directory.listSync().length, 1);
    expect(source.readAsBytesSync(), [1, 2, 3]);
    source.writeAsBytesSync([4, 5, 6]);
    await expectLater(
      store.relink(one.hash, LocalFileGrant.fromUserSelection(source)),
      error('RELINK_HASH_MISMATCH'),
    );
    expect(store.directory.listSync().length, 1);
    one.file.writeAsBytesSync([9]);
    await expectLater(store.resolve(one.hash), error('BLOB_HASH_MISMATCH'));
  });
  test('oversize import and symlink selection publish no blob', () async {
    final source = File('${dir.path}/selected')..writeAsBytesSync([1, 2, 3]);
    final store = BlobStore(
      Directory('${dir.path}/cas'),
      ns,
      maxImportBytes: 2,
    );
    await expectLater(
      store.importFile(LocalFileGrant.fromUserSelection(source)),
      error('IMPORT_LIMIT'),
    );
    expect(store.directory.listSync(), isEmpty);
    final link = Link('${dir.path}/link')..createSync(source.path);
    await expectLater(
      store.importFile(LocalFileGrant.fromUserSelection(File(link.path))),
      error('LOCAL_FILE_REQUIRED'),
    );
  });
  test('atomic sibling publication replaces complete file; failure never overwrites old good target', () {
    final target = File('${dir.path}/good')..writeAsStringSync('good');
    final p = AtomicFilePublisher();
    final stage = p.stagingFor(target)..writeAsStringSync('new');
    p.publish(stage, target);
    expect(target.readAsStringSync(), 'new');
    expect(
      () => p.publish(File('${dir.path}/missing'), target),
      error('INVALID_STAGING_FILE'),
    );
    expect(target.readAsStringSync(), 'new');
    final linked = Link('${dir.path}/linked')..createSync(target.path);
    expect(
      () => p.write(File(linked.path), [1]),
      error('UNSAFE_OUTPUT_TARGET'),
    );
    expect(target.readAsStringSync(), 'new');
  });
  test(
    'archive valid roundtrip/fork and damaged checksum preserve original',
    () async {
      final p = ProjectDocument.empty(
        namespace: ns,
        projectId: 'p1',
        title: 'good',
      );
      final store = BlobStore(Directory('${dir.path}/cas'), ns),
          archive = ProjectArchive(),
          file = File('${dir.path}/good.zip');
      await archive.save(p, store, file);
      expect(archive.open(file).project.hash, p.hash);
      var id = 0;
      final fork = forkLocalProject(
        p,
        Namespace('other', 'local', 'ws'),
        newId: () => 'fork-${id++}',
      );
      expect(fork.projectId, isNot(p.projectId));
      expect(fork.revision, BigInt.zero);
      expect(fork.namespace.appId, 'other');
      final bytes = file.readAsBytesSync();
      expect(
        () => archive.verifyBytes(bytes.sublist(0, bytes.length ~/ 2)),
        throwsA(isA<StudioException>()),
      );
      expect(archive.open(file).project.hash, p.hash);
    },
  );
  List<int> zip(Map<String, List<int>> files) {
    final a = Archive();
    for (final e in files.entries) {
      a.add(ArchiveFile.bytes(e.key, e.value));
    }
    return ZipEncoder().encode(a);
  }

  List<int> unsafeZip(String name) {
    final bytes = Uint8List.fromList(
      zip({
        List.filled(name.length, 'x').join(): [1],
      }),
    );
    for (var i = 0; i <= bytes.length - name.length; i++) {
      if (List.generate(
        name.length,
        (n) => bytes[i + n],
      ).every((b) => b == 120)) {
        bytes.setRange(i, i + name.length, name.codeUnits);
        i += name.length - 1;
      }
    }
    return bytes;
  }

  test('hostile ZIP paths rejected before extraction', () {
    for (final path in [
      '../escape',
      '/absolute',
      'a/../b',
      'a\\b',
      'C:bad',
      'a%2fb',
      'a//b',
    ]) {
      expect(
        () => ProjectArchive().verifyBytes(unsafeZip(path)),
        error('ARCHIVE_UNSAFE_PATH'),
        reason: path,
      );
    }
    expect(File('${dir.parent.path}/escape').existsSync(), false);
  });
  test('ZIP duplicate headers and advertised expanded-size bomb are rejected before decompression', () {
    final bytes = Uint8List.fromList(
      zip({
        'aaaa': [1],
        'bbbb': [2],
      }),
    );
    for (var i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == 98 &&
          bytes[i + 1] == 98 &&
          bytes[i + 2] == 98 &&
          bytes[i + 3] == 98) {
        bytes.setRange(i, i + 4, [97, 97, 97, 97]);
      }
    }
    expect(
      () => ProjectArchive().verifyBytes(bytes),
      error('ARCHIVE_DUPLICATE_PATH'),
    );
    final bomb = Uint8List.fromList(
      zip({
        'x': [0],
      }),
    );
    final data = ByteData.sublistView(bomb);
    for (var i = 0; i < bomb.length - 28; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint32(i + 24, 300 * 1024 * 1024, Endian.little);
        break;
      }
    }
    expect(() => ProjectArchive().verifyBytes(bomb), error('ARCHIVE_LIMIT'));
  });
  test('ZIP Unix symlink metadata is rejected before contents are trusted', () {
    final a = Archive()
      ..add(ArchiveFile.symlink('shortcut', '../outside')..mode = 0xa1ff);
    expect(
      () => ProjectArchive().verifyBytes(ZipEncoder().encode(a)),
      error('ARCHIVE_UNSAFE_ENTRY'),
    );
  });
  test('valid checksums cannot authorize unknown manifest fields; unlisted entries rejected', () async {
    final p = ProjectDocument.empty(
      namespace: ns,
      projectId: 'manifest-test',
      title: 'good',
    );
    final file = File('${dir.path}/original.zip'), archive = ProjectArchive();
    await archive.save(p, BlobStore(Directory('${dir.path}/cas'), ns), file);
    final entries = {
      for (final f in ZipDecoder().decodeBytes(file.readAsBytesSync()))
        f.name: List<int>.from(f.content),
    };
    expect(
      () => archive.verifyBytes(
        zip({
          ...entries,
          'unexpected': [1],
        }),
      ),
      error('ARCHIVE_UNCHECKED_ENTRY'),
    );
    final manifest = jsonDecode(
      utf8.decode(entries['manifest.json']!),
    ) as Map<String, dynamic>;
    manifest['untrustedExtra'] = 'not accepted';
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
    expect(() => archive.verifyBytes(zip(entries)), error('MANIFEST_SCHEMA'));
  });
}
