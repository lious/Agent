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

String lastCommand(StudioWorkspace w, String kind) =>
    w.commandLog.where((c) => c['kind'] == kind).last['id']!;

void prepareSplitAndCaptions(StudioWorkspace w) {
  final a = videoId(w.current);
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
      ]),
    ),
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
          'cue-keep-out',
          TimeRange(Q.of(3, 5), Q.of(1, 5)),
          'later-on-left',
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
    root = Directory.systemTemp.createTempSync('field-invert-');
    w = openMoveWorkspace(root);
    await installSingleClip(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('inverts a prior SetCaptions after an unrelated move; tip invert and followed host conflict', () {
    final a = videoId(w.current);
    prepareSplitAndCaptions(w);
    final setCaptionsId = lastCommand(w, 'setCaptions');
    w.edit(MoveClip('right', Q.of(1, 2)), expectedRevision: w.current.revision);
    expect(
      Q.fromJson(
        moveVideos(w.current)
            .singleWhere((c) => c['id'] == 'right')['timelineRange']['start'],
      ),
      Q.of(3, 2),
    );
    expect(w.current.toJson()['captions'], hasLength(2));

    expect(
      () => w.invertCommand(
        lastCommand(w, 'moveClip'),
        expectedRevision: w.current.revision,
      ),
      code('UNDO_CONFLICT'),
    );
    expect(w.current.toJson()['captions'], hasLength(2));

    final beforeInvert = contents(w.current);
    w.invertCommand(setCaptionsId, expectedRevision: w.current.revision);
    expect(w.current.toJson()['captions'], hasLength(1));
    expect(cue(w.current)['text'], 'hello');
    expect(
      Q.fromJson(
        moveVideos(w.current)
            .singleWhere((c) => c['id'] == 'right')['timelineRange']['start'],
      ),
      Q.of(3, 2),
    );
    final inverted = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), beforeInvert);
    expect(w.current.toJson()['captions'], hasLength(2));
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);

    expect(
      () => w.invertCommand(
        lastCommand(w, 'invertCommand'),
        expectedRevision: w.current.revision,
      ),
      code('UNDO_CONFLICT'),
    );
    expect(contents(w.current), inverted);

    final firstSet = w.commandLog
        .where((c) => c['kind'] == 'setCaptions')
        .first['id']!;
    w.edit(MoveClip(a, Q.of(1, 2)), expectedRevision: w.current.revision);
    final afterFollow = contents(w.current);
    expect(
      () => w.invertCommand(firstSet, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(contents(w.current), afterFollow);
  });

  test('short path: invert SetCaptions, undo/redo, archive fork, sidecar, no MP4 burn-in', () async {
    prepareSplitAndCaptions(w);
    final setCaptionsId = lastCommand(w, 'setCaptions');
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
    w.edit(MoveClip('right', Q.of(1, 2)), expectedRevision: w.current.revision);
    final start = contents(w.current);
    w.invertCommand(setCaptionsId, expectedRevision: w.current.revision);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello'},
    );
    expect(
      Q.fromJson(
        moveVideos(w.current)
            .singleWhere((c) => c['id'] == 'right')['timelineRange']['start'],
      ),
      Q.of(3, 2),
    );
    final inverted = w.current;
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(inverted));
    final archive = File('${root.path}/field-invert.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello'},
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'stay');
    expect(
      moveVideos(w.current).map((c) => Q.fromJson(c['timelineRange']['start'])),
      contains(Q.of(3, 2)),
    );
    final sidecar = File('${root.path}/field-invert.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    expect(sidecar.existsSync(), isTrue);
    expect(sidecar.readAsStringSync(), contains('hello'));
    expect(sidecar.readAsStringSync(), isNot(contains('later-on-left')));
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
