import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));
List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];
Map<String, int> journal(Directory root) {
  final db = sqlite3.open('${root.path}/db');
  try {
    return {
      for (final t in [
        'commands',
        'revisions',
        'receipts',
        'events',
        'outbox',
        'entity_versions',
        'blob_edges',
      ])
        t: db.select('SELECT count(*) n FROM $t').single['n'] as int,
    };
  } finally {
    db.dispose();
  }
}

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);
Q durOf(Map c) => Q.fromJson(c['timelineRange']['duration']);

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('overwrite-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('overwrite paste carves linked destinations, one command, undo/reopen/fork/AAC', () async {
    final first = moveVideos(w.current).first;
    final last = moveVideos(w.current).last;
    final firstId = first['id'] as String;
    final lastId = last['id'] as String;
    final before = w.current;
    final counts = journal(root);
    w.copySelection([firstId]);
    expect(w.current.hash, before.hash);
    expect(journal(root), counts);
    expect(
      () => w.pasteClipboard(at: Q.of(0), expectedRevision: w.current.revision),
      code('COLLISION'),
    );
    expect(w.current.hash, before.hash);
    final at = Q.of(1, 2); // 0.5s = 15 frames at 30fps
    final pixels = await w.previewTimelineAt(Q.of(0));
    w.pasteClipboard(
      at: at,
      mode: 'overwrite',
      expectedRevision: w.current.revision,
    );
    expect(w.current.revision, before.revision + BigInt.one);
    expect(
      journal(root).values.reduce((a, b) => a + b),
      greaterThan(counts.values.reduce((a, b) => a + b)),
    );
    final firstAfter = moveVideos(w.current)
        .singleWhere((c) => c['id'] == firstId);
    expect(startOf(firstAfter), Q.of(0));
    expect(durOf(firstAfter), at);
    final lastAfter = moveVideos(w.current)
        .singleWhere((c) => c['id'] == lastId);
    expect(startOf(lastAfter), at + durOf(first));
    expect(
      Q.fromJson(w.current.toJson()['sequences'][0]['duration']),
      Q.fromJson(before.toJson()['sequences'][0]['duration']),
    );
    // Linked audio was also carved/placed; later uninvolved duration stays.
    expect(media(w.current).where((c) => c['linkGroupId'] != null), isNotEmpty);
    expect((await w.previewTimelineAt(Q.of(0))).rgba, pixels.rgba);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(before));
    w.redo(expectedRevision: w.current.revision);
    final redone = w.current;
    w.openDemo();
    expect(contents(w.current), contents(redone));
    final archive = File('${root.path}/overwrite.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(w.clipboard, isNull);
    final out = await w.exportVideo(
      File('${root.path}/overwrite.mp4'),
      captureFrames: const [0, 15],
    );
    expect(out['audio'], 'aac');
    expect(File('${root.path}/overwrite.mp4').lengthSync(), greaterThan(1000));
  });

  test('overwrite move is one command; locks/SQL/fence refuse wholly; reject is unchanged', () async {
    final firstId = moveVideos(w.current).first['id'] as String;
    final lastId = moveVideos(w.current).last['id'] as String;
    final baseline = w.current;
    expect(
      () => w.edit(
        MoveClips([firstId], Q.of(3, 2)),
        expectedRevision: w.current.revision,
      ),
      code('COLLISION'),
    );
    expect(w.current.hash, baseline.hash);
    w.edit(
      MoveClips([firstId], Q.of(3, 2), mode: 'overwrite'),
      expectedRevision: w.current.revision,
    );
    expect(w.current.revision, baseline.revision + BigInt.one);
    expect(
      startOf(moveVideos(w.current).singleWhere((c) => c['id'] == firstId)),
      Q.of(3, 2),
    );
    // Second 1.5s clip started at 1.5; destination [1.5,3) removes it.
    expect(moveVideos(w.current).where((c) => c['id'] == lastId), isEmpty);
    expect(
      Q.fromJson(w.current.toJson()['sequences'][0]['duration']),
      Q.fromJson(baseline.toJson()['sequences'][0]['duration']),
    );
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(baseline));
    final frozen = w.current.hash;
    final counts = journal(root);
    final db = sqlite3.open('${root.path}/db');
    db.execute(
      "CREATE TRIGGER ovw_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );
    try {
      expect(
        () => w.edit(
          MoveClips([firstId], Q.of(3, 2), mode: 'overwrite'),
          expectedRevision: w.current.revision,
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(w.current.hash, frozen);
      expect(journal(root), counts);
    } finally {
      db.execute('DROP TRIGGER ovw_fail');
      db.dispose();
    }
    await adoptMoveMetadata(w, root, (d) {
      d['sequences'][0]['tracks'][0]['locked'] = true;
    });
    final lockedFirst = moveVideos(w.current).first['id'] as String;
    final lockedHash = w.current.hash;
    expect(
      () => w.edit(
        MoveClips([lockedFirst], Q.of(3, 2), mode: 'overwrite'),
        expectedRevision: w.current.revision,
      ),
      code('FIELD_LOCKED'),
    );
    expect(w.current.hash, lockedHash);
    await adoptMoveMetadata(w, root, (d) {
      d['sequences'][0]['tracks'][0]['locked'] = false;
    });
    final repository = DocumentRepository.open(
      '${root.path}/db',
      w.current.namespace,
    );
    try {
      repository.acquireWriter(
        w.projectId,
        'fixture-other',
        expectedEpoch: repository.writerEpoch(w.projectId),
      );
      expect(
        () => w.edit(
          MoveClips(
            [moveVideos(w.current).first['id'] as String],
            Q.of(3, 2),
            mode: 'overwrite',
          ),
          expectedRevision: w.current.revision,
        ),
        code('WRITER_FENCED'),
      );
    } finally {
      repository.close();
    }
  });
}
