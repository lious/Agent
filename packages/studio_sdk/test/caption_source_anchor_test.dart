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

Map cue(ProjectDocument p) => p.toJson()['captions'][0] as Map;

void attachLastVideoSourceCue(
  StudioWorkspace w, {
  String text = 'source of last',
}) {
  final last = moveVideos(w.current).last;
  final id = last['id'] as String;
  final cs = startOf(last);
  final anchored =
      CaptionCue(
        'source-cue',
        TimeRange(cs, Q.of(1, 2)),
        text,
        manualFields: {'text', 'timing'},
      ).anchoredToSource(
        clipId: id,
        clipStart: cs,
        clipDuration: Q.fromJson(last['timelineRange']['duration']),
        sourceDuration: Q.fromJson(last['sourceRange']['duration']),
        rate: Q.fromJson(last['timeMap']['rate']),
      );
  w.edit(
    SetCaptions(CaptionStore([anchored])),
    expectedRevision: w.current.revision,
  );
}

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('caption-source-anchor-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('source cue follows one MoveClips, undo/reopen/fork/sidecar; MP4 stays refused', () async {
    attachLastVideoSourceCue(w);
    final lastVideo = moveVideos(w.current).last['id'] as String;
    expect(cue(w.current)['anchor']['kind'], 'source');
    expect(cue(w.current)['anchor']['clipId'], lastVideo);
    expect(cueStart(w.current), Q.of(3, 2));
    final before = w.current;
    w.edit(
      MoveClips([lastVideo], Q.of(1, 2), includeLinks: false),
      expectedRevision: w.current.revision,
    );
    expect(w.current.revision, before.revision + BigInt.one);
    expect(startOf(moveVideos(w.current).last), Q.of(2));
    expect(cueStart(w.current), Q.of(2));
    expect(cue(w.current)['text'], 'source of last');
    expect(cue(w.current)['anchor']['kind'], 'source');
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(before));
    w.redo(expectedRevision: w.current.revision);
    final redone = w.current;
    w.openDemo();
    expect(contents(w.current), contents(redone));
    final archive = File('${root.path}/caption-source.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(cueStart(w.current), Q.of(2));
    expect(cue(w.current)['anchor']['kind'], 'source');
    final sidecar = File('${root.path}/source.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    expect(
      CaptionFormats.decode(
        sidecar.readAsStringSync(),
        CaptionFormat.vtt,
      ).captions.cues.single.range.start,
      Q.of(2),
    );
    await expectLater(
      w.previewTimelineAt(Q.of(2)),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    await expectLater(
      w.exportVideo(File('${root.path}/must-not.mp4')),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    expect(File('${root.path}/must-not.mp4').existsSync(), false);
  });

  test('insert move leaves a source gap; uncovering ripple close refuses; SQL failure is a no-op', () async {
    attachLastVideoSourceCue(w);
    final lastVideo = moveVideos(w.current).last['id'] as String;
    final before = w.current;
    final beforeDur = Q.fromJson(
      w.current.toJson()['sequences'][0]['duration'],
    );
    w.edit(
      MoveClips([lastVideo], Q.of(3, 2), mode: 'insert', includeLinks: false),
      expectedRevision: w.current.revision,
    );
    expect(startOf(moveVideos(w.current).last), Q.of(3));
    expect(cueStart(w.current), Q.of(3));
    expect(cue(w.current)['anchor']['kind'], 'source');
    expect(
      Q.fromJson(w.current.toJson()['sequences'][0]['duration']),
      greaterThan(beforeDur),
    );
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(before));
    expect(
      () => w.edit(
        RippleDeleteClips(
          const [],
          range: TimeRange(cueStart(w.current), Q.of(1, 30)),
        ),
        expectedRevision: w.current.revision,
      ),
      code('ANCHOR_OUT_OF_RANGE'),
    );
    expect(contents(w.current), contents(before));
    final frozen = w.current.hash;
    final db = sqlite3.open('${root.path}/db');
    db.execute(
      "CREATE TRIGGER cap_source_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
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
      db.execute('DROP TRIGGER cap_source_fail');
      db.dispose();
    }
  });
}
