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

void addTripleCues(StudioWorkspace w, String a) {
  w.edit(SplitClip(a, Q.of(1), 'mid'), expectedRevision: w.current.revision);
  w.edit(
    SplitClip('mid', Q.of(2), 'right'),
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
          'cue-mid',
          TimeRange(Q.of(1), Q.of(1, 2)),
          'there',
          manualFields: {'text', 'timing'},
        ),
        CaptionCue(
          'cue-right',
          TimeRange(Q.of(2), Q.of(1, 2)),
          'stay',
          manualFields: {'text', 'timing'},
        ),
      ]),
    ),
    expectedRevision: w.current.revision,
  );
}

void slideMiddle(StudioWorkspace w, String a) {
  w.edit(
    SlideClip(a, 'mid', 'right', Q.of(1, 2)),
    expectedRevision: w.current.revision,
  );
}

void expectTriple(ProjectDocument p, String a) {
  expect(moveVideos(p), hasLength(3));
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(1));
  expect(sourceStartOf(p, a), Q.of(0));
  expect(startOf(p, 'mid'), Q.of(1));
  expect(durationOf(p, 'mid'), Q.of(1));
  expect(sourceStartOf(p, 'mid'), Q.of(1));
  expect(startOf(p, 'right'), Q.of(2));
  expect(durationOf(p, 'right'), Q.of(1));
  expect(sourceStartOf(p, 'right'), Q.of(2));
  expect(seqDur(p), Q.of(3));
  expect(Q.fromJson(cue(p, 'hello')['timelineRange']['start']), Q.of(0));
  expect(cue(p, 'hello')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cue(p, 'there')['timelineRange']['start']), Q.of(1));
  expect(cue(p, 'there')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'there')['anchor']['clipId'], 'mid');
  expect(Q.fromJson(cue(p, 'stay')['timelineRange']['start']), Q.of(2));
  expect(cue(p, 'stay')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'stay')['anchor']['clipId'], 'right');
}

void expectSlid(ProjectDocument p, String a) {
  expect(moveVideos(p), hasLength(3));
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(3, 2));
  expect(sourceStartOf(p, a), Q.of(0));
  expect(startOf(p, 'mid'), Q.of(3, 2));
  expect(durationOf(p, 'mid'), Q.of(1));
  expect(sourceStartOf(p, 'mid'), Q.of(1));
  expect(startOf(p, 'right'), Q.of(5, 2));
  expect(durationOf(p, 'right'), Q.of(1, 2));
  expect(sourceStartOf(p, 'right'), Q.of(5, 2));
  expect(seqDur(p), Q.of(3));
  expect(Q.fromJson(cue(p, 'hello')['timelineRange']['start']), Q.of(0));
  expect(cue(p, 'hello')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'hello')['anchor']['clipId'], a);
  expect(cue(p, 'hello')['text'], 'hello');
  expect(Q.fromJson(cue(p, 'there')['timelineRange']['start']), Q.of(3, 2));
  expect(cue(p, 'there')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'there')['anchor']['clipId'], 'mid');
  expect(cue(p, 'there')['text'], 'there');
  expect(Q.fromJson(cue(p, 'stay')['timelineRange']['start']), Q.of(5, 2));
  expect(cue(p, 'stay')['anchor']['kind'], 'clipLocal');
  expect(cue(p, 'stay')['anchor']['clipId'], 'right');
  expect(cue(p, 'stay')['text'], 'stay');
}

