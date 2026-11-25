import 'dart:io';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

/// Scaled s3 table frame (÷5) so the 450-frame sequence fits the 3s fixture.
Q f(int frames) => Q.of(frames, 150);

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

List<Map> videos(ProjectDocument p) => moveVideos(p);

Map clip(ProjectDocument p, String id) =>
    videos(p).singleWhere((c) => c['id'] == id);

Q startOf(ProjectDocument p, String id) =>
    Q.fromJson(clip(p, id)['timelineRange']['start']);

Q durOf(ProjectDocument p, String id) =>
    Q.fromJson(clip(p, id)['timelineRange']['duration']);

Q sourceStartOf(ProjectDocument p, String id) =>
    Q.fromJson(clip(p, id)['sourceRange']['start']);

Q sourceDurOf(ProjectDocument p, String id) =>
    Q.fromJson(clip(p, id)['sourceRange']['duration']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

String idA(ProjectDocument p) => videos(p)
    .reduce(
      (a, b) =>
          Q.fromJson(a['timelineRange']['start']) <=
              Q.fromJson(b['timelineRange']['start'])
          ? a
          : b,
    )['id'] as String;

String idAt(ProjectDocument p, Q start) => videos(p).singleWhere(
      (c) => Q.fromJson(c['timelineRange']['start']) == start,
    )['id'] as String;

ProjectDocument detached(ProjectDocument p, EditOperation op) {
  var serial = 0, max = 0;
  void scan(dynamic v) {
    if (v is Map) {
      if (v['version'] is String) {
        final n = int.tryParse(v['version']);
        if (n != null && n > max) max = n;
      }
      for (final c in v.values) {
        scan(c);
      }
    } else if (v is List) {
      for (final c in v) {
        scan(c);
      }
    }
  }

  scan(p.toJson());
  final allocations = <String, String>{};
  return applyEdit(
    p,
    op,
    nextVersion: (id) => allocations.putIfAbsent(id, () => '${++max}'),
    newId: () => 's3-${p.hash.substring(7, 15)}-${serial++}',
  );
}

Future<void> muxAv(Directory root) async {
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
}

Future<void> installS3Abc(StudioWorkspace w, Directory root) async {
  w.openDemo();
  await muxAv(root);
  await w.importVideo(
    LocalFileGrant.fromUserSelection(File('${root.path}/av.mp4')),
    expectedRevision: w.current.revision,
    acknowledgeVideoOnly: true,
  );
  final first = idA(w.current);
  w.edit(
    SplitClip(first, Q.of(1), 's3-b'),
    expectedRevision: w.current.revision,
  );
  w.edit(
    SplitClip('s3-b', Q.of(2), 's3-c'),
    expectedRevision: w.current.revision,
  );
  await adoptMoveMetadata(w, root, (d) {
    void plant(String id, Q start) {
      for (final t in d['sequences'][0]['tracks']) {
        for (final item in t['items']) {
          if (item['id'] == id && item['source'] != null) {
            item['sourceRange'] = {
              'start': start.toJson(),
              'duration': Q.of(1).toJson(),
            };
          }
        }
      }
    }

    plant(first, f(30));
    plant('s3-b', f(60));
    plant('s3-c', f(0));
  });
}

void attachFollowAndStay(StudioWorkspace w) {
  final a = idA(w.current);
  final sequenceId = w.current.toJson()['sequences'][0]['id'] as String;
  w.edit(
    SetCaptions(
      CaptionStore([
        CaptionCue(
          'cue-local',
          TimeRange(f(15), f(30)),
          'follow',
          manualFields: {'text', 'timing'},
        ),
        CaptionCue(
          'cue-abs',
          TimeRange(f(330), f(30)),
          'stay',
          manualFields: {'text', 'timing'},
        ),
      ]),
    ),
    expectedRevision: w.current.revision,
  );
  final cues = [
    for (final c in (w.current.toJson()['captions'] as List))
      CaptionCue.fromProjectJson(Map<String, dynamic>.from(c as Map)),
  ].map((c) => c.id == 'cue-abs' ? c.makeAbsolute() : c).toList();
  w.edit(SetCaptions(CaptionStore(cues)), expectedRevision: w.current.revision);
  w.edit(
    SetMarkers(
      MarkerStore([
        TimelineMarker(
          'mark-local',
          sequenceId: sequenceId,
          label: 'on-a',
          time: f(30),
          anchorKind: 'clipLocal',
          anchorClipId: a,
        ),
        TimelineMarker(
          'mark-abs',
          sequenceId: sequenceId,
          label: 'stay',
          time: f(330),
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
    root = Directory.systemTemp.createTempSync('s3-opened-matrix-');
    w = openMoveWorkspace(root);
    await installS3Abc(w, root);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('s3 reject move of A by +30 collides; negative start and revision stay', () {
    final a = idA(w.current);
    final rev = w.current.revision;
    final hash = contents(w.current);
    expect(
      () => w.edit(MoveClips([a], f(30)), expectedRevision: rev),
      code('COLLISION'),
    );
    expect(w.current.revision, rev);
    expect(contents(w.current), hash);
    expect(
      () => w.edit(
        MoveClips([a], Q.of(0) - f(30)),
        expectedRevision: w.current.revision,
      ),
      code('NEGATIVE_TIMELINE_START'),
    );
    expect(w.current.revision, rev);
    expect(contents(w.current), hash);
  });

  test('s3 split of A at 60 remaps the planted source window; endpoints refuse', () {
    final a = idA(w.current);
    final before = contents(w.current);
    w.edit(
      SplitClip(a, f(60), 's3-a-right'),
      expectedRevision: w.current.revision,
    );
    expect(startOf(w.current, a), Q.of(0));
    expect(durOf(w.current, a), f(60));
    expect(sourceStartOf(w.current, a), f(30));
    expect(sourceDurOf(w.current, a), f(60));
    expect(startOf(w.current, 's3-a-right'), f(60));
    expect(sourceStartOf(w.current, 's3-a-right'), f(90));
    expect(sourceDurOf(w.current, 's3-a-right'), f(90));
    expect(seqDur(w.current), f(450));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), before);
    expect(
      () => w.edit(
        SplitClip(a, Q.of(0), 'x'),
        expectedRevision: w.current.revision,
      ),
      throwsA(isA<StudioException>()),
    );
    expect(contents(w.current), before);
  });

  test('s3 insert paste of 60 frames at 150 shifts B and C and grows duration', () {
    final a = idA(w.current);
    final payload = buildClipboard(
      detached(w.current, TrimClip(a, 'out', Q.of(0) - f(90))),
      [a],
    );
    final before = contents(w.current);
    w.edit(
      PasteClips(payload, at: f(150), mode: 'insert'),
      expectedRevision: w.current.revision,
    );
    final b = idAt(w.current, f(210));
    final c = idAt(w.current, f(360));
    expect(startOf(w.current, a), Q.of(0));
    expect(sourceStartOf(w.current, b), f(60));
    expect(durOf(w.current, b), Q.of(1));
    expect(durOf(w.current, c), Q.of(1));
    expect(seqDur(w.current), f(510));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), before);
  });

  test('s3 overwrite [120,210) keeps C and duration; remaps the B tail', () {
    final a = idA(w.current);
    final payload = buildClipboard(
      detached(w.current, TrimClip(a, 'out', Q.of(0) - f(60))),
      [a],
    );
    w.edit(
      PasteClips(payload, at: f(120), mode: 'overwrite'),
      expectedRevision: w.current.revision,
    );
    expect(startOf(w.current, a), Q.of(0));
    expect(durOf(w.current, a), f(120));
    expect(sourceStartOf(w.current, a), f(30));
    final pasted = videos(w.current).singleWhere(
      (c) => Q.fromJson(c['timelineRange']['start']) == f(120),
    );
    expect(Q.fromJson(pasted['timelineRange']['duration']), f(90));
    final b = idAt(w.current, f(210));
    expect(sourceStartOf(w.current, b), f(120));
    expect(durOf(w.current, b), f(90));
    expect(startOf(w.current, idAt(w.current, f(300))), f(300));
    expect(sourceStartOf(w.current, idAt(w.current, f(300))), f(0));
    expect(seqDur(w.current), f(450));
    expect(durOf(w.current, a), f(120));
  });

  test('s3 ripple R=[120,180) remaps B and shortens to 390; lift of clipLocal-marker host refuses', () {
    attachFollowAndStay(w);
    final a = idA(w.current);
    final marked = contents(w.current);
    expect(
      () => w.edit(LiftClips([a]), expectedRevision: w.current.revision),
      code('REF_NOT_FOUND'),
    );
    expect(contents(w.current), marked);
    w.edit(
      RippleDeleteClips(const [], range: TimeRange(f(120), f(60))),
      expectedRevision: w.current.revision,
    );
    expect(startOf(w.current, a), Q.of(0));
    expect(durOf(w.current, a), f(120));
    final remnantB = videos(w.current).singleWhere(
      (c) =>
          Q.fromJson(c['timelineRange']['start']) == f(120) &&
          Q.fromJson(c['timelineRange']['duration']) == f(120),
    );
    expect(sourceStartOf(w.current, remnantB['id'] as String), f(90));
    expect(startOf(w.current, idAt(w.current, f(240))), f(240));
    expect(sourceStartOf(w.current, idAt(w.current, f(240))), f(0));
    expect(seqDur(w.current), f(390));
    final local = (w.current.toJson()['captions'] as List)
        .singleWhere((c) => c['id'] == 'cue-local');
    final abs = (w.current.toJson()['captions'] as List)
        .singleWhere((c) => c['id'] == 'cue-abs');
    expect(local['text'], 'follow');
    expect(Q.fromJson(local['timelineRange']['start']), f(15));
    expect(abs['text'], 'stay');
    expect(Q.fromJson(abs['timelineRange']['start']), f(270));
    expect(
      (w.current.toJson()['markers'] as List)
          .singleWhere((m) => m['id'] == 'mark-abs')['label'],
      'stay',
    );
  });

  test('s3 ordinary leave-gap trim and ripple trim match the table; captions still refuse split/trim', () {
    final a = idA(w.current);
    final start = contents(w.current);
    w.edit(
      TrimClip(a, 'out', Q.of(0) - f(15)),
      expectedRevision: w.current.revision,
    );
    expect(durOf(w.current, a), f(135));
    expect(startOf(w.current, idAt(w.current, f(150))), f(150));
    expect(seqDur(w.current), f(450));
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    w.edit(
      RippleTrimClip(a, 'out', Q.of(0) - f(15)),
      expectedRevision: w.current.revision,
    );
    expect(durOf(w.current, a), f(135));
    expect(startOf(w.current, idAt(w.current, f(135))), f(135));
    expect(startOf(w.current, idAt(w.current, f(285))), f(285));
    expect(seqDur(w.current), f(435));
    w.undo(expectedRevision: w.current.revision);
    attachFollowAndStay(w);
    final withCues = contents(w.current);
    expect(
      () => w.edit(
        SplitClip(a, f(60), 's3-a-right'),
        expectedRevision: w.current.revision,
      ),
      code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
    );
    expect(
      () => w.edit(
        TrimClip(a, 'out', Q.of(0) - f(15)),
        expectedRevision: w.current.revision,
      ),
      code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
    );
    expect(contents(w.current), withCues);
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'follow', 'stay'},
    );
  });

  test('short s3 path: one ripple-trim, undo/redo, archive fork, sidecar, no MP4 burn-in', () async {
    attachFollowAndStay(w);
    final a = idA(w.current);
    final start = contents(w.current);
    w.edit(
      RippleTrimClip(a, 'out', Q.of(0) - f(15)),
      expectedRevision: w.current.revision,
    );
    expect(seqDur(w.current), f(435));
    expect(
      (w.current.toJson()['captions'] as List)
          .singleWhere((c) => c['id'] == 'cue-local')['text'],
      'follow',
    );
    final trimmed = w.current;
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(trimmed));
    final archive = File('${root.path}/s3-matrix.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(seqDur(w.current), f(435));
    expect(
      (w.current.toJson()['captions'] as List).map((c) => c['text']).toSet(),
      {'follow', 'stay'},
    );
    expect(
      (w.current.toJson()['markers'] as List).map((m) => m['label']).toSet(),
      {'on-a', 'stay'},
    );
    final sidecar = File('${root.path}/s3.vtt');
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
