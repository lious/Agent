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
  test('persist path: invert split after moving an uninvolved remnant, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync('invert-split-sdk-');
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
    final splitId = lastCommand(w, 'splitClip');
    expect(moveVideos(w.current), hasLength(3));
    w.edit(MoveClips(['right'], Q.of(1)), expectedRevision: w.current.revision);
    expect(startOf(w.current, 'right'), Q.of(3));
    final beforeInvert = contents(w.current);
    w.invertCommand(splitId, expectedRevision: w.current.revision);

    expect(moveVideos(w.current), hasLength(2));
    expect(startOf(w.current, a), Q.of(0));
    expect(durationOf(w.current, a), Q.of(2));
    expect(startOf(w.current, 'right'), Q.of(3));
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(7, 2),
    );
    expect(cue(w.current, 'hello')['text'], 'hello');
    final inverted = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), beforeInvert);
    expect(moveVideos(w.current), hasLength(3));
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expect(moveVideos(w.current), hasLength(2));

    final archive = File('${root.path}/invert-split.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(moveVideos(w.current), hasLength(2));
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'stay'},
    );
    expect(
      moveVideos(w.current).map((c) => Q.fromJson(c['timelineRange']['start'])),
      containsAll([Q.of(0), Q.of(3)]),
    );

    final sidecar = File('${root.path}/invert-split.vtt');
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

  test('invert of the tip split or of split after a later remnant move is UNDO_CONFLICT', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-split-conflict-sdk-',
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
    w.edit(SplitClip(a, Q.of(1), 'mid'), expectedRevision: w.current.revision);
    final splitId = lastCommand(w, 'splitClip');
    expect(
      () => w.invertCommand(splitId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(moveVideos(w.current), hasLength(3));
    w.edit(MoveClips(['mid'], Q.of(2)), expectedRevision: w.current.revision);
    expect(startOf(w.current, 'mid'), Q.of(3));
    expect(
      () => w.invertCommand(splitId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(moveVideos(w.current), hasLength(3));
    expect(startOf(w.current, 'mid'), Q.of(3));
    expect((w.current.toJson()['captions'] as List).single['text'], 'hello');
  });
}
