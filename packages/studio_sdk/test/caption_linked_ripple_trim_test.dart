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

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('caption-linked-ripple-trim-');
    w = openMoveWorkspace(root);
    await installSingleClip(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('linked ripple TrimClip shortens both members and splits a spanning cue; undo restores', () {
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
            TimeRange(Q.of(0), Q.of(7, 2)),
            'hello',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final before = contents(w.current);
    w.edit(
      TrimClip(a, 'out', Q.of(-1, 2), ripple: true),
      expectedRevision: w.current.revision,
    );
    expect(
      Q.fromJson(moveVideos(w.current).first['timelineRange']['duration']),
      Q.of(5, 2),
    );
    expect(
      Q.fromJson(audioMedia(w.current).single['timelineRange']['duration']),
      Q.of(5, 2),
    );
    final left = cue(w.current);
    final right = (w.current.toJson()['captions'] as List)
        .cast<Map>()
        .singleWhere((c) => c['id'] != left['id']);
    expect(left['text'], 'hello');
    expect(Q.fromJson(left['timelineRange']['duration']), Q.of(5, 2));
    expect(right['text'], 'hello');
    expect(Q.fromJson(right['timelineRange']['start']), Q.of(5, 2));
    expect(Q.fromJson(right['timelineRange']['duration']), Q.of(1, 2));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), before);
  });

  test('short path: linked ripple TrimClip, undo/redo, archive fork, sidecar, no MP4 burn-in', () async {
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
            TimeRange(Q.of(0), Q.of(7, 2)),
            'linked-ripple',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-stay',
            sequenceId: w.current.toJson()['sequences'][0]['id'] as String,
            label: 'stay',
            time: Q.of(1),
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final start = contents(w.current);
    w.edit(
      TrimClip(a, 'out', Q.of(-1, 2), ripple: true),
      expectedRevision: w.current.revision,
    );
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'linked-ripple'},
    );
    final trimmed = w.current;
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(trimmed));
    final archive = File(
      '${root.path}/caption-linked-ripple-trim.studio-project',
    );
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'linked-ripple'},
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'stay');
    expect(audioMedia(w.current), hasLength(1));
    final sidecar = File('${root.path}/linked-ripple.vtt');
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
