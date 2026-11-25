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
    root = Directory.systemTemp.createTempSync('ripple-delete-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test(
    'ripple delete closes linked AV, one command, undo/reopen/fork/AAC',
    () async {
      final firstId = moveVideos(w.current).first['id'] as String;
      final lastId = moveVideos(w.current).last['id'] as String;
      final before = w.current;
      final oldDur = seqDur(before);
      final counts = journal(root);
      final pixels = await w.previewTimelineAt(Q.of(3, 2));
      w.edit(
        RippleDeleteClips([firstId]),
        expectedRevision: w.current.revision,
      );
      expect(w.current.revision, before.revision + BigInt.one);
      expect(
        journal(root).values.reduce((a, b) => a + b),
        greaterThan(counts.values.reduce((a, b) => a + b)),
      );
      expect(moveVideos(w.current).where((c) => c['id'] == firstId), isEmpty);
      final last = moveVideos(w.current).singleWhere((c) => c['id'] == lastId);
      expect(startOf(last), Q.of(0));
      expect(seqDur(w.current), oldDur - Q.of(3, 2));
      expect((await w.previewTimelineAt(Q.of(0))).rgba, pixels.rgba);
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), contents(before));
      w.redo(expectedRevision: w.current.revision);
      final redone = w.current;
      w.openDemo();
      expect(contents(w.current), contents(redone));
      final archive = File('${root.path}/ripple-delete.studio-project');
      await w.saveArchive(archive);
      await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
      expect(w.canUndo, false);
      final out = await w.exportVideo(
        File('${root.path}/ripple-delete.mp4'),
        captureFrames: const [0, 15],
      );
      expect(out['audio'], 'aac');
      expect(
        File('${root.path}/ripple-delete.mp4').lengthSync(),
        greaterThan(1000),
      );
    },
  );

  test(
    'lift still leaves a gap; ripple delete locks/SQL/fence refuse wholly',
    () async {
      final firstId = moveVideos(w.current).first['id'] as String;
      final lastId = moveVideos(w.current).last['id'] as String;
      final baseline = w.current;
      final oldDur = seqDur(baseline);
      w.edit(LiftClips([lastId]), expectedRevision: w.current.revision);
      expect(seqDur(w.current), oldDur);
      expect(startOf(moveVideos(w.current).first), Q.of(0));
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), contents(baseline));
      final preRipple = w.current;
      w.edit(RippleDeleteClips([lastId]), expectedRevision: w.current.revision);
      expect(w.current.revision, preRipple.revision + BigInt.one);
      expect(seqDur(w.current), oldDur - Q.of(3, 2));
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), contents(baseline));
      final frozen = w.current.hash;
      final counts = journal(root);
      final db = sqlite3.open('${root.path}/db');
      db.execute(
        "CREATE TRIGGER rd_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      try {
        expect(
          () => w.edit(
            RippleDeleteClips([firstId]),
            expectedRevision: w.current.revision,
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(w.current.hash, frozen);
        expect(journal(root), counts);
      } finally {
        db.execute('DROP TRIGGER rd_fail');
        db.dispose();
      }
      await adoptMoveMetadata(w, root, (d) {
        d['sequences'][0]['tracks'][0]['locked'] = true;
      });
      final lockedFirst = moveVideos(w.current).first['id'] as String;
      final lockedHash = w.current.hash;
      expect(
        () => w.edit(
          RippleDeleteClips([lockedFirst]),
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
            RippleDeleteClips([moveVideos(w.current).first['id'] as String]),
            expectedRevision: w.current.revision,
          ),
          code('WRITER_FENCED'),
        );
      } finally {
        repository.close();
      }
    },
  );

  test(
    'ripple delete refuses when absolute captions would have to shift',
    () async {
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
          RippleDeleteClips([moveVideos(w.current).first['id'] as String]),
          expectedRevision: w.current.revision,
        ),
        code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
      );
      expect(w.current.hash, captioned);
    },
  );
}
