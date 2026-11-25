import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

Q cueStart(ProjectDocument p) =>
    Q.fromJson(p.toJson()['captions'][0]['timelineRange']['start']);

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('caption-default-cliplocal-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('import of a uniquely covered cue defaults to clipLocal, one command, undo/reopen/fork/sidecar', () async {
    final srt = File('${root.path}/cue.srt')
      ..writeAsStringSync('1\n00:00:01,500 --> 00:00:02,000\nFollows last\n');
    await w.importCaptions(
      LocalFileGrant.fromUserSelection(srt),
      CaptionFormat.srt,
      expectedRevision: w.current.revision,
    );
    final lastVideo = moveVideos(w.current).last['id'] as String;
    expect(w.current.toJson()['captions'][0]['anchor']['kind'], 'clipLocal');
    expect(w.current.toJson()['captions'][0]['anchor']['clipId'], lastVideo);
    expect(cueStart(w.current), Q.of(3, 2));
    final before = w.current;
    w.edit(
      MoveClips([lastVideo], Q.of(1, 2), includeLinks: false),
      expectedRevision: w.current.revision,
    );
    expect(w.current.revision, before.revision + BigInt.one);
    expect(startOf(moveVideos(w.current).last), Q.of(2));
    expect(cueStart(w.current), Q.of(2));
    expect(w.current.toJson()['captions'][0]['text'], 'Follows last');
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(before));
    w.redo(expectedRevision: w.current.revision);
    final redone = w.current;
    w.openDemo();
    expect(contents(w.current), contents(redone));
    final archive = File('${root.path}/caption-default.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(cueStart(w.current), Q.of(2));
    expect(w.current.toJson()['captions'][0]['anchor']['kind'], 'clipLocal');
    final sidecar = File('${root.path}/default.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    expect(
      CaptionFormats.decode(
        sidecar.readAsStringSync(),
        CaptionFormat.vtt,
      ).captions.cues.single.range.start,
      Q.of(2),
    );
    await expectLater(
      w.exportVideo(File('${root.path}/must-not.mp4')),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    expect(File('${root.path}/must-not.mp4').existsSync(), false);
  });

  test(
    'import spanning a cut stays absolute; SQL failure is a no-op',
    () async {
      final srt = File('${root.path}/span.srt')
        ..writeAsStringSync('1\n00:00:00,000 --> 00:00:02,000\nSpans cut\n');
      await w.importCaptions(
        LocalFileGrant.fromUserSelection(srt),
        CaptionFormat.srt,
        expectedRevision: w.current.revision,
      );
      expect(w.current.toJson()['captions'][0]['anchor']['kind'], 'absolute');
      final lastVideo = moveVideos(w.current).last['id'] as String;
      final imported = w.current;
      final lastStart = startOf(moveVideos(w.current).last);
      w.edit(
        MoveClips([lastVideo], Q.of(1, 2), includeLinks: false),
        expectedRevision: w.current.revision,
      );
      expect(startOf(moveVideos(w.current).last), lastStart + Q.of(1, 2));
      expect(cueStart(w.current), Q.of(0));
      w.undo(expectedRevision: w.current.revision);
      expect(contents(w.current), contents(imported));
      final frozen = w.current.hash;
      final db = sqlite3.open('${root.path}/db');
      db.execute(
        "CREATE TRIGGER cap_default_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
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
      } finally {
        db.execute('DROP TRIGGER cap_default_fail');
        db.dispose();
      }
    },
  );
}
