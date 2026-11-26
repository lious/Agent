import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Map cue(ProjectDocument p, [String id = 'cue-left']) =>
    (p.toJson()['captions'] as List).cast<Map>().singleWhere(
      (c) => c['id'] == id,
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

List<Map> audioMedia(ProjectDocument p) => [
  for (final c in (p.toJson()['sequences'][0]['tracks'] as List).singleWhere(
    (t) => t['kind'] == 'audio',
  )['items'])
    if (c['source'] != null) c as Map,
];

String prepareLinkedSplit(StudioWorkspace w) {
  final a = videoId(w.current);
  final stream =
      (w.current.toJson()['assets'][0]['streams'] as List).singleWhere(
            (s) => s['type'] == 'audio',
          )['id']
          as String;
  w.edit(ExtractAudioClip(a, stream), expectedRevision: w.current.revision);
  w.edit(SplitClip(a, Q.of(1), 'right'), expectedRevision: w.current.revision);
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
          'cue-later',
          TimeRange(Q.of(3, 2), Q.of(1, 5)),
          'stay',
          manualFields: {'text', 'timing'},
        ),
      ]),
    ),
    expectedRevision: w.current.revision,
  );
  return a;
}

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('caption-leave-gap-delete-');
    w = openMoveWorkspace(root);
    await installSingleClip(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('linked leave-gap DeleteClip leaves an absolute remnant and does not shift later content; undo restores', () {
    final a = prepareLinkedSplit(w);
    final before = contents(w.current);
    w.edit(DeleteClip(a), expectedRevision: w.current.revision);
    expect(moveVideos(w.current).map((c) => c['id']), isNot(contains(a)));
    expect(
      Q.fromJson(moveVideos(w.current).single['timelineRange']['start']),
      Q.of(1),
    );
    expect(
      Q.fromJson(audioMedia(w.current).single['timelineRange']['start']),
      Q.of(1),
    );
    final remnant = cue(w.current);
    expect(remnant['text'], 'hello');
    expect(remnant['anchor']['kind'], 'absolute');
    expect(Q.fromJson(remnant['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(remnant['timelineRange']['duration']), Q.of(1, 2));
    expect(
      Q.fromJson(cue(w.current, 'cue-later')['timelineRange']['start']),
      Q.of(3, 2),
    );
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), before);
  });

  test('short path: linked leave-gap DeleteClip, undo/redo, archive fork, sidecar, no MP4 burn-in', () async {
    final a = prepareLinkedSplit(w);
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-stay',
            sequenceId: w.current.toJson()['sequences'][0]['id'] as String,
            label: 'stay',
            time: Q.of(2),
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final start = contents(w.current);
    w.edit(DeleteClip(a), expectedRevision: w.current.revision);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'stay'},
    );
    final deleted = w.current;
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(deleted));
    final archive = File(
      '${root.path}/caption-leave-gap-delete.studio-project',
    );
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'stay'},
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'stay');
    expect(audioMedia(w.current), hasLength(1));
    expect(
      Q.fromJson(audioMedia(w.current).single['timelineRange']['start']),
      Q.of(1),
    );
    final sidecar = File('${root.path}/leave-gap-delete.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    expect(sidecar.existsSync(), isTrue);
    await expectLater(
      w.previewTimelineAt(Q.of(0)),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    await expectLater(
      w.exportVideo(File('${root.path}/must-not.mp4')),
      code('CAPTION_RENDER_POLICY_NOT_IMPLEMENTED'),
    );
    expect(File('${root.path}/must-not.mp4').existsSync(), false);
  });
}
