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

void attachLastVideoCue(StudioWorkspace w) {
  final last = moveVideos(w.current).last;
  final id = last['id'] as String;
  final cs = startOf(last);
  final cd = Q.fromJson(last['timelineRange']['duration']);
  final anchored = CaptionCue(
    'follow-cue',
    TimeRange(cs, Q.of(1, 2)),
    'follows host',
    manualFields: {'text', 'timing'},
  ).anchoredToClip(id, cs, cd);
  w.edit(
    SetCaptions(CaptionStore([anchored])),
    expectedRevision: w.current.revision,
  );
}

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('caption-follow-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('clipLocal cue follows ignore-links move, one command, undo/reopen/fork/sidecar', () async {
    attachLastVideoCue(w);
    final lastVideo = moveVideos(w.current).last['id'] as String;
    final lastAudio = audios(w.current).last['id'] as String;
    expect(startOf(moveVideos(w.current).last), Q.of(3, 2));
    expect(cueStart(w.current), Q.of(3, 2));
    expect(cue(w.current)['anchor']['kind'], 'clipLocal');
    final before = w.current;
    w.edit(
      MoveClips([lastVideo], Q.of(1, 2), includeLinks: false),
      expectedRevision: w.current.revision,
    );
    expect(w.current.revision, before.revision + BigInt.one);
    expect(startOf(moveVideos(w.current).last), Q.of(2));
    expect(
      startOf(audios(w.current).singleWhere((c) => c['id'] == lastAudio)),
      Q.of(3, 2),
    );
    expect(cueStart(w.current), Q.of(2));
    expect(cue(w.current)['text'], 'follows host');
    expect(cue(w.current)['anchor']['clipId'], lastVideo);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(before));
    expect(cueStart(w.current), Q.of(3, 2));
    w.redo(expectedRevision: w.current.revision);
    final redone = w.current;
    w.openDemo();
    expect(contents(w.current), contents(redone));
    expect(cueStart(w.current), Q.of(2));
    final archive = File('${root.path}/caption-follow.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(cueStart(w.current), Q.of(2));
    expect(w.current.toJson()['captions'][0]['anchor']['kind'], 'clipLocal');
    final sidecar = File('${root.path}/follow.vtt');
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

  test('default closure, SQL and ripple still refuse wholly; absolute cue does not follow', () async {
    attachLastVideoCue(w);
    final lastVideo = moveVideos(w.current).last['id'] as String;
    final lastAudio = audios(w.current).last['id'] as String;
    final baseline = w.current;
    w.edit(
      MoveClips([lastVideo], Q.of(1, 2)),
      expectedRevision: w.current.revision,
    );
    expect(startOf(moveVideos(w.current).last), Q.of(2));
    expect(
      startOf(audios(w.current).singleWhere((c) => c['id'] == lastAudio)),
      Q.of(2),
    );
    expect(cueStart(w.current), Q.of(2));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(baseline));
    w.edit(
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cue(w.current)))
              .makeAbsolute(),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final frozenAbs = w.current;
    w.edit(
      MoveClips([lastVideo], Q.of(1, 2), includeLinks: false),
      expectedRevision: w.current.revision,
    );
    expect(startOf(moveVideos(w.current).last), Q.of(2));
    expect(cueStart(w.current), Q.of(3, 2));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(frozenAbs));
    final frozen = w.current.hash;
    final db = sqlite3.open('${root.path}/db');
    db.execute(
      "CREATE TRIGGER cf_fail BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture'); END",
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
      db.execute('DROP TRIGGER cf_fail');
      db.dispose();
    }
    expect(
      () => w.edit(
        RippleDeleteClips(const [], range: TimeRange(Q.of(0), Q.of(1, 2))),
        expectedRevision: w.current.revision,
      ),
      code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
    );
    expect(w.current.hash, frozen);
  });
}

List<Map> audios(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    if (t['kind'] == 'audio')
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
];
