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

List<Map> media(ProjectDocument p) => [...moveVideos(p)];

Map clipOf(ProjectDocument p, String id) =>
    media(p).singleWhere((c) => c['id'] == id);

Q startOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['start']);

Q durationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

Q sourceStartOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['start']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

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

void addSplitCues(StudioWorkspace w, String a) {
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
          'cue-right',
          TimeRange(Q.of(3, 2), Q.of(1, 2)),
          'stay',
          manualFields: {'text', 'timing'},
        ),
      ]),
    ),
    expectedRevision: w.current.revision,
  );
}

void slipLeft(StudioWorkspace w, String a) {
  w.edit(SlipClip(a, Q.of(1, 2)), expectedRevision: w.current.revision);
}

void expectSplit(ProjectDocument p, String a) {
  expect(moveVideos(p), hasLength(2));
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(1));
  expect(sourceStartOf(p, a), Q.of(0));
  expect(startOf(p, 'right'), Q.of(1));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(sourceStartOf(p, 'right'), Q.of(1));
  expect(seqDur(p), Q.of(3));
  expect(Q.fromJson(cue(p, 'hello')['timelineRange']['start']), Q.of(0));
  expect(cue(p, 'hello')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cue(p, 'stay')['timelineRange']['start']), Q.of(3, 2));
  expect(cue(p, 'stay')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'stay')['anchor']['clipId'], 'right');
}

void expectSlipped(ProjectDocument p, String a) {
  expect(moveVideos(p), hasLength(2));
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(1));
  expect(sourceStartOf(p, a), Q.of(1, 2));
  expect(startOf(p, 'right'), Q.of(1));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(sourceStartOf(p, 'right'), Q.of(1));
  expect(seqDur(p), Q.of(3));
  expect(Q.fromJson(cue(p, 'hello')['timelineRange']['start']), Q.of(0));
  expect(cue(p, 'hello')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'hello')['anchor']['clipId'], a);
  expect(cue(p, 'hello')['text'], 'hello');
  expect(Q.fromJson(cue(p, 'stay')['timelineRange']['start']), Q.of(3, 2));
  expect(cue(p, 'stay')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'stay')['anchor']['clipId'], 'right');
  expect(cue(p, 'stay')['text'], 'stay');
}

void expectSlippedByTimes(ProjectDocument p) {
  final videos = moveVideos(p);
  expect(videos, hasLength(2));
  final left = videos.singleWhere(
    (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(0),
  );
  final right = videos.singleWhere(
    (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(1),
  );
  expect(Q.fromJson(left['timelineRange']['duration']), Q.of(1));
  expect(Q.fromJson(left['sourceRange']['start']), Q.of(1, 2));
  expect(Q.fromJson(right['timelineRange']['duration']), Q.of(2));
  expect(Q.fromJson(right['sourceRange']['start']), Q.of(1));
  expect(seqDur(p), Q.of(3));
  expect(Q.fromJson(cue(p, 'hello')['timelineRange']['start']), Q.of(0));
  expect(cue(p, 'hello')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cue(p, 'stay')['timelineRange']['start']), Q.of(3, 2));
  expect(cue(p, 'stay')['anchor']['kind'], 'clipLocal');
}

void main() {
  test('short path: caption-aware SlipClip of the left remnant, undo/redo, archive fork, sidecar, no MP4 burn-in', () async {
    final root = Directory.systemTemp.createTempSync('caption-slip-clip-sdk-');
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    expectSplit(w.current, a);
    w.edit(
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-later',
            sequenceId: w.current.toJson()['sequences'][0]['id'] as String,
            label: 'later',
            time: Q.of(2),
          ),
        ]),
      ),
      expectedRevision: w.current.revision,
    );
    final start = contents(w.current);
    slipLeft(w, a);
    expect(lastCommand(w, 'slipClip'), isNotEmpty);
    expectSlipped(w.current, a);
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    final slipped = w.current;
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    expectSplit(w.current, a);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(slipped));
    expectSlipped(w.current, a);

    final archive = File('${root.path}/caption-slip-clip.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expectSlippedByTimes(w.current);
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');

    final sidecar = File('${root.path}/caption-slip-clip.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    expect(sidecar.existsSync(), isTrue);
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

  test('slip that would uncover a source cue or exhaust the source tail is a whole-group refusal', () async {
    final root = Directory.systemTemp.createTempSync(
      'caption-slip-clip-refuse-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addSplitCues(w, a);
    expect(
      () => w.edit(
        SlipClip('right', Q.of(1, 30)),
        expectedRevision: w.current.revision,
      ),
      code('SOURCE_OUT_OF_RANGE'),
    );
    expectSplit(w.current, a);

    final host = clipOf(w.current, a);
    final sourceCue =
        CaptionCue(
          'cue-src',
          TimeRange(Q.of(0), Q.of(1, 2)),
          'src',
          manualFields: {'text', 'timing'},
        ).anchoredToSource(
          clipId: a,
          clipStart: Q.fromJson(host['timelineRange']['start']),
          clipDuration: Q.fromJson(host['timelineRange']['duration']),
          sourceDuration: Q.fromJson(host['sourceRange']['duration']),
          rate: Q.fromJson(host['timeMap']['rate']),
        );
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cue(w.current, 'stay')),
    );
    w.edit(
      SetCaptions(CaptionStore([sourceCue, stay])),
      expectedRevision: w.current.revision,
    );
    final before = contents(w.current);
    expect(
      () =>
          w.edit(SlipClip(a, Q.of(1, 2)), expectedRevision: w.current.revision),
      code('ANCHOR_OUT_OF_RANGE'),
    );
    expect(contents(w.current), before);
    expect(sourceStartOf(w.current, a), Q.of(0));
    expect(
      Q.fromJson(cue(w.current, 'src')['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(cue(w.current, 'stay')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });
}
