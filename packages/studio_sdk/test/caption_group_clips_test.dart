import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Map cue(ProjectDocument p, String id) => (p.toJson()['captions'] as List)
    .cast<Map>()
    .singleWhere((c) => c['id'] == id);

Q startOf(ProjectDocument p, String id) => Q.fromJson(
  moveVideos(p).singleWhere((c) => c['id'] == id)['timelineRange']['start'],
);

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

void main() {
  test('persist path: group two captioned remnants, move the group, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync('caption-group-sdk-');
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    final stream =
        (w.current.toJson()['assets'][0]['streams'] as List).singleWhere(
              (s) => s['type'] == 'audio',
            )['id']
            as String;
    w.edit(ExtractAudioClip(a, stream), expectedRevision: w.current.revision);
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
    expect(
      () => w.edit(
        MoveClips([a], Q.of(1, 2)),
        expectedRevision: w.current.revision,
      ),
      code('COLLISION'),
    );
    w.groupSelection([a, 'right'], expectedRevision: w.current.revision);
    expect(w.current.toJson()['selectionGroups'], hasLength(1));
    expect(
      Q.fromJson(cue(w.current, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    w.edit(MoveClips([a], Q.of(1)), expectedRevision: w.current.revision);
    expect(startOf(w.current, a), Q.of(1));
    expect(startOf(w.current, 'right'), Q.of(2));
    expect(cue(w.current, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cue(w.current, 'cue-left')['timelineRange']['start']),
      Q.of(1),
    );
    expect(
      Q.fromJson(cue(w.current, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
    final moved = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(startOf(w.current, a), Q.of(0));
    expect(
      Q.fromJson(cue(w.current, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), moved);

    final archive = File('${root.path}/caption-group.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'stay'},
    );
    expect(
      moveVideos(w.current).map((c) => Q.fromJson(c['timelineRange']['start'])),
      containsAll([Q.of(1), Q.of(2)]),
    );
    expect(w.current.toJson()['selectionGroups'], hasLength(1));

    final sidecar = File('${root.path}/group.vtt');
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

  test('persist path: ungroup then move one member, leaving the other cue in place', () async {
    final root = Directory.systemTemp.createTempSync(
      'caption-group-ungroup-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
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
    w.groupSelection([a, 'right'], expectedRevision: w.current.revision);
    w.edit(MoveClips([a], Q.of(1)), expectedRevision: w.current.revision);
    final gid =
        (w.current.toJson()['selectionGroups'] as List).single['id'] as String;
    w.ungroupSelection([gid], expectedRevision: w.current.revision);
    expect(w.current.toJson()['selectionGroups'], isEmpty);
    w.edit(MoveClips(['right'], Q.of(1)), expectedRevision: w.current.revision);
    expect(startOf(w.current, a), Q.of(1));
    expect(startOf(w.current, 'right'), Q.of(3));
    expect(
      Q.fromJson(cue(w.current, 'cue-left')['timelineRange']['start']),
      Q.of(1),
    );
    expect(
      Q.fromJson(cue(w.current, 'cue-right')['timelineRange']['start']),
      Q.of(7, 2),
    );
  });
}
