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
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

Q startOf(ProjectDocument p, String id) => Q.fromJson(
  media(p).singleWhere((c) => c['id'] == id)['timelineRange']['start'],
);

int groupCount(ProjectDocument p) => (p.toJson()['linkGroups'] as List).length;

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
  test('persist path: invert unlink after an aligned leave-gap move, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync('invert-unlink-sdk-');
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
    expect(groupCount(w.current), 2);
    final gid =
        media(w.current).singleWhere((c) => c['id'] == 'right')['linkGroupId']
            as String;
    final audioId =
        media(w.current).singleWhere(
              (c) => c['id'] != 'right' && c['linkGroupId'] == gid,
            )['id']
            as String;
    w.edit(UnlinkAudioVideo(gid), expectedRevision: w.current.revision);
    final unlinkId = lastCommand(w, 'unlinkAudioVideo');
    w.edit(
      MoveClips(['right', audioId], Q.of(1)),
      expectedRevision: w.current.revision,
    );
    expect(startOf(w.current, 'right'), Q.of(2));
    expect(startOf(w.current, audioId), Q.of(2));
    expect(groupCount(w.current), 1);
    final beforeInvert = contents(w.current);
    w.invertCommand(unlinkId, expectedRevision: w.current.revision);
    expect(groupCount(w.current), 2);
    expect(
      media(w.current).singleWhere((c) => c['id'] == 'right')['linkGroupId'],
      isNotNull,
    );
    expect(startOf(w.current, a), Q.of(0));
    expect(startOf(w.current, 'right'), Q.of(2));
    expect(startOf(w.current, audioId), Q.of(2));
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(5, 2),
    );
    final inverted = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), beforeInvert);
    expect(groupCount(w.current), 1);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expect(groupCount(w.current), 2);

    final archive = File('${root.path}/invert-unlink.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(groupCount(w.current), 2);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'stay'},
    );
    expect(
      moveVideos(w.current).map((c) => Q.fromJson(c['timelineRange']['start'])),
      containsAll([Q.of(0), Q.of(2)]),
    );

    final sidecar = File('${root.path}/invert-unlink.vtt');
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

  test('invert of the tip unlink, a later relink, or a diverging move is refused atomically', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-unlink-conflict-sdk-',
    );
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
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final gid =
        media(w.current).singleWhere((c) => c['id'] == 'right')['linkGroupId']
            as String;
    final audioId =
        media(w.current).singleWhere(
              (c) => c['id'] != 'right' && c['linkGroupId'] == gid,
            )['id']
            as String;
    w.edit(UnlinkAudioVideo(gid), expectedRevision: w.current.revision);
    final unlinkId = lastCommand(w, 'unlinkAudioVideo');
    expect(
      () => w.invertCommand(unlinkId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(groupCount(w.current), 1);
    w.edit(
      LinkAudioVideo('right', audioId),
      expectedRevision: w.current.revision,
    );
    expect(
      () => w.invertCommand(unlinkId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(groupCount(w.current), 2);
    expect((w.current.toJson()['captions'] as List).single['text'], 'hello');

    final relinkGid =
        media(w.current).singleWhere((c) => c['id'] == 'right')['linkGroupId']
            as String;
    w.edit(UnlinkAudioVideo(relinkGid), expectedRevision: w.current.revision);
    final laterUnlinkId = lastCommand(w, 'unlinkAudioVideo');
    w.edit(MoveClips(['right'], Q.of(1)), expectedRevision: w.current.revision);
    expect(startOf(w.current, 'right'), Q.of(2));
    // A later command must sit on the tip so invert of laterUnlink is legal.
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
    final beforeDiverged = contents(w.current);
    expect(
      () =>
          w.invertCommand(laterUnlinkId, expectedRevision: w.current.revision),
      code('LINK_OFFSET_MISMATCH'),
    );
    expect(contents(w.current), beforeDiverged);
    expect(groupCount(w.current), 1);
    expect(startOf(w.current, 'right'), Q.of(2));
    expect((w.current.toJson()['captions'] as List).single['text'], 'hello');
  });
}
