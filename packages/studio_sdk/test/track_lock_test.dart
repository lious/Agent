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

Map trackOf(ProjectDocument p, String kind) =>
    (p.toJson()['sequences'][0]['tracks'] as List).cast<Map>().singleWhere(
      (t) => t['kind'] == kind,
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
  test('persist path: lock video, refuse move, unlock, follow cue, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync('track-lock-sdk-');
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
    final video = trackOf(w.current, 'video')['id'] as String;
    w.edit(
      SetTrackState(video, locked: true),
      expectedRevision: w.current.revision,
    );
    expect(trackOf(w.current, 'video')['locked'], isTrue);
    expect(
      () => w.edit(MoveClip(a, Q.of(1)), expectedRevision: w.current.revision),
      code('FIELD_LOCKED'),
    );
    expect(
      Q.fromJson(moveVideos(w.current).first['timelineRange']['start']),
      Q.of(0),
    );
    expect(cue(w.current)['text'], 'hello');
    w.edit(
      SetTrackState(video, locked: false),
      expectedRevision: w.current.revision,
    );
    w.edit(MoveClip(a, Q.of(1)), expectedRevision: w.current.revision);
    expect(
      Q.fromJson(moveVideos(w.current).first['timelineRange']['start']),
      Q.of(1),
    );
    expect(cue(w.current)['anchor']['kind'], 'clipLocal');
    expect(Q.fromJson(cue(w.current)['timelineRange']['start']), Q.of(1));
    final afterMove = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(
      Q.fromJson(moveVideos(w.current).first['timelineRange']['start']),
      Q.of(0),
    );
    expect(Q.fromJson(cue(w.current)['timelineRange']['start']), Q.of(0));
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), afterMove);
    expect(Q.fromJson(cue(w.current)['timelineRange']['start']), Q.of(1));

    final archive = File('${root.path}/track-lock.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(
      Q.fromJson(moveVideos(w.current).first['timelineRange']['start']),
      Q.of(1),
    );
    final restored = (w.current.toJson()['captions'] as List)
        .cast<Map>()
        .single;
    expect(restored['text'], 'hello');
    expect(Q.fromJson(restored['timelineRange']['start']), Q.of(1));
    expect(trackOf(w.current, 'video')['locked'], isFalse);

    final sidecar = File('${root.path}/lock.vtt');
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

  test('persist path: locked caption track refuses SetCaptions; video lock is independent', () async {
    final root = Directory.systemTemp.createTempSync('track-lock-caption-sdk-');
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
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
    final video = trackOf(w.current, 'video')['id'] as String;
    final caption = trackOf(w.current, 'caption')['id'] as String;
    w.edit(
      SetTrackState(video, locked: true),
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
          CaptionCue(
            'cue-2',
            TimeRange(Q.of(2), Q.of(1, 5)),
            'later',
            manualFields: {'text', 'timing'},
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    expect((w.current.toJson()['captions'] as List), hasLength(2));
    w.edit(
      SetTrackState(caption, locked: true),
      expectedRevision: w.current.revision,
    );
    final cues = [
      for (final c in (w.current.toJson()['captions'] as List))
        CaptionCue.fromProjectJson(Map<String, dynamic>.from(c as Map)),
    ];
    expect(
      () => w.edit(
        SetCaptions(
          CaptionStore([
            cues.first,
            CaptionCue(
              'cue-2',
              TimeRange(Q.of(2), Q.of(1, 5)),
              'changed',
              manualFields: {'text', 'timing'},
            ),
          ]),
        ),
        expectedRevision: w.current.revision,
      ),
      code('FIELD_LOCKED'),
    );
    expect(cue(w.current, 'cue-2')['text'], 'later');
    expect(
      () => w.edit(MoveClip(a, Q.of(1)), expectedRevision: w.current.revision),
      code('FIELD_LOCKED'),
    );
  });
}
