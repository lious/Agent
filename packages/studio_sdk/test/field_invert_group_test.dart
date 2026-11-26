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

String lastCommand(StudioWorkspace w, String kind) =>
    w.commandLog.where((c) => c['kind'] == kind).last['id']!;

void main() {
  test('persist path: invert GroupClips after a group move, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync('invert-group-sdk-');
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
    w.groupSelection([a, 'right'], expectedRevision: w.current.revision);
    final groupId = lastCommand(w, 'groupClips');
    w.edit(MoveClips([a], Q.of(1)), expectedRevision: w.current.revision);
    expect(startOf(w.current, a), Q.of(1));
    expect(w.current.toJson()['selectionGroups'], hasLength(1));
    final beforeInvert = contents(w.current);
    w.invertCommand(groupId, expectedRevision: w.current.revision);
    expect(w.current.toJson()['selectionGroups'], isEmpty);
    expect(startOf(w.current, a), Q.of(1));
    expect(startOf(w.current, 'right'), Q.of(2));
    expect(
      Q.fromJson(cue(w.current, 'cue-left')['timelineRange']['start']),
      Q.of(1),
    );
    expect(
      Q.fromJson(cue(w.current, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
    expect(cue(w.current, 'cue-left')['text'], 'hello');
    final inverted = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), beforeInvert);
    expect(w.current.toJson()['selectionGroups'], hasLength(1));
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expect(w.current.toJson()['selectionGroups'], isEmpty);

    final archive = File('${root.path}/invert-group.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.current.toJson()['selectionGroups'], isEmpty);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'stay'},
    );
    expect(
      moveVideos(w.current).map((c) => Q.fromJson(c['timelineRange']['start'])),
      containsAll([Q.of(1), Q.of(2)]),
    );

    final sidecar = File('${root.path}/invert-group.vtt');
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

  test('invert of the tip GroupClips or of a later-ungrouped GroupClips is UNDO_CONFLICT', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-group-conflict-sdk-',
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
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    w.groupSelection([a, 'right'], expectedRevision: w.current.revision);
    final groupId = lastCommand(w, 'groupClips');
    expect(
      () => w.invertCommand(groupId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(w.current.toJson()['selectionGroups'], hasLength(1));
    final gid =
        (w.current.toJson()['selectionGroups'] as List).single['id'] as String;
    w.ungroupSelection([gid], expectedRevision: w.current.revision);
    expect(
      () => w.invertCommand(groupId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(w.current.toJson()['selectionGroups'], isEmpty);
    expect((w.current.toJson()['captions'] as List).single['text'], 'hello');
  });
}
