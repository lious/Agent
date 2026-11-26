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

Map? transformOf(ProjectDocument p, String clipId) {
  final ids = List<String>.from(clipOf(p, clipId)['effectIds'] as List);
  final found = [
    for (final e in p.toJson()['effects'] as List)
      if (ids.contains(e['id']) && e['type'] == 'transform2d') e as Map,
  ];
  return found.isEmpty ? null : found.single;
}


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


Map<String, double> translateX(double x) => {
  ...identityTransform2d,
  'translateX': x,
};

void expectTranslateX(ProjectDocument p, String a, double x) {
  final effect = transformOf(p, a)!;
  expect(effect['type'], 'transform2d');
  expect(effect['keyframes'], isEmpty);
  expect(effect['enabled'], true);
  expect(effect['parameters']['translateX'], x);
  expect(effect['parameters']['translateY'], 0);
  expect(effect['parameters']['scaleX'], 1);
  expect(effect['parameters']['scaleY'], 1);
  expect(effect['parameters']['rotationDeg'], 0);
}

void main() {
  test('persist path: invert SetClipTransform after a later marker edit, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-set-clip-transform-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    w.setClipTransform(
      a,
      translateX(16),
      expectedRevision: w.current.revision,
    );
    final keyId = lastCommand(w, 'setClipTransform');
    expect(moveVideos(w.current), hasLength(2));
    expect(startOf(w.current, a), Q.of(0));
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(durationOf(w.current, 'right'), Q.of(2));
    expect(seqDur(w.current), Q.of(3));
    expectTranslateX(w.current, a, 16);
    expect(transformOf(w.current, 'right'), isNull);
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(0),
    );
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

    expect(transformOf(w.current, a), isNull);
    expect(transformOf(w.current, 'right'), isNull);
    expect(moveVideos(w.current), hasLength(2));
    expect(startOf(w.current, a), Q.of(0));
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(durationOf(w.current, 'right'), Q.of(2));
    expect(seqDur(w.current), Q.of(3));
    expect(cue(w.current, 'hello')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cue(w.current, 'stay')['anchor']['kind'], 'clipLocal');
    expect(cue(w.current, 'stay')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    final inverted = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), beforeInvert);
    expectTranslateX(w.current, a, 16);
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(seqDur(w.current), Q.of(3));
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expect(transformOf(w.current, a), isNull);
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(durationOf(w.current, 'right'), Q.of(2));

    final archive = File('${root.path}/invert-set-clip-transform.studio-project');
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
          (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(1),
        )['timelineRange']['duration'],
      ),
      Q.of(2),
    );
    final leftId = videos
        .singleWhere((c) => Q.fromJson(c['timelineRange']['start']) == Q.of(0))['id']
        as String;
    final rightId = videos
        .singleWhere((c) => Q.fromJson(c['timelineRange']['start']) == Q.of(1))['id']
        as String;
    expect(transformOf(w.current, leftId), isNull);
    expect(transformOf(w.current, rightId), isNull);
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

    final sidecar = File('${root.path}/invert-set-clip-transform.vtt');
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

  test('invert of the tip SetClipTransform or of SetClipTransform after a later rewrite is UNDO_CONFLICT', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-set-clip-transform-conflict-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    w.setClipTransform(
      a,
      translateX(16),
      expectedRevision: w.current.revision,
    );
    final keyId = lastCommand(w, 'setClipTransform');
    expectTranslateX(w.current, a, 16);
    expect(
      () => w.invertCommand(keyId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expectTranslateX(w.current, a, 16);
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(seqDur(w.current), Q.of(3));
    w.setClipTransform(
      a,
      translateX(32),
      expectedRevision: w.current.revision,
    );
    expectTranslateX(w.current, a, 32);
    expect(
      () => w.invertCommand(keyId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(startOf(w.current, a), Q.of(0));
    expect(startOf(w.current, 'right'), Q.of(1));
    expectTranslateX(w.current, a, 32);
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });
}
