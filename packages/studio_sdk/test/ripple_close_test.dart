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
Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);
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
    root = Directory.systemTemp.createTempSync('ripple-close-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test(
    'close vacated insert-move hole, one command, undo/reopen/fork/AAC',
    () async {
      final firstId = moveVideos(w.current).first['id'] as String;
      final lastId = moveVideos(w.current).last['id'] as String;
      final original = w.current;
      final oldDur = seqDur(original);
      w.edit(
        MoveClips([firstId], Q.of(3, 2), mode: 'insert'),
        expectedRevision: w.current.revision,
      );
      expect(seqDur(w.current), oldDur + Q.of(3, 2));
      expect(
        startOf(moveVideos(w.current).singleWhere((c) => c['id'] == firstId)),
        Q.of(3, 2),
      );
      final moved = w.current;
      final counts = journal(root);
      w.edit(
        RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(3, 2))),
        expectedRevision: w.current.revision,
      );
      expect(w.current.revision, moved.revision + BigInt.one);
      expect(
        journal(root).values.reduce((a, b) => a + b),
        greaterThan(counts.values.reduce((a, b) => a + b)),
      );
      expect(seqDur(w.current), oldDur);
      expect(
        startOf(moveVideos(w.current).singleWhere((c) => c['id'] == firstId)),
        Q.of(0),
      );
      expect(
        startOf(moveVideos(w.current).singleWhere((c) => c['id'] == lastId)),
        Q.of(3, 2),
      );
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), contents(moved));
      expect(seqDur(w.current), oldDur + Q.of(3, 2));
      w.redo(expectedRevision: w.current.revision);
      final redone = w.current;
      w.openDemo();
      expect(contents(w.current), contents(redone));
      final archive = File('${root.path}/ripple-close.studio-project');
      await w.saveArchive(archive);
      await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
      expect(w.canUndo, false);
      final out = await w.exportVideo(
        File('${root.path}/ripple-close.mp4'),
        captureFrames: const [0, 15],
      );
      expect(out['audio'], 'aac');
      expect(
        File('${root.path}/ripple-close.mp4').lengthSync(),
        greaterThan(1000),
      );
    },
  );

  test(
    'insert-move gap remains until close; locks/SQL/fence refuse wholly',
    () async {
      final firstId = moveVideos(w.current).first['id'] as String;
      final baseline = w.current;
      final oldDur = seqDur(baseline);
      w.edit(
        MoveClips([firstId], Q.of(3, 2), mode: 'insert'),
        expectedRevision: w.current.revision,
      );
      expect(seqDur(w.current), oldDur + Q.of(3, 2));
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), contents(baseline));
      // Re-apply the move so the hole exists, then refuse close on locks/SQL/fence.
      w.edit(
        MoveClips([firstId], Q.of(3, 2), mode: 'insert'),
        expectedRevision: w.current.revision,
      );
      final pre = w.current;
      final frozen = pre.hash;
      final counts = journal(root);
      final db = sqlite3.open('${root.path}/db');
      db.execute(
        "CREATE TRIGGER rc_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      try {
        expect(
          () => w.edit(
            RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(3, 2))),
            expectedRevision: w.current.revision,
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(w.current.hash, frozen);
        expect(journal(root), counts);
      } finally {
        db.execute('DROP TRIGGER rc_fail');
        db.dispose();
      }
      await adoptMoveMetadata(w, root, (d) {
        d['sequences'][0]['tracks'][0]['locked'] = true;
      });
      final lockedHash = w.current.hash;
      expect(
        () => w.edit(
          RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(3, 2))),
          expectedRevision: w.current.revision,
        ),
        code('SYNC_LOCKED'),
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
            RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(3, 2))),
            expectedRevision: w.current.revision,
          ),
          code('WRITER_FENCED'),
        );
      } finally {
        repository.close();
      }
      expect(seqDur(pre), oldDur + Q.of(3, 2));
    },
  );

  test(
    'range close refuses when absolute captions would have to shift',
    () async {
      final firstId = moveVideos(w.current).first['id'] as String;
      w.edit(
        MoveClips([firstId], Q.of(3, 2), mode: 'insert'),
        expectedRevision: w.current.revision,
      );
      final srt = File('${root.path}/cue.srt')
        ..writeAsStringSync('1\n00:00:00,000 --> 00:00:02,000\nAbsolute cue\n');
      await w.importCaptions(
        LocalFileGrant.fromUserSelection(srt),
        CaptionFormat.srt,
        expectedRevision: w.current.revision,
      );
      final captioned = w.current.hash;
      expect(
        () => w.edit(
          RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(3, 2))),
          expectedRevision: w.current.revision,
        ),
        code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
      );
      expect(w.current.hash, captioned);
    },
  );
}
