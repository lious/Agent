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

String lastCommand(StudioWorkspace w, String kind) =>
    w.commandLog.where((c) => c['kind'] == kind).last['id']!;

void main() {
  test('persist path: invert SetMarkers after an unrelated move, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync('invert-markers-sdk-');
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
            'cue-1',
            TimeRange(Q.of(0), Q.of(1, 2)),
            'hello',
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
            'mark-1',
            sequenceId: w.current.toJson()['sequences'][0]['id'] as String,
            label: 'later',
            time: Q.of(2),
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final setMarkersId = lastCommand(w, 'setMarkers');
    w.edit(MoveClip('right', Q.of(1, 2)), expectedRevision: w.current.revision);
    expect(
      Q.fromJson(
        moveVideos(w.current)
            .singleWhere((c) => c['id'] == 'right')['timelineRange']['start'],
      ),
      Q.of(3, 2),
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    final beforeInvert = contents(w.current);
    w.invertCommand(setMarkersId, expectedRevision: w.current.revision);
    expect(w.current.toJson()['markers'], isEmpty);
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
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expect(w.current.toJson()['markers'], isEmpty);

    final archive = File('${root.path}/invert-markers.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.current.toJson()['markers'], isEmpty);
    expect(
      (w.current.toJson()['captions'] as List).cast<Map>().single['text'],
      'hello',
    );
    expect(
      moveVideos(w.current).map((c) => Q.fromJson(c['timelineRange']['start'])),
      contains(Q.of(3, 2)),
    );

    final sidecar = File('${root.path}/invert-markers.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    expect(sidecar.readAsStringSync(), contains('hello'));
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

  test(
    'invert of the tip or of a later-edited SetMarkers is UNDO_CONFLICT',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'invert-markers-conflict-sdk-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      final w = openMoveWorkspace(root);
      addTearDown(w.close);
      await installSingleClip(w, root);
      final seq = w.current.toJson()['sequences'][0]['id'] as String;
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
      w.edit(
        SetMarkers(
          MarkerStore([
            TimelineMarker(
              'mark-1',
              sequenceId: seq,
              label: 'later',
              time: Q.of(2),
            ),
          ]),
        ),
        expectedRevision: w.current.revision,
      );
      final firstMarkers = lastCommand(w, 'setMarkers');
      expect(
        () =>
            w.invertCommand(firstMarkers, expectedRevision: w.current.revision),
        code('UNDO_CONFLICT'),
      );
      expect((w.current.toJson()['markers'] as List).single['label'], 'later');
      w.edit(
        SetMarkers(
          MarkerStore([
            TimelineMarker(
              'mark-1',
              sequenceId: seq,
              label: 'changed',
              time: Q.of(2),
            ),
          ]),
        ),
        expectedRevision: w.current.revision,
      );
      expect(
        () =>
            w.invertCommand(firstMarkers, expectedRevision: w.current.revision),
        code('UNDO_CONFLICT'),
      );
      expect(
        (w.current.toJson()['markers'] as List).single['label'],
        'changed',
      );
      expect(cue(w.current)['text'], 'hello');
    },
  );
}
