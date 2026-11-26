import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

List<Map> audios(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    if (t['kind'] == 'audio')
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
];

Map cue(ProjectDocument p, String text) => (p.toJson()['captions'] as List)
    .cast<Map>()
    .singleWhere((c) => c['text'] == text);

Map clipOf(ProjectDocument p, String id) =>
    [...moveVideos(p), ...audios(p)].singleWhere((c) => c['id'] == id);

Q startOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['start']);

Q durationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

String policy(ProjectDocument p) =>
    p.toJson()['linkGroups'][0]['syncPolicy'] as String;

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

String audioStreamId(ProjectDocument p) =>
    (p.toJson()['assets'][0]['streams'] as List).singleWhere(
          (s) => s['type'] == 'audio',
        )['id']
        as String;

void addLinkedCues(StudioWorkspace w, String video) {
  w.edit(
    ExtractAudioClip(video, audioStreamId(w.current)),
    expectedRevision: w.current.revision,
  );
  final hello = CaptionCue(
    'cue-left',
    TimeRange(Q.of(0), Q.of(1, 2)),
    'hello',
    manualFields: {'text', 'timing'},
  ).anchoredToClip(video, Q.of(0), Q.of(3));
  final stay = CaptionCue(
    'cue-stay',
    TimeRange(Q.of(2), Q.of(1, 2)),
    'stay',
    manualFields: {'text', 'timing'},
  );
  w.edit(
    SetCaptions(CaptionStore([hello, stay])),
    expectedRevision: w.current.revision,
  );
  w.edit(
    SetCaptions(
      CaptionStore([
        CaptionCue.fromProjectJson(
          Map<String, dynamic>.from(
            (w.current.toJson()['captions'] as List)
                .cast<Map>()
                .singleWhere((c) => c['id'] == 'cue-left'),
          ),
        ),
        CaptionCue.fromProjectJson(
          Map<String, dynamic>.from(
            (w.current.toJson()['captions'] as List)
                .cast<Map>()
                .singleWhere((c) => c['id'] == 'cue-stay'),
          ),
        ).makeAbsolute(),
      ]),
    ),
    expectedRevision: w.current.revision,
  );
}

void main() {
  test('persist path: invert includeLinks=false MoveClips of the video host after a later marker edit, undo/redo, archive, VTT, no MP4', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-ignore-links-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final video = videoId(w.current);
    addLinkedCues(w, video);
    final audio = audios(w.current).single['id'] as String;
    expect(policy(w.current), 'preserve');
    w.edit(
      MoveClips([video], Q.of(1), includeLinks: false),
      expectedRevision: w.current.revision,
    );
    final moveId = lastCommand(w, 'moveClips');
    expect(startOf(w.current, video), Q.of(1));
    expect(startOf(w.current, audio), Q.of(0));
    expect(durationOf(w.current, video), Q.of(3));
    expect(durationOf(w.current, audio), Q.of(3));
    expect(policy(w.current), 'allowOutOfSync');
    expect(seqDur(w.current), Q.of(4));
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(1),
    );
    expect(cue(w.current, 'hello')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(2),
    );
    expect(cue(w.current, 'stay')['anchor']['kind'], 'absolute');
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-1',
            sequenceId: w.current.toJson()['rootSequenceId'] as String,
            label: 'later',
            time: Q.of(3),
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final beforeInvert = contents(w.current);
    w.invertCommand(moveId, expectedRevision: w.current.revision);

    expect(moveVideos(w.current), hasLength(1));
    expect(audios(w.current), hasLength(1));
    expect(startOf(w.current, video), Q.of(0));
    expect(startOf(w.current, audio), Q.of(0));
    expect(policy(w.current), 'preserve');
    expect(seqDur(w.current), Q.of(3));
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cue(w.current, 'hello')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(2),
    );
    expect(cue(w.current, 'stay')['anchor']['kind'], 'absolute');
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    final inverted = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), beforeInvert);
    expect(startOf(w.current, video), Q.of(1));
    expect(startOf(w.current, audio), Q.of(0));
    expect(policy(w.current), 'allowOutOfSync');
    expect(seqDur(w.current), Q.of(4));
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), inverted);
    expect(startOf(w.current, video), Q.of(0));
    expect(startOf(w.current, audio), Q.of(0));
    expect(policy(w.current), 'preserve');
    expect(seqDur(w.current), Q.of(3));

    final archive = File('${root.path}/invert-ignore-links.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'hello', 'stay'},
    );
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    expect(moveVideos(w.current), hasLength(1));
    expect(audios(w.current), hasLength(1));
    expect(
      Q.fromJson(moveVideos(w.current).single['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(audios(w.current).single['timelineRange']['start']),
      Q.of(0),
    );
    expect(policy(w.current), 'preserve');
    expect(seqDur(w.current), Q.of(3));
    expect(
      (w.current.toJson()['captions'] as List)
          .cast<Map>()
          .singleWhere((c) => c['text'] == 'stay')['anchor']['kind'],
      'absolute',
    );
    expect(
      Q.fromJson(
        (w.current.toJson()['captions'] as List)
            .cast<Map>()
            .singleWhere((c) => c['text'] == 'hello')['timelineRange']['start'],
      ),
      Q.of(0),
    );

    final sidecar = File('${root.path}/invert-ignore-links.vtt');
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

  test('invert of the tip includeLinks=false MoveClips or of includeLinks=false MoveClips after a later second ignore-links move is UNDO_CONFLICT', () async {
    final root = Directory.systemTemp.createTempSync(
      'invert-ignore-links-conflict-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final video = videoId(w.current);
    addLinkedCues(w, video);
    final audio = audios(w.current).single['id'] as String;
    w.edit(
      MoveClips([video], Q.of(1), includeLinks: false),
      expectedRevision: w.current.revision,
    );
    final moveId = lastCommand(w, 'moveClips');
    expect(startOf(w.current, video), Q.of(1));
    expect(startOf(w.current, audio), Q.of(0));
    expect(policy(w.current), 'allowOutOfSync');
    expect(
      () => w.invertCommand(moveId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(startOf(w.current, video), Q.of(1));
    expect(startOf(w.current, audio), Q.of(0));
    expect(policy(w.current), 'allowOutOfSync');
    w.edit(
      MoveClips([video], Q.of(1, 2), includeLinks: false),
      expectedRevision: w.current.revision,
    );
    expect(startOf(w.current, video), Q.of(3, 2));
    expect(startOf(w.current, audio), Q.of(0));
    expect(
      () => w.invertCommand(moveId, expectedRevision: w.current.revision),
      code('UNDO_CONFLICT'),
    );
    expect(startOf(w.current, video), Q.of(3, 2));
    expect(startOf(w.current, audio), Q.of(0));
    expect(policy(w.current), 'allowOutOfSync');
    expect(
      Q.fromJson(cue(w.current, 'hello')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(2),
    );
  });
}
