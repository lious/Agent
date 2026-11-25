import 'dart:io';
import 'dart:convert';

import 'package:studio_store/blob_store.dart';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
void main() {
  late Directory dir;
  late DocumentRepository repo;
  late WriterToken writer;
  late Database db;
  final ns = Namespace('studio', 'local', 'retention');
  var step = 0;
  void guard() {}
  void rename() {
    step++;
    repo.rename(
      writer: writer,
      commandId: 'c$step',
      receiptKey: 'r$step',
      expectedRevision: repo.read('p')!.revision,
      title: 'Title$step',
    );
  }

  BigInt rev() => repo.read('p')!.revision;
  int count(String table) =>
      db.select('SELECT count(*) AS n FROM $table').single['n'] as int;
  Map<String, dynamic> review() => repo.reviewCheckpointPruning(writer, rev());
  Map<String, dynamic> apply(Map<String, dynamic> r) =>
      repo.applyCheckpointPruning(
        writer,
        rev(),
        reviewHash: r['reviewHash'],
        confirmed: true,
        validateStorageAuthority: guard,
      );
  void configure(int? n) => repo.configureCheckpointRetention(
    writer,
    rev(),
    n,
    confirmed: true,
    validateStorageAuthority: guard,
  );
  setUp(() {
    dir = Directory.systemTemp.createTempSync('checkpoint-retention-');
    repo = DocumentRepository.open('${dir.path}/db', ns);
    repo.create(
      ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'Root'),
    );
    writer = repo.acquireWriter('p', 'owner', expectedEpoch: 0);
    db = sqlite3.open('${dir.path}/db');
    step = 0;
  });
  tearDown(() {
    repo.close();
    db.dispose();
    dir.deleteSync(recursive: true);
  });
  test('REAL default preserveAll, named/save/latest pins; prune indexes only, repeat audited once and undo remains', () {
    repo.nameCurrentCheckpoint(writer, rev(), 'Original');
    rename();
    repo.beginSave(writer, repo.read('p')!, explicit: true);
    for (var i = 0; i < 4; i++) {
      rename();
      repo.captureCheckpoint(writer);
    }
    expect(review()['candidates'], isEmpty);
    expect(
      () => repo.nameCurrentCheckpoint(writer, rev(), 'Original'),
      code('CHECKPOINT_NAME_EXISTS'),
    );
    configure(1);
    final r = review();
    expect(r['candidates'], hasLength(3));
    final tables = [
      'snapshots',
      'commands',
      'revisions',
      'blob_edges',
      'entity_versions',
      'save_operations',
      'checkpoint_labels',
    ];
    final before = {for (final t in tables) t: count(t)};
    final audit = apply(r);
    expect(audit['removedCheckpointIds'], hasLength(3));
    expect(count('checkpoints'), 3);
    expect(apply(r), audit);
    expect(count('checkpoint_prune_audits'), 1);
    expect(repo.checkpointPruneAuditHistory('p'), hasLength(1));
    expect({for (final t in tables) t: count(t)}, before);
    final revision = rev();
    repo.undoLatest(
      writer: writer,
      commandId: 'undo',
      receiptKey: 'undo-r',
      expectedRevision: revision,
      targetCommandId: 'c5',
    );
    expect(repo.read('p')!.toJson()['title'], 'Title4');
    expect(rev(), revision + BigInt.one);
    final pointer = repo.persistenceView('p').checkpointRevision;
    expect(pointer, BigInt.from(5));
  });
  test('REAL stale policy/name/row/revision/fence reviews refuse; explicit confirmation and bounds', () {
    for (var i = 0; i < 4; i++) {
      repo.captureCheckpoint(writer);
      rename();
    }
    repo.captureCheckpoint(writer);
    configure(1);
    var r = review();
    configure(2);
    expect(() => apply(r), code('RETENTION_REVIEW_STALE'));
    r = review();
    repo.nameCurrentCheckpoint(writer, rev(), 'Pinned');
    expect(() => apply(r), code('RETENTION_REVIEW_STALE'));
    r = review();
    rename();
    expect(
      () => repo.applyCheckpointPruning(
        writer,
        BigInt.parse(r['revision']),
        reviewHash: r['reviewHash'],
        confirmed: true,
        validateStorageAuthority: guard,
      ),
      code('REVISION_CONFLICT'),
    );
    r = review();
    final old = writer;
    writer = repo.acquireWriter('p', 'new-owner', expectedEpoch: 1);
    expect(
      () => repo.applyCheckpointPruning(
        old,
        rev(),
        reviewHash: r['reviewHash'],
        confirmed: true,
        validateStorageAuthority: guard,
      ),
      code('WRITER_FENCED'),
    );
    expect(() => apply(r), code('RETENTION_REVIEW_STALE'));
    expect(
      () => repo.configureCheckpointRetention(
        writer,
        rev(),
        1,
        confirmed: false,
        validateStorageAuthority: guard,
      ),
      code('RETENTION_CONFIRMATION_REQUIRED'),
    );
    for (final invalid in [0, -1, 10001]) {
      expect(() => configure(invalid), code('RETENTION_POLICY_INVALID'));
    }
    expect(
      () => repo.applyCheckpointPruning(
        writer,
        rev(),
        reviewHash: review()['reviewHash'],
        confirmed: false,
        validateStorageAuthority: guard,
      ),
      code('RETENTION_CONFIRMATION_REQUIRED'),
    );
  });
  test('REAL audit SQL failure and lost ownership after deletion roll back ALL indexes and audit', () {
    for (var i = 0; i < 4; i++) {
      repo.captureCheckpoint(writer);
      rename();
    }
    repo.captureCheckpoint(writer);
    configure(1);
    final r = review(), n = count('checkpoints');
    db.execute(
      "CREATE TRIGGER fail_prune BEFORE INSERT ON checkpoint_prune_audits BEGIN SELECT RAISE(ABORT,'injected audit failure'); END",
    );
    expect(() => apply(r), throwsA(isA<SqliteException>()));
    expect(count('checkpoints'), n);
    expect(count('checkpoint_prune_audits'), 0);
    db.execute('DROP TRIGGER fail_prune');
    var calls = 0;
    expect(
      () => repo.applyCheckpointPruning(
        writer,
        rev(),
        reviewHash: r['reviewHash'],
        confirmed: true,
        validateStorageAuthority: () {
          if (++calls == 2) {
            throw const StudioException('AUTHORITY_LOST');
          }
        },
      ),
      code('AUTHORITY_LOST'),
    );
    expect(count('checkpoints'), n);
    expect(count('checkpoint_prune_audits'), 0);
    expect(apply(r)['removedCheckpointIds'], isNotEmpty);
  });
  test('REAL other projects/namespaces and ANY session plan retain their roots; corrupt root refuses review', () {
    for (var i = 0; i < 3; i++) {
      repo.captureCheckpoint(writer);
      rename();
    }
    repo.captureCheckpoint(writer);
    configure(1);
    repo.create(
      ProjectDocument.empty(namespace: ns, projectId: 'other', title: 'Other'),
    );
    final other = repo.acquireWriter('other', 'other-owner', expectedEpoch: 0);
    repo.captureCheckpoint(other);
    final different = DocumentRepository.open(
      '${dir.path}/db',
      Namespace('studio', 'local', 'different'),
    );
    different.create(
      ProjectDocument.empty(
        namespace: different.namespace,
        projectId: 'p',
        title: 'Other namespace',
      ),
    );
    different.captureCheckpoint(
      different.acquireWriter('p', 'own', expectedEpoch: 0),
    );
    different.close();
    final otherRows = db
        .select("SELECT * FROM checkpoints WHERE project_id='other' OR ns<>?", [
          ns.key,
        ])
        .map((r) => r.values.toList())
        .toList();
    db.execute('INSERT INTO harness_plans VALUES(?,?,?,?,?,?,?,?)', [
      ns.key,
      'session',
      'plan',
      'p',
      '{}',
      0,
      0,
      'boot',
    ]);
    expect(review()['candidates'], isEmpty);
    db.execute('DELETE FROM harness_plans');
    apply(review());
    expect(
      db
          .select(
            "SELECT * FROM checkpoints WHERE project_id='other' OR ns<>?",
            [ns.key],
          )
          .map((r) => r.values.toList())
          .toList(),
      otherRows,
    );
    db.execute(
      "UPDATE snapshots SET json='{}' WHERE hash IN (SELECT snapshot_hash FROM checkpoints WHERE ns=? AND project_id=?)",
      [ns.key, 'p'],
    );
    expect(review, throwsA(isA<StudioException>()));
  });
  test('REAL v7 through v8/v9 migration atomic failure/reopen and integrity retain old snapshots/checkpoints', () {
    repo.captureCheckpoint(writer);
    final before = repo.read('p')!.hash;
    repo.close();
    for (final t in [
      'checkpoint_labels',
      'checkpoint_retention',
      'checkpoint_prune_audits',
      'import_maps',
    ]) {
      db.execute('DROP TABLE $t');
    }
    db.execute('DELETE FROM schema_migrations WHERE version>=8');
    db.userVersion = 7;
    db.execute('CREATE TABLE checkpoint_labels(dummy TEXT)');
    expect(
      () => DocumentRepository.open('${dir.path}/db', ns),
      throwsA(isA<SqliteException>()),
    );
    expect(db.userVersion, 7);
    expect(
      db.select(
        "SELECT name FROM sqlite_master WHERE name='checkpoint_retention'",
      ),
      isEmpty,
    );
    expect(
      db.select('SELECT * FROM schema_migrations WHERE version=8'),
      isEmpty,
    );
    db.execute('DROP TABLE checkpoint_labels');
    repo = DocumentRepository.open('${dir.path}/db', ns);
    expect(db.userVersion, 9);
    expect(repo.read('p')!.hash, before);
    expect(count('checkpoints'), 1);
    expect(db.select('PRAGMA foreign_key_check'), isEmpty);
    expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
    repo.close();
    repo = DocumentRepository.open('${dir.path}/db', ns);
    expect(repo.read('p')!.hash, before);
  });
  test('REAL SIGKILL after index deletes and audit insert rolls back; next writer re-reviews and commits', () async {
    for (var i = 0; i < 4; i++) {
      repo.captureCheckpoint(writer);
      rename();
    }
    repo.captureCheckpoint(writer);
    configure(1);
    final before = count('checkpoints'), hash = repo.read('p')!.hash;
    final blobs = BlobStore(Directory('${dir.path}/media'), ns)
      ..noteDatabaseUsage('${dir.path}/db');
    repo.close();
    final child = await Process.start(Platform.resolvedExecutable, [
      'run',
      'packages/studio_store/tool/checkpoint_prune_worker.dart',
      '${dir.path}/db',
      '${dir.path}/media',
    ]);
    final errors = child.stderr.transform(utf8.decoder).join();
    try {
      await child.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((v) => v == 'PRUNED_UNCOMMITTED')
          .timeout(const Duration(seconds: 20));
      child.kill(ProcessSignal.sigkill);
      expect(await child.exitCode, -ProcessSignal.sigkill.signalNumber);
      await errors;
      repo = DocumentRepository.open('${dir.path}/db', ns);
      expect(count('checkpoints'), before);
      expect(count('checkpoint_prune_audits'), 0);
      expect(repo.read('p')!.hash, hash);
      writer = repo.acquireWriter(
        'p',
        'recovered-owner',
        expectedEpoch: repo.writerEpoch('p'),
      );
      await blobs.withMaintenanceLease(() async {
        final r = review();
        expect(r['candidates'], isNotEmpty);
        repo.applyCheckpointPruning(
          writer,
          rev(),
          reviewHash: r['reviewHash'],
          confirmed: true,
          validateStorageAuthority: () =>
              blobs.requireExclusiveRepairDatabase('${dir.path}/db'),
        );
      });
      expect(count('checkpoints'), 1);
      expect(count('checkpoint_prune_audits'), 1);
      expect(repo.checkpointPruneAuditHistory('p'), hasLength(1));
      final audit = repo.checkpointPruneAuditHistory('p').single;
      final damaged = Map<String, dynamic>.from(audit)
        ..['removedCheckpointIds'] = <String>[];
      db.execute('UPDATE checkpoint_prune_audits SET json=?', [
        jsonEncode(damaged),
      ]);
      expect(
        () => repo.checkpointPruneAuditHistory('p'),
        code('STORE_INTEGRITY'),
      );
      db.execute('UPDATE checkpoint_prune_audits SET json=?', [
        jsonEncode(audit),
      ]);

      expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
    } finally {
      child.kill(ProcessSignal.sigkill);
      await child.exitCode;
    }
  });
}
