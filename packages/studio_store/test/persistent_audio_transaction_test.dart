import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:sqlite3/sqlite3.dart';

ProjectDocument avFixture() {
  final d = jsonDecode(
    File('fixtures/project/local-video.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final st = Map<String, dynamic>.from(d['assets'][0]['streams'][0] as Map)
    ..addAll({
      'id': 'audio-stream',
      'type': 'audio',
      'codec': 'aac',
      'profile': 'LC',
      'width': null,
      'height': null,
      'pixelFormat': null,
      'color': null,
      'nominalFrameRate': null,
      'sampleRate': 48000,
      'channels': 2,
      'channelLayout': 'stereo',
      'timeBase': Q.of(1, 48000).toJson(),
    });
  (d['assets'][0]['streams'] as List).add(st);
  return ProjectDocument.fromJson(d);
}

void main() {
  test('REAL SQLite persistent AV extraction all-table rollback, retry/idempotency, stale CAS, undo and reopen', () {
    final dir = Directory.systemTemp.createTempSync('persistent-audio-sql-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/project.db', p = avFixture();
    var repo = DocumentRepository.open(path, p.namespace);
    repo.create(p);
    final writer = repo.acquireWriter(p.projectId, 'owner', expectedEpoch: 0);
    final db = sqlite3.open(path);
    Map<String, Object?> counts() => {
      for (final row in db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      ))
        row['name'] as String: db
            .select('SELECT count(*) AS n FROM "${row['name']}"')
            .single['n'],
    };
    final initial = counts(),
        hash = p.hash,
        video =
            p.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'] as String;
    db.execute(
      "CREATE TRIGGER audio_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'after audio definitions'); END",
    );
    void extract() => repo.edit(
      writer: writer,
      commandId: 'extract',
      receiptKey: 'extract',
      expectedRevision: BigInt.zero,
      operation: ExtractAudioClip(video, 'audio-stream'),
    );
    expect(extract, throwsA(isA<SqliteException>()));
    expect(counts(), initial);
    expect(repo.read(p.projectId)!.hash, hash);
    db.execute('DROP TRIGGER audio_fail');
    extract();
    final linked = repo.read(p.projectId)!;
    expect(linked.toJson()['linkGroups'].length, 1);
    final committed = counts();
    extract();
    expect(counts(), committed);
    expect(repo.read(p.projectId)!.hash, linked.hash);
    expect(
      () => repo.edit(
        writer: writer,
        commandId: 'stale',
        receiptKey: 'stale',
        expectedRevision: BigInt.zero,
        operation: UnlinkAudioVideo(
          linked.toJson()['linkGroups'][0]['id'] as String,
        ),
      ),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'REVISION_CONFLICT',
        ),
      ),
    );
    expect(counts(), committed);
    repo.undoLatest(
      writer: writer,
      commandId: 'undo',
      targetCommandId: 'extract',
      receiptKey: 'undo',
      expectedRevision: linked.revision,
    );
    expect(repo.read(p.projectId)!.toJson()['linkGroups'], isEmpty);
    expect(
      repo.read(p.projectId)!.toJson()['sequences'][0]['tracks'].length,
      1,
    );
    expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
    expect(db.select('PRAGMA foreign_key_check'), isEmpty);
    final saved = repo.read(p.projectId)!.hash;
    repo.close();
    repo = DocumentRepository.open(path, p.namespace);
    expect(repo.read(p.projectId)!.hash, saved);
    repo.close();
    db.dispose();
  });
  test('rich Schema project remains read-only: unsupported image/story/plugin writes refuse without definitions, preserving opaque data', () {
    final dir = Directory.systemTemp.createTempSync('rich-sql-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final p = ProjectDocument.fromJson(
          jsonDecode(
            File('fixtures/project/semantic-rich.json').readAsStringSync(),
          ) as Map<String, dynamic>,
        ),
        path = '${dir.path}/db';
    final repo = DocumentRepository.open(path, p.namespace);
    expect(
      () => repo.create(p),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'FEATURE_NOT_IMPLEMENTED',
        ),
      ),
    );
    expect(repo.read(p.projectId), isNull);
    repo.close();
    final db = sqlite3.open(path);
    expect(
      db.select('SELECT count(*) AS n FROM entity_versions').single['n'],
      0,
    );
    expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
    db.dispose();
  });
  test('REAL SQLite unlinked audio split undo/re-edit never reuses a retired immutable version', () {
    final dir = Directory.systemTemp.createTempSync('audio-version-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final p = avFixture(),
        repo = DocumentRepository.open('${dir.path}/db', p.namespace);
    addTearDown(repo.close);
    repo.create(p);
    final writer = repo.acquireWriter(p.projectId, 'owner', expectedEpoch: 0);
    var n = 0;
    void edit(EditOperation op) => repo.edit(
      writer: writer,
      commandId: 'op-${n++}',
      receiptKey: 'key-$n',
      expectedRevision: repo.read(p.projectId)!.revision,
      operation: op,
    );
    final video =
        p.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'] as String;
    edit(ExtractAudioClip(video, 'audio-stream'));
    var d = repo.read(p.projectId)!.toJson();
    final audio = d['sequences'][0]['tracks'][1]['items'][0]['id'] as String;
    edit(UnlinkAudioVideo(d['linkGroups'][0]['id'] as String));
    edit(SplitClip(audio, Q.of(1), 'audio-reuse'));
    d = repo.read(p.projectId)!.toJson();
    final first = BigInt.parse(
      d['sequences'][0]['tracks'][1]['items'][1]['version'] as String,
    );
    repo.undoLatest(
      writer: writer,
      commandId: 'undo-split',
      receiptKey: 'undo-split',
      targetCommandId: 'op-2',
      expectedRevision: repo.read(p.projectId)!.revision,
    );
    edit(SplitClip(audio, Q.of(1), 'audio-reuse'));
    final next = BigInt.parse(
      repo
              .read(p.projectId)!
              .toJson()['sequences'][0]['tracks'][1]['items'][1]['version']
          as String,
    );
    expect(next, greaterThan(first));
  });
  test('archive fork remaps AV group, anchor, members and clip backlinks without mutating original', () {
    var serial = 0;
    final p = avFixture(),
        video =
            p.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'] as String;
    final linked = applyEdit(
      p,
      ExtractAudioClip(video, 'audio-stream'),
      newId: () => 'new-${serial++}',
      nextVersion: (_) => '10',
    );
    final hash = linked.hash;
    final fork = forkLocalProject(
          linked,
          linked.namespace,
          newId: () => 'fork-${serial++}',
        ),
        d = fork.toJson(),
        g = d['linkGroups'][0],
        clips = [
          for (final t in d['sequences'][0]['tracks'])
            for (final c in t['items'])
              if (c['source'] != null) c,
        ];
    final ids = clips.map((c) => c['id']).toSet();
    expect(ids.contains(g['anchorClipId']), isTrue);
    expect(
      (g['members'] as List).every((m) => ids.contains(m['clipId'])),
      isTrue,
    );
    expect(clips.every((c) => c['linkGroupId'] == g['id']), isTrue);
    expect(fork.projectId, isNot(linked.projectId));
    expect(linked.hash, hash);
  });
}
