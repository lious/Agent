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
Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);
List<Map> audios(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    if (t['kind'] == 'audio')
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
];
String policyOf(ProjectDocument p, String clipId) {
  final g = (p.toJson()['linkGroups'] as List).singleWhere(
    (g) => (g['members'] as List).any((m) => m['clipId'] == clipId),
  );
  return g['syncPolicy'] as String;
}

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

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('ignore-links-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test(
    'ignore links moves only selected video, one command, undo/reopen/fork/AAC',
    () async {
      final firstVideo = moveVideos(w.current).first['id'] as String;
      final firstAudio = audios(w.current).first['id'] as String;
      final lastVideo = moveVideos(w.current).last['id'] as String;
      final lastAudio = audios(w.current).last['id'] as String;
      final before = w.current;
      expect(startOf(moveVideos(before).last), Q.of(3, 2));
      expect(startOf(audios(before).last), Q.of(3, 2));
      expect(policyOf(before, lastVideo), 'preserve');
      final counts = journal(root);
      w.edit(
        MoveClips([lastVideo], Q.of(1, 2), includeLinks: false),
        expectedRevision: w.current.revision,
      );
      expect(w.current.revision, before.revision + BigInt.one);
      expect(
        journal(root).values.reduce((a, b) => a + b),
        greaterThan(counts.values.reduce((a, b) => a + b)),
      );
      expect(
        startOf(moveVideos(w.current).singleWhere((c) => c['id'] == lastVideo)),
        Q.of(2),
      );
      expect(
        startOf(audios(w.current).singleWhere((c) => c['id'] == lastAudio)),
        Q.of(3, 2),
      );
      expect(
        startOf(
          moveVideos(w.current).singleWhere((c) => c['id'] == firstVideo),
        ),
        Q.of(0),
      );
      expect(
        startOf(audios(w.current).singleWhere((c) => c['id'] == firstAudio)),
        Q.of(0),
      );
      expect(policyOf(w.current, lastVideo), 'allowOutOfSync');
      expect(policyOf(w.current, firstVideo), 'preserve');
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), contents(before));
      expect(policyOf(w.current, lastVideo), 'preserve');
      w.redo(expectedRevision: w.current.revision);
      final redone = w.current;
      w.openDemo();
      expect(contents(w.current), contents(redone));
      expect(policyOf(w.current, lastVideo), 'allowOutOfSync');
      final archive = File('${root.path}/ignore-links.studio-project');
      await w.saveArchive(archive);
      await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
      expect(w.canUndo, false);
      expect(
        policyOf(w.current, moveVideos(w.current).last['id'] as String),
        'allowOutOfSync',
      );
      final out = await w.exportVideo(
        File('${root.path}/ignore-links.mp4'),
        captureFrames: const [0, 15],
      );
      expect(out['audio'], 'aac');
      expect(
        File('${root.path}/ignore-links.mp4').lengthSync(),
        greaterThan(1000),
      );
    },
  );

  test('default closure, locks, SQL and fence still refuse wholly', () async {
    final lastVideo = moveVideos(w.current).last['id'] as String;
    final lastAudio = audios(w.current).last['id'] as String;
    final baseline = w.current;
    w.edit(
      MoveClips([lastVideo], Q.of(1, 2)),
      expectedRevision: w.current.revision,
    );
    expect(
      startOf(audios(w.current).singleWhere((c) => c['id'] == lastAudio)),
      Q.of(2),
    );
    expect(policyOf(w.current, lastVideo), 'preserve');
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(baseline));
    final frozen = w.current.hash;
    final counts = journal(root);
    final db = sqlite3.open('${root.path}/db');
    db.execute(
      "CREATE TRIGGER il_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );
    try {
      expect(
        () => w.edit(
          MoveClips([lastVideo], Q.of(1, 2), includeLinks: false),
          expectedRevision: w.current.revision,
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(w.current.hash, frozen);
      expect(journal(root), counts);
    } finally {
      db.execute('DROP TRIGGER il_fail');
      db.dispose();
    }
    await adoptMoveMetadata(w, root, (d) {
      d['sequences'][0]['tracks'][0]['locked'] = true;
    });
    final lockedHash = w.current.hash;
    expect(
      () => w.edit(
        MoveClips(
          [moveVideos(w.current).last['id'] as String],
          Q.of(1, 2),
          includeLinks: false,
        ),
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
            [moveVideos(w.current).last['id'] as String],
            Q.of(1, 2),
            includeLinks: false,
          ),
          expectedRevision: w.current.revision,
        ),
        code('WRITER_FENCED'),
      );
    } finally {
      repository.close();
    }
    expect(lastAudio, isNotEmpty);
  });
}
