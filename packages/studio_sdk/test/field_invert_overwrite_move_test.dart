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

Map clipOf(ProjectDocument p, String id) =>
    moveVideos(p).singleWhere((c) => c['id'] == id);

Q startOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['start']);

Q durationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

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
          'cue-hole',
          TimeRange(Q.of(3, 2), Q.of(1, 4)),
          'carved',
          manualFields: {'text', 'timing'},
        ),
        CaptionCue(
          'cue-later',
          TimeRange(Q.of(2), Q.of(1, 5)),
          'stay',
          manualFields: {'text', 'timing'},
        ),
      ]),
    ),
    expectedRevision: w.current.revision,
  );
}

void main() {
  test('persist path: invert overwrite MoveClips of the left remnant after a later marker edit, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-overwrite-move-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    w.edit(
      MoveClips([a], Q.of(1), mode: 'overwrite'),
      expectedRevision: w.current.revision,
    );
    final moveId = lastCommand(w, 'moveClips');
    expect(startOf(w.current, a), Q.of(1));
    expect(startOf(w.current, 'right'), Q.of(2));
    expect(durationOf(w.current, 'right'), Q.of(1));
    expect(cue(w.current, 'carved')['anchor']['kind'], 'absolute');
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(1),
    );
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-1',
            sequenceId: w.current.toJson()['rootSequenceId'] as String,
            label: 'later',
            time: Q.of(5, 2),
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final beforeInvert = contents(w.current);
    w.invertCommand(moveId, expectedRevision: w.current.revision);

    expect(moveVideos(w.current), hasLength(2));
    expect(startOf(w.current, a), Q.of(0));
    expect(startOf(w.current, 'right'), Q.of(1));
    expect(durationOf(w.current, 'right'), Q.of(2));
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cue(w.current, 'hello')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cue(w.current, 'carved')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(cue(w.current, 'carved')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(2),
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    final inverted = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), beforeInvert);
    expect(startOf(w.current, a), Q.of(1));
    expect(startOf(w.current, 'right'), Q.of(2));
    expect(durationOf(w.current, 'right'), Q.of(1));
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expect(startOf(w.current, a), Q.of(0));
    expect(durationOf(w.current, 'right'), Q.of(2));

    final archive = File('${root.path}/invert-overwrite-move.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'carved', 'stay'},
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
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
    expect(
      (w.current.toJson()['captions'] as List)
          .cast<Map>()
          .singleWhere((c) => c['text'] == 'carved')['anchor']['kind'],
      'clipLocal',
    );

    final sidecar = File('${root.path}/invert-overwrite-move.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    expect(sidecar.readAsStringSync(), contains('hello'));
    expect(sidecar.readAsStringSync(), contains('carved'));
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

  test('invert of the tip overwrite MoveClips or of overwrite MoveClips after a later out-trim of the carved dest is UNDO_CONFLICT', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-overwrite-move-conflict-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    w.edit(
      MoveClips([a], Q.of(1), mode: 'overwrite'),
      expectedRevision: w.current.revision,
    );
    final moveId = lastCommand(w, 'moveClips');
    expect(startOf(w.current, a), Q.of(1));
    expect(durationOf(w.current, 'right'), Q.of(1));
    expect(
      () => w.invertCommand(moveId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(startOf(w.current, a), Q.of(1));
    expect(durationOf(w.current, 'right'), Q.of(1));
    expect(cue(w.current, 'carved')['anchor']['kind'], 'absolute');
    w.edit(
      TrimClip('right', 'out', Q.of(-1, 2)),
      expectedRevision: w.current.revision,
    );
    expect(durationOf(w.current, 'right'), Q.of(1, 2));
    expect(
      () => w.invertCommand(moveId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(startOf(w.current, 'right'), Q.of(2));
    expect(durationOf(w.current, 'right'), Q.of(1, 2));
    expect(cue(w.current, 'carved')['text'], 'carved');
  });
}
