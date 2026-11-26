import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Map cue(ProjectDocument p, String text) => (p.toJson()['captions'] as List)
    .cast<Map>()
    .singleWhere((c) => c['text'] == text);

List<Map> media(ProjectDocument p) => [
  ...moveVideos(p),
];

Map clipOf(ProjectDocument p, String id) =>
    media(p).singleWhere((c) => c['id'] == id);

Q startOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['start']);

Q durationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

Future<void> installSingleClip(StudioWorkspace w, Directory root) async {
  w.openDemo();
  final av = File('${root.path}/av.mp4');
  final made = await Process.run('ffmpeg', [
    '-v',
    'error',
    '-i',
    Platform.environment['STUDIO_TEST_VIDEO']!,
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=997:sample_rate=44100:duration=3',
    '-map',
    '0:v:0',
    '-map',
    '1:a:0',
    '-c:v',
    'copy',
    '-c:a',
    'aac',
    av.path,
  ]);
  if (made.exitCode != 0) throw StateError('${made.stderr}');
  await w.importVideo(
    LocalFileGrant.fromUserSelection(av),
    expectedRevision: w.current.revision,
    acknowledgeVideoOnly: true,
  );
}

String videoId(ProjectDocument p) => moveVideos(p).first['id'] as String;

String lastCommand(StudioWorkspace w, String kind) =>
    w.commandLog.where((c) => c['kind'] == kind).last['id']!;

void addSplitCues(StudioWorkspace w, String a) {
  w.edit(
    SplitClip(a, Q.of(1), 'right'),
    expectedRevision: w.current.revision,
  );
  w.edit(
    SetCaptions(
      CaptionStore([
        CaptionCue(
          'cue-left',
          TimeRange(Q.of(0), Q.of(1, 2)),
          'hello',
          manualFields: {'text', 'timing'},
        ),
        CaptionCue(
          'cue-right',
          TimeRange(Q.of(3, 2), Q.of(1, 2)),
          'stay',
          manualFields: {'text', 'timing'},
        ),
      ]),
    ),
    expectedRevision: w.current.revision,
  );
}

void lengthenLeft(StudioWorkspace w, String a) {
  w.edit(
    RippleTrimClip(a, 'out', Q.of(1)),
    expectedRevision: w.current.revision,
  );
}

void expectSplit(ProjectDocument p, String a) {
  expect(moveVideos(p), hasLength(2));
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(1));
  expect(startOf(p, 'right'), Q.of(1));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(seqDur(p), Q.of(3));
  expect(Q.fromJson(cue(p, 'hello')['timelineRange']['start']), Q.of(0));
  expect(cue(p, 'hello')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cue(p, 'stay')['timelineRange']['start']), Q.of(3, 2));
  expect(cue(p, 'stay')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'stay')['anchor']['clipId'], 'right');
}

void expectLengthened(ProjectDocument p, String a) {
  expect(moveVideos(p), hasLength(2));
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(2));
  expect(startOf(p, 'right'), Q.of(2));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(seqDur(p), Q.of(4));
  expect(Q.fromJson(cue(p, 'hello')['timelineRange']['start']), Q.of(0));
  expect(cue(p, 'hello')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cue(p, 'stay')['timelineRange']['start']), Q.of(5, 2));
  expect(cue(p, 'stay')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'stay')['anchor']['clipId'], 'right');
}

void main() {
  test('persist path: invert ripple-trim-lengthen after a later marker edit, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-ripple-trim-lengthen-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    expectSplit(w.current, a);
    lengthenLeft(w, a);
    final keyId = lastCommand(w, 'rippleTrimClip');
    expectLengthened(w.current, a);
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-1',
            sequenceId: w.current.toJson()['rootSequenceId'] as String,
            label: 'later',
            time: Q.of(2),
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final beforeInvert = contents(w.current);
    w.invertCommand(keyId, expectedRevision: w.current.revision);

    expectSplit(w.current, a);
    expect(cue(w.current, 'hello')['text'], 'hello');
    expect(cue(w.current, 'stay')['text'], 'stay');
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    final inverted = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), beforeInvert);
    expectLengthened(w.current, a);
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expectSplit(w.current, a);

    final archive = File('${root.path}/invert-ripple-trim-lengthen.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.current.toJson()['transitions'], isEmpty);
    final videos = moveVideos(w.current);
    expect(videos, hasLength(2));
    expect(
      videos.map((c) => Q.fromJson(c['timelineRange']['start'])),
      containsAll([Q.of(0), Q.of(1)]),
    );
    expect(
      Q.fromJson(
        videos.singleWhere(
          (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(0),
        )['timelineRange']['duration'],
      ),
      Q.of(1),
    );
    expect(
      Q.fromJson(
        videos.singleWhere(
          (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(1),
        )['timelineRange']['duration'],
      ),
      Q.of(2),
    );
    expect(seqDur(w.current), Q.of(3));
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'stay'},
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    expect(
      (w.current.toJson()['captions'] as List)
          .cast<Map>()
          .singleWhere((c) => c['text'] == 'stay')['anchor']['kind'],
      'clipLocal',
    );
    expect(
      Q.fromJson(
        (w.current.toJson()['captions'] as List)
            .cast<Map>()
            .singleWhere((c) => c['text'] == 'stay')['timelineRange']['start'],
      ),
      Q.of(3, 2),
    );
    expect(
      Q.fromJson(
        (w.current.toJson()['captions'] as List)
            .cast<Map>()
            .singleWhere((c) => c['text'] == 'hello')['timelineRange']['start'],
      ),
      Q.of(0),
    );

    final sidecar = File('${root.path}/invert-ripple-trim-lengthen.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    expect(sidecar.readAsStringSync(), contains('hello'));
    expect(sidecar.readAsStringSync(), contains('stay'));
    await expectLater(
      w.previewTimelineAt(Q.of(0)),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    await expectLater(
      w.exportVideo(File('${root.path}/must-not.mp4')),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    expect(File('${root.path}/must-not.mp4').existsSync(), isFalse);
  });

  test('invert of the tip ripple-trim-lengthen or of ripple-trim-lengthen after a later rewrite is UNDO_CONFLICT', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-ripple-trim-lengthen-conflict-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    lengthenLeft(w, a);
    final keyId = lastCommand(w, 'rippleTrimClip');
    expectLengthened(w.current, a);
    expect(
      () => w.invertCommand(keyId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expectLengthened(w.current, a);
    lengthenLeft(w, a);
    expect(durationOf(w.current, a), Q.of(3));
    expect(startOf(w.current, 'right'), Q.of(3));
    expect(seqDur(w.current), Q.of(5));
    expect(
      () => w.invertCommand(keyId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(startOf(w.current, a), Q.of(0));
    expect(durationOf(w.current, a), Q.of(3));
    expect(startOf(w.current, 'right'), Q.of(3));
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(7, 2),
    );
  });
}