void expectSlidByTimes(ProjectDocument p) {
  final videos = moveVideos(p);
  expect(videos, hasLength(3));
  final left = videos.singleWhere(
    (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(0),
  );
  final mid = videos.singleWhere(
    (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(3, 2),
  );
  final right = videos.singleWhere(
    (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(5, 2),
  );
  expect(Q.fromJson(left['timelineRange']['duration']), Q.of(3, 2));
  expect(Q.fromJson(left['sourceRange']['start']), Q.of(0));
  expect(Q.fromJson(mid['timelineRange']['duration']), Q.of(1));
  expect(Q.fromJson(mid['sourceRange']['start']), Q.of(1));
  expect(Q.fromJson(right['timelineRange']['duration']), Q.of(1, 2));
  expect(Q.fromJson(right['sourceRange']['start']), Q.of(5, 2));
  expect(seqDur(p), Q.of(3));
  expect(Q.fromJson(cue(p, 'hello')['timelineRange']['start']), Q.of(0));
  expect(cue(p, 'hello')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cue(p, 'there')['timelineRange']['start']), Q.of(3, 2));
  expect(cue(p, 'there')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cue(p, 'stay')['timelineRange']['start']), Q.of(5, 2));
  expect(cue(p, 'stay')['anchor']['kind'], 'clipLocal');
}

void main() {
  test('short path: caption-aware SlideClip of a packed 3s triple, undo/redo, archive fork, sidecar, no MP4 burn-in', () async {
    final root = Directory.systemTemp.createTempSync('caption-slide-clip-sdk-');
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addTripleCues(w, a);
    expectTriple(w.current, a);
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
    slideMiddle(w, a);
    expect(lastCommand(w, 'slideClip'), isNotEmpty);
    expectSlid(w.current, a);
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');
    expect(
      Q.fromJson((w.current.toJson()['markers'] as List).single['time']),
      Q.of(2),
    );
    final slid = w.current;
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    expectTriple(w.current, a);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(slid));
    expectSlid(w.current, a);

    final archive = File('${root.path}/caption-slide-clip.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expectSlidByTimes(w.current);
    expect((w.current.toJson()['markers'] as List).single['label'], 'later');

    final sidecar = File('${root.path}/caption-slide-clip.vtt');
    w.exportCaptions(sidecar, CaptionFormat.vtt);
    expect(sidecar.existsSync(), isTrue);
    final text = sidecar.readAsStringSync();
    expect(text, contains('hello'));
    expect(text, contains('there'));
    expect(text, contains('stay'));
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

  test('a slide that would uncover a source cue, leave the triple, or exhaust source is a whole-group refusal', () async {
    final root = Directory.systemTemp.createTempSync(
      'caption-slide-clip-refuse-sdk-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final w = openMoveWorkspace(root);
    addTearDown(w.close);
    await installSingleClip(w, root);
    final a = videoId(w.current);
    addTripleCues(w, a);

    w.edit(MoveClip('right', Q.of(1)), expectedRevision: w.current.revision);
    expect(
      () => w.edit(
        SlideClip(a, 'mid', 'right', Q.of(1, 2)),
        expectedRevision: w.current.revision,
      ),
      code('NOT_ADJACENT'),
    );
    expect(startOf(w.current, 'right'), Q.of(3));
    w.undo(expectedRevision: w.current.revision);
    expectTriple(w.current, a);

    w.edit(SlipClip(a, Q.of(2)), expectedRevision: w.current.revision);
    expect(
      () => w.edit(
        SlideClip(a, 'mid', 'right', Q.of(1, 30)),
        expectedRevision: w.current.revision,
      ),
      code('SOURCE_OUT_OF_RANGE'),
    );
    expect(sourceStartOf(w.current, a), Q.of(2));
    expect(durationOf(w.current, a), Q.of(1));
    w.undo(expectedRevision: w.current.revision);
    expectTriple(w.current, a);

    final host = clipOf(w.current, 'right');
    final sourceCue =
        CaptionCue(
          'cue-src',
          TimeRange(Q.of(17, 8), Q.of(1, 2)),
          'src',
          manualFields: {'text', 'timing'},
        ).anchoredToSource(
          clipId: 'right',
          clipStart: Q.fromJson(host['timelineRange']['start']),
          clipDuration: Q.fromJson(host['timelineRange']['duration']),
          sourceDuration: Q.fromJson(host['sourceRange']['duration']),
          rate: Q.fromJson(host['timeMap']['rate']),
        );
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cue(w.current, 'hello')),
    );
    final there = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cue(w.current, 'there')),
    );
    w.edit(
      SetCaptions(CaptionStore([hello, there, sourceCue])),
      expectedRevision: w.current.revision,
    );
    final before = contents(w.current);
    expect(
      () => w.edit(
        SlideClip(a, 'mid', 'right', Q.of(1, 2)),
        expectedRevision: w.current.revision,
      ),
      code('ANCHOR_OUT_OF_RANGE'),
    );
    expect(contents(w.current), before);
    expect(startOf(w.current, 'right'), Q.of(2));
    expect(durationOf(w.current, a), Q.of(1));
    expect(startOf(w.current, 'mid'), Q.of(1));
  });
}
