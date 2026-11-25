import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

ProjectDocument fixture() => ProjectDocument.fromJson(
  jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
      as Map<String, dynamic>,
);
void main() {
  test('1000 edit/undo SQLite transactions preserve exact definition pins; re-edit versions never reused', () {
    final p = fixture(),
        repo = DocumentRepository.open(':memory:', fixture().namespace);
    addTearDown(repo.close);
    repo.create(p);
    final writer = repo.acquireWriter(p.projectId, 'owner', expectedEpoch: 0);
    final clip =
        p.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'] as String;
    repo.edit(
      writer: writer,
      commandId: 'trim',
      receiptKey: 'trim',
      expectedRevision: BigInt.zero,
      operation: TrimClip(clip, 'out', Q.of(-1), ripple: true),
    );
    final original = repo.read(p.projectId)!.toJson()..remove('revision');
    final random = Random(251125);
    for (var i = 0; i < 1000; i++) {
      final before = repo.read(p.projectId)!;
      final result = repo.edit(
        writer: writer,
        commandId: 'slip-$i',
        receiptKey: 'slip-$i',
        expectedRevision: before.revision,
        operation: SlipClip(clip, Q.of(1 + random.nextInt(30), 30)),
      );
      expect(result.toJson()['invalidatedRanges'], isNotEmpty);
      repo.undoLatest(
        writer: writer,
        commandId: 'undo-$i',
        receiptKey: 'undo-$i',
        expectedRevision: before.revision + BigInt.one,
        targetCommandId: 'slip-$i',
      );
      final restored = repo.read(p.projectId)!;
      expect(restored.revision, before.revision + BigInt.two);
      expect(
        contentHash(restored.toJson()..remove('revision')),
        contentHash(original),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('v1 frozen SQL migration preserves existing snapshot and permits later edits/reopen', () {
    final dir = Directory.systemTemp.createTempSync('v1-migration-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/db.sqlite';
    final ns = Namespace('test', 'local', 'ws'),
        p = ProjectDocument.empty(
          namespace: Namespace('test', 'local', 'ws'),
          projectId: 'old-project',
          title: 'v1 saved',
        );
    final db = sqlite3.open(path),
        sql = File('fixtures/store/v1.sql').readAsStringSync();
    db.execute(sql);
    db.execute('INSERT INTO schema_migrations VALUES(1,?)', [contentHash(sql)]);
    db.userVersion = 1;
    db.execute('INSERT INTO snapshots VALUES(?,?,?)', [
      ns.key,
      p.hash,
      p.canonicalJson,
    ]);
    db.execute(
      'INSERT INTO project_heads(ns,project_id,revision,snapshot_hash) VALUES(?,?,0,?)',
      [ns.key, p.projectId, p.hash],
    );
    db.execute('INSERT INTO stream_heads VALUES(?,?,1)', [ns.key, p.projectId]);
    db.execute('INSERT INTO entity_versions VALUES(?,?,?,?,?)', [
      ns.key,
      p.projectId,
      'sequence-main',
      0,
      contentHash(p.toJson()['sequences'][0]),
    ]);
    db.dispose();
    var repo = DocumentRepository.open(path, ns);
    expect(repo.read(p.projectId)!.hash, p.hash);
    final writer = repo.acquireWriter(p.projectId, 'owner', expectedEpoch: 0);
    repo.rename(
      writer: writer,
      commandId: 'rename',
      receiptKey: 'rename',
      expectedRevision: BigInt.zero,
      title: 'v2 saved',
    );
    repo.close();
    repo = DocumentRepository.open(path, ns);
    expect(repo.read(p.projectId)!.title, 'v2 saved');
    repo.close();
    final check = sqlite3.open(path);
    expect(check.userVersion, 6);
    expect(check.select('PRAGMA integrity_check').single.values.single, 'ok');
    check.dispose();
  });
  test(
    'failure after definitions/blob pins rolls back every table and head',
    () {
      final dir = Directory.systemTemp.createTempSync('edit-rollback-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/db.sqlite', p = fixture();
      final repo = DocumentRepository.open(path, p.namespace);
      addTearDown(repo.close);
      repo.create(p);
      final writer = repo.acquireWriter(p.projectId, 'owner', expectedEpoch: 0);
      final db = sqlite3.open(path);
      addTearDown(db.dispose);
      const tables = [
        'snapshots',
        'entity_versions',
        'blob_edges',
        'commands',
        'revisions',
        'events',
        'outbox',
        'receipts',
      ];
      Map<String, Object?> counts() => {
        for (final t in tables)
          t: db.select('SELECT count(*) AS n FROM $t').single['n'],
      };
      final before = counts();
      db.execute(
        "CREATE TRIGGER fail_event BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'injected failure after pins'); END",
      );
      final clip =
          p.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'] as String;
      expect(
        () => repo.edit(
          writer: writer,
          commandId: 'split',
          receiptKey: 'split',
          expectedRevision: BigInt.zero,
          operation: SplitClip(clip, Q.of(1), 'right'),
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(counts(), before);
      expect(repo.read(p.projectId)!.hash, p.hash);
      expect(db.select('PRAGMA foreign_key_check'), isEmpty);
    },
  );
}
