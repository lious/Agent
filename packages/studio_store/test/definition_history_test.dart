import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_store/project_archive.dart';

void main() {
  final ns = Namespace('studio', 'local', 'history');
  late Directory dir;
  late String path;
  late DocumentRepository repo;
  late Database db;
  late WriterToken writer;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('definition-history-');
    path = '${dir.path}/db';
    repo = DocumentRepository.open(path, ns);
    repo.create(
      ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'original'),
    );
    writer = repo.acquireWriter('p', 'owner', expectedEpoch: 0);
    db = sqlite3.open(path);
  });
  tearDown(() {
    repo.close();
    db.dispose();
    dir.deleteSync(recursive: true);
  });
  ProjectDocument proposal(String version, double gain) {
    final d = repo.read('p')!.toJson();
    d['sequences'][0]['version'] = version;
    d['audioBuses'][0]['gainDb'] = gain;
    return ProjectDocument.fromJson(d);
  }

  void gain(String command, double value) => repo.edit(
    writer: writer,
    commandId: command,
    receiptKey: command,
    expectedRevision: repo.read('p')!.revision,
    operation: SetMasterAudio(gainDb: value),
  );
  Matcher code(String s) =>
      throwsA(isA<StudioException>().having((e) => e.code, 'code', s));

  test('noncurrent version reuse resolves real dependencies; exact reuse allowed without writes; fresh checks do not teach history', () {
    gain('one', -6);
    gain('two', -9);
    final rows = db
        .select('SELECT * FROM entity_versions')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    final hash = repo.read('p')!.hash;
    expect(
      () => repo.checkDefinitionCompatibility(proposal('1', -3)),
      code('IMMUTABLE_VERSION_CONFLICT'),
    );
    repo.checkDefinitionCompatibility(proposal('1', -6));
    repo.checkDefinitionCompatibility(proposal('3', -3));
    repo.checkDefinitionCompatibility(proposal('3', -2));
    expect(repo.read('p')!.hash, hash);
    expect(
      db
          .select('SELECT * FROM entity_versions')
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
      rows,
    );
  });
  test('other connection invalidates proof cache; receipt replay and undo retain byte-exact old rows', () {
    gain('one', -6);
    final oldRows = db
        .select('SELECT * FROM entity_versions')
        .map((r) => Map<String, Object?>.from(r))
        .toList();
    final other = DocumentRepository.open(path, ns);
    other.edit(
      writer: writer,
      commandId: 'two',
      receiptKey: 'two',
      expectedRevision: BigInt.one,
      operation: const SetMasterAudio(gainDb: -9),
    );
    other.close();
    expect(
      () => repo.checkDefinitionCompatibility(proposal('2', -3)),
      code('IMMUTABLE_VERSION_CONFLICT'),
    );
    repo.undoLatest(
      writer: writer,
      commandId: 'undo',
      receiptKey: 'undo',
      expectedRevision: BigInt.two,
      targetCommandId: 'two',
    );
    expect(repo.read('p')!.toJson()['audioBuses'][0]['gainDb'], -6);
    for (final row in oldRows) {
      expect(
        db
            .select(
              'SELECT * FROM entity_versions WHERE entity_id=? AND version=?',
              [row['entity_id'], row['version']],
            )
            .map((r) => Map<String, Object?>.from(r))
            .single,
        row,
      );
    }
    repo.close();
    repo = DocumentRepository.open(path, ns);
    repo.checkDefinitionCompatibility(proposal('1', -6));
    expect(
      () => repo.checkDefinitionCompatibility(proposal('2', -3)),
      code('IMMUTABLE_VERSION_CONFLICT'),
    );
  });
  test('late SQL fault rolls back counters/history/head; rejected candidate cannot contaminate cache', () {
    final hash = repo.read('p')!.hash;
    db.execute(
      "CREATE TRIGGER fail_event BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture');END",
    );
    expect(() => gain('failed', -6), throwsA(isA<SqliteException>()));
    expect(repo.read('p')!.hash, hash);
    expect(db.select('SELECT * FROM commands'), isEmpty);
    db.execute('DROP TRIGGER fail_event');
    gain('success', -9);
    expect(
      () => repo.checkDefinitionCompatibility(proposal('1', -6)),
      code('IMMUTABLE_VERSION_CONFLICT'),
    );
    repo.checkDefinitionCompatibility(proposal('1', -9));
  });
  test('unknown raw hash and removed counter refuse; no automatic rewrite or source mutation', () {
    gain('one', -6);
    final hash = repo.read('p')!.hash;
    db.execute(
      "UPDATE entity_versions SET content_hash='corrupt' WHERE version=1",
    );
    expect(
      () => repo.checkDefinitionCompatibility(proposal('1', -6)),
      code('STORE_INTEGRITY'),
    );
    expect(
      db
          .select('SELECT content_hash FROM entity_versions WHERE version=1')
          .single['content_hash'],
      'corrupt',
    );
    db.execute('DELETE FROM entity_versions WHERE version=1');
    expect(
      () => repo.checkDefinitionCompatibility(proposal('1', -6)),
      code('STORE_INTEGRITY'),
    );
    expect(repo.read('p')!.hash, hash);
  });
  test('historical snapshot hash corruption refuses even if current metadata/legacy row matches', () {
    final original = repo.read('p')!;
    gain('one', -6);
    final bad = original.toJson()..['title'] = 'corrupt';
    db.execute('UPDATE snapshots SET json=? WHERE hash=?', [
      jsonEncode(bad),
      original.hash,
    ]);
    expect(
      () => repo.checkDefinitionCompatibility(proposal('1', -6)),
      code('STORE_INTEGRITY'),
    );
    db.execute('UPDATE snapshots SET json=? WHERE hash=?', [
      original.canonicalJson,
      original.hash,
    ]);
    repo.checkDefinitionCompatibility(proposal('1', -6));
  });
  test('orphan raw hash does not establish historical identity; foreign project/namespace cannot certify reuse', () {
    final candidate = proposal('1', -6);
    db.execute('INSERT INTO snapshots VALUES(?,?,?)', [
      ns.key,
      candidate.hash,
      candidate.canonicalJson,
    ]);
    db.execute('INSERT INTO entity_versions VALUES(?,?,?,?,?)', [
      ns.key,
      'p',
      'sequence-main',
      1,
      contentHash(candidate.toJson()['sequences'][0]),
    ]);
    expect(
      () => repo.checkDefinitionCompatibility(candidate),
      code('DEFINITION_HISTORY_UNQUALIFIED'),
    );
    final foreign = candidate.toJson()..['projectId'] = 'foreign';
    expect(
      () =>
          repo.checkDefinitionCompatibility(ProjectDocument.fromJson(foreign)),
      code('PROJECT_NOT_FOUND'),
    );
  });
  test('SQL parent-location fixture permits known-equivalent legacy raw mismatch without rewriting it', () {
    final d = jsonDecode(
      File('fixtures/project/local-video.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    d['namespace'] = ns.toJson();
    d['projectId'] = 'media';
    final original = ProjectDocument.fromJson(d);
    repo.create(original);
    final w = repo.acquireWriter('media', 'media-owner', expectedEpoch: 0);
    final clipId = d['sequences'][0]['tracks'][0]['items'][0]['id'];
    final oldRaw = db.select(
      'SELECT content_hash FROM entity_versions WHERE project_id=? AND entity_id=?',
      ['media', clipId],
    ).single['content_hash'];
    d['revision'] = '1';
    final seq = d['sequences'][0];
    seq['version'] = '2';
    seq['tracks'][0]['id'] = 'relocated-parent';
    for (final c in seq['tracks'][0]['items']) {
      c['trackId'] = 'relocated-parent';
    }
    final relocated = ProjectDocument.fromJson(d);
    db.execute('INSERT INTO snapshots VALUES(?,?,?)', [
      ns.key,
      relocated.hash,
      relocated.canonicalJson,
    ]);
    db.execute('INSERT INTO entity_versions VALUES(?,?,?,?,?)', [
      ns.key,
      'media',
      seq['id'],
      2,
      contentHash({'definition': seq, 'sources': d['assets']}),
    ]);
    db.execute('INSERT INTO commands VALUES(?,?,?,?,?,?,?,?,?)', [
      ns.key,
      'fixture-parent',
      'media',
      'fixture',
      0,
      original.hash,
      relocated.hash,
      original.hash,
      '{}',
    ]);
    db.execute('INSERT INTO revisions VALUES(?,?,?,?,?,?)', [
      ns.key,
      'media',
      1,
      0,
      relocated.hash,
      'fixture-parent',
    ]);
    db.execute(
      'UPDATE project_heads SET revision=1,snapshot_hash=? WHERE ns=? AND project_id=?',
      [relocated.hash, ns.key, 'media'],
    );
    db.execute('INSERT INTO events VALUES(?,?,?,?,?)', [
      ns.key,
      'media',
      1,
      'fixture-parent',
      original.hash,
    ]);
    db.execute(
      'UPDATE stream_heads SET next_seq=2 WHERE ns=? AND project_id=?',
      [ns.key, 'media'],
    );
    repo.rename(
      writer: w,
      commandId: 'rename-parent',
      receiptKey: 'rename-parent',
      expectedRevision: BigInt.one,
      title: 'known equivalent',
    );
    expect(
      db.select(
        'SELECT content_hash FROM entity_versions WHERE project_id=? AND entity_id=?',
        ['media', clipId],
      ).single['content_hash'],
      oldRaw,
    );
    expect(
      db.select('SELECT json FROM snapshots WHERE hash=?', [
        original.hash,
      ]).single['json'],
      original.canonicalJson,
    );
    expect(repo.read('media')!.title, 'known equivalent');
  });
  test('zero cache streams identical source proofs and still rejects noncurrent conflicts', () {
    gain('one', -6);
    gain('two', -9);
    repo.close();
    repo = DocumentRepository.open(path, ns, definitionHistoryCacheLimit: 0);
    repo.checkDefinitionCompatibility(proposal('1', -6));
    expect(
      () => repo.checkDefinitionCompatibility(proposal('1', -3)),
      code('IMMUTABLE_VERSION_CONFLICT'),
    );
    repo.undoLatest(
      writer: writer,
      commandId: 'undo-stream',
      receiptKey: 'undo-stream',
      expectedRevision: BigInt.two,
      targetCommandId: 'two',
    );
    expect(repo.read('p')!.toJson()['audioBuses'][0]['gainDb'], -6);
    expect(
      () => DocumentRepository.open(
        ':memory:',
        ns,
        definitionHistoryCacheLimit: -1,
      ),
      code('DEFINITION_CACHE_LIMIT_INVALID'),
    );
  });
  test('real preservation archive/fork/reopen retain original historical bytes and independent definition authority', () async {
    gain('one', -6);
    final current = repo.read('p')!, file = File('${dir.path}/project.studio');
    await ProjectArchive().preparePreservation(current, {}, file);
    final opened = ProjectArchive().open(file, preservationOnly: true);
    expect(opened.project.canonicalJson, current.canonicalJson);
    var i = 0;
    final fork = forkLocalProject(
      opened.project,
      ns,
      newId: () => 'fork-${++i}',
    );
    repo.create(fork);
    repo.checkDefinitionCompatibility(fork);
    expect(repo.read('p')!.hash, current.hash);
    repo.close();
    repo = DocumentRepository.open(path, ns);
    repo.checkDefinitionCompatibility(proposal('1', -6));
    expect(repo.read(fork.projectId)!.canonicalJson, fork.canonicalJson);
  });
}
