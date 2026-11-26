import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Map cue(ProjectDocument p, [String id = 'cue-1']) =>
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

String prepareLinkedCue(StudioWorkspace w) {
  final a = videoId(w.current);
  final stream =
      (w.current.toJson()['assets'][0]['streams'] as List).singleWhere(
            (s) => s['type'] == 'audio',
          )['id']
          as String;
  w.edit(ExtractAudioClip(a, stream), expectedRevision: w.current.revision);
  w.edit(
    SetCaptions(
      CaptionStore([
        CaptionCue(
          'cue-1',
          TimeRange(Q.of(0), Q.of(1, 2)),
          'hello',
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
    root = Directory.systemTemp.createTempSync('caption-move-clip-');
    w = openMoveWorkspace(root);
    await installSingleClip(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('linked MoveClip follows a clipLocal cue and leaves the source gap; undo restores', () {
    final a = prepareLinkedCue(w);
    final before = contents(w.current);
    w.edit(MoveClip(a, Q.of(1, 2)), expectedRevision: w.current.revision);
    expect(
      Q.fromJson(moveVideos(w.current).single['timelineRange']['start']),
      Q.of(1, 2),
    );
    expect(
      Q.fromJson(audioMedia(w.current).single['timelineRange']['start']),
      Q.of(1, 2),
    );
    expect(cue(w.current)['text'], 'hello');
    expect(cue(w.current)['anchor']['kind'], 'clipLocal');
    expect(Q.fromJson(cue(w.current)['timelineRange']['start']), Q.of(1, 2));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), before);
  });

  test('short path: linked MoveClip, undo/redo, archive fork, sidecar, no MP4 burn-in', () async {
    final a = prepareLinkedCue(w);
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-follow',
            sequenceId: w.current.toJson()['sequences'][0]['id'] as String,
            label: 'pin',
            time: Q.of(1, 5),
            anchorKind: 'clipLocal',
            anchorClipId: a,
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final start = contents(w.current);
    w.edit(MoveClip(a, Q.of(1, 2)), expectedRevision: w.current.revision);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello'},
    );
    expect(
      Q.fromJson((w.current.toJson()['markers'] as List).single['time']),
      Q.of(7, 10),
    );
    final moved = w.current;
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(moved));
    final archive = File('${root.path}/caption-move-clip.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello'},
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'pin');
    expect(audioMedia(w.current), hasLength(1));
    expect(
      Q.fromJson(audioMedia(w.current).single['timelineRange']['start']),
      Q.of(1, 2),
    );
    final sidecar = File('${root.path}/move-clip.vtt');
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
