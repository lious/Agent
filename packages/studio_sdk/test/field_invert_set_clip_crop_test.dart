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

Map? cropOf(ProjectDocument p, String clipId) {
  final ids = List<String>.from(clipOf(p, clipId)['effectIds'] as List);
  final found = [
    for (final e in p.toJson()['effects'] as List)
      if (ids.contains(e['id']) && e['type'] == 'crop') e as Map,
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


Map<String, double> cropLeft(double left) => {
  ...identityCrop,
  'left': left,
};

void expectCropLeft(ProjectDocument p, String a, double left) {
  final effect = cropOf(p, a)!;
  expect(effect['type'], 'crop');
  expect(effect['keyframes'], isEmpty);
  expect(effect['enabled'], true);
  expect(effect['parameters']['left'], left);
  expect(effect['parameters']['top'], 0);
  expect(effect['parameters']['right'], 1);
  expect(effect['parameters']['bottom'], 1);
}

void main() {
  test('persist path: invert SetClipCrop after a later marker edit, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-set-clip-crop-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    w.setClipCrop(
      a,
      cropLeft(0.25),
      expectedRevision: w.current.revision,
    );
    final keyId = lastCommand(w, 'setClipCrop');
    expect(moveVideos(w.current), hasLength(2));
    expect(startOf(w.current, a), Q.of(0));
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(durationOf(w.current, 'right'), Q.of(2));
    expect(seqDur(w.current), Q.of(3));
    expectCropLeft(w.current, a, 0.25);
    expect(cropOf(w.current, 'right'), isNull);
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

    expect(cropOf(w.current, a), isNull);
    expect(cropOf(w.current, 'right'), isNull);
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
    expectCropLeft(w.current, a, 0.25);
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(seqDur(w.current), Q.of(3));
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expect(cropOf(w.current, a), isNull);
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(durationOf(w.current, 'right'), Q.of(2));

    final archive = File('${root.path}/invert-set-clip-crop.studio-project');
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
    expect(cropOf(w.current, leftId), isNull);
    expect(cropOf(w.current, rightId), isNull);
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

    final sidecar = File('${root.path}/invert-set-clip-crop.vtt');
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

  test('invert of the tip SetClipCrop or of SetClipCrop after a later rewrite is UNDO_CONFLICT', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-set-clip-crop-conflict-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    w.setClipCrop(
      a,
      cropLeft(0.25),
      expectedRevision: w.current.revision,
    );
    final keyId = lastCommand(w, 'setClipCrop');
    expectCropLeft(w.current, a, 0.25);
    expect(
      () => w.invertCommand(keyId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expectCropLeft(w.current, a, 0.25);
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(seqDur(w.current), Q.of(3));
    w.setClipCrop(
      a,
      cropLeft(0.5),
      expectedRevision: w.current.revision,
    );
    expectCropLeft(w.current, a, 0.5);
    expect(
      () => w.invertCommand(keyId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(startOf(w.current, a), Q.of(0));
    expect(startOf(w.current, 'right'), Q.of(1));
    expectCropLeft(w.current, a, 0.5);
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });
}
