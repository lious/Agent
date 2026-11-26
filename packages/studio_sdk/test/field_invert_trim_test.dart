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

void main() {
  test('persist path: invert leave-gap out-trim after an unrelated marker edit, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync('invert-trim-sdk-');
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    w.edit(
      SplitClip(a, Q.of(2), 'right'),
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
            TimeRange(Q.of(5, 2), Q.of(1, 2)),
            'stay',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    w.edit(SplitClip(a, Q.of(1), 'mid'), expectedRevision: w.current.revision);
    w.edit(
      TrimClip(a, 'out', Q.of(-1, 2)),
      expectedRevision: w.current.revision,
    );
    final trimId = lastCommand(w, 'trimClip');
    expect(durationOf(w.current, a), Q.of(1, 2));
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
    w.invertCommand(trimId, expectedRevision: w.current.revision);

    expect(startOf(w.current, a), Q.of(0));
    expect(durationOf(w.current, a), Q.of(1));
    expect(startOf(w.current, 'mid'), Q.of(1));
    expect(startOf(w.current, 'right'), Q.of(2));
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(5, 2),
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    expect(cue(w.current, 'hello')['text'], 'hello');
    final inverted = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), beforeInvert);
    expect(durationOf(w.current, a), Q.of(1, 2));
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expect(durationOf(w.current, a), Q.of(1));

    final archive = File('${root.path}/invert-trim.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'stay'},
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    final videos = moveVideos(w.current);
    expect(videos, hasLength(3));
    expect(
      videos.map((c) => Q.fromJson(c['timelineRange']['start'])),
      containsAll([Q.of(0), Q.of(1), Q.of(2)]),
    );
    expect(
      Q.fromJson(
        videos.singleWhere(
          (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(0),
        )['timelineRange']['duration'],
      ),
      Q.of(1),
    );

    final sidecar = File('${root.path}/invert-trim.vtt');
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

  test('invert of the tip trim or of trim after a later numerator-changing trim is UNDO_CONFLICT', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-trim-conflict-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    w.edit(
      SplitClip(a, Q.of(2), 'right'),
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
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    w.edit(
      TrimClip(a, 'out', Q.of(-1, 2)),
      expectedRevision: w.current.revision,
    );
    final trimId = lastCommand(w, 'trimClip');
    expect(
      () => w.invertCommand(trimId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(durationOf(w.current, a), Q.of(3, 2));
    w.edit(
      TrimClip(a, 'out', Q.of(-1, 2)),
      expectedRevision: w.current.revision,
    );
    expect(durationOf(w.current, a), Q.of(1));
    expect(
      () => w.invertCommand(trimId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(durationOf(w.current, a), Q.of(1));
    expect((w.current.toJson()['captions'] as List).single['text'], 'hello');
  });
}
