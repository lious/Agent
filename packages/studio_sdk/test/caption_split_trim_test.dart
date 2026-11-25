import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

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

void attachCoveredCue(
  StudioWorkspace w, {
  Q? start,
  Q? duration,
  String id = 'cue-1',
  String text = 'hello',
}) {
  w.edit(
    SetCaptions(
      CaptionStore([
        CaptionCue(
          id,
          TimeRange(start ?? Q.of(0), duration ?? Q.of(1, 2)),
          text,
          manualFields: {'text', 'timing'},
        ),
      ]),
    ),
    expectedRevision: w.current.revision,
  );
}

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('caption-split-trim-');
    w = openMoveWorkspace(root);
    await installSingleClip(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('split keeps a left clipLocal cue; a spanning cue becomes absolute; undo restores', () {
    final a = videoId(w.current);
    attachCoveredCue(w, start: Q.of(0), duration: Q.of(1, 2));
    w.edit(
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(cue(w.current))),
          CaptionCue(
            'cue-span',
            TimeRange(Q.of(1, 2), Q.of(1)),
            'spans',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final before = contents(w.current);
    final rev = w.current.revision;
    w.edit(SplitClip(a, Q.of(1), 'right'), expectedRevision: rev);
    expect(cue(w.current)['anchor']['kind'], 'clipLocal');
    expect(cue(w.current)['anchor']['clipId'], a);
    expect(cue(w.current, 'cue-span')['anchor']['kind'], 'absolute');
    expect(cue(w.current, 'cue-span')['text'], 'spans');
    expect(
      Q.fromJson(cue(w.current, 'cue-span')['timelineRange']['start']),
      Q.of(1, 2),
    );
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), before);
  });

  test('leave-gap out trim leaves an absolute remnant in the gap; later content unmoved', () {
    final a = videoId(w.current);
    attachCoveredCue(w, start: Q.of(2), duration: Q.of(1), text: 'cross');
    final before = contents(w.current);
    w.edit(
      TrimClip(a, 'out', Q.of(-1, 2)),
      expectedRevision: w.current.revision,
    );
    expect(
      Q.fromJson(moveVideos(w.current).first['timelineRange']['duration']),
      Q.of(5, 2),
    );
    expect(Q.fromJson(w.current.toJson()['sequences'][0]['duration']), Q.of(3));
    expect(cue(w.current, 'cue-1')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cue(w.current, 'cue-1')['timelineRange']['duration']),
      Q.of(1, 2),
    );
    final abs = (w.current.toJson()['captions'] as List)
        .cast<Map>()
        .singleWhere((c) => c['anchor']['kind'] == 'absolute');
    expect(abs['text'], 'cross');
    expect(Q.fromJson(abs['timelineRange']['start']), Q.of(5, 2));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), before);
  });

  test('short path: leave-gap trim, undo/redo, archive fork, sidecar, no MP4 burn-in', () async {
    final a = videoId(w.current);
    attachCoveredCue(w, start: Q.of(0), duration: Q.of(1), text: 'split-trim');
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
    w.edit(
      TrimClip(a, 'out', Q.of(-1, 2)),
      expectedRevision: w.current.revision,
    );
    expect(cue(w.current)['text'], 'split-trim');
    expect(cue(w.current)['anchor']['kind'], 'clipLocal');
    final trimmed = w.current;
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(trimmed));
    final archive = File('${root.path}/caption-split-trim.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'split-trim'},
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'stay');
    final sidecar = File('${root.path}/split-trim.vtt');
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
