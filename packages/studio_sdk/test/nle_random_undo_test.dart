import 'dart:io';
import 'dart:math';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Q startOf(Map c) => Q.fromJson(c['timelineRange']['start']);

List<Map> cuesOf(ProjectDocument p) =>
    (p.toJson()['captions'] as List).cast<Map>();

List<Map> markersOf(ProjectDocument p) =>
    (p.toJson()['markers'] as List).cast<Map>();

void attachBaseline(StudioWorkspace w) {
  final last = moveVideos(w.current).last;
  final id = last['id'] as String;
  final cs = startOf(last);
  final cd = Q.fromJson(last['timelineRange']['duration']);
  final sd = Q.fromJson(last['sourceRange']['duration']);
  final rate = Q.fromJson(last['timeMap']['rate']);
  final local = CaptionCue(
    'cue-local',
    TimeRange(cs, Q.of(1, 2)),
    'local',
    manualFields: {'text', 'timing'},
  ).anchoredToClip(id, cs, cd);
  final sourced =
      CaptionCue(
        'cue-source',
        TimeRange(cs + Q.of(1, 2), Q.of(1, 4)),
        'source',
        manualFields: {'text', 'timing'},
      ).anchoredToSource(
        clipId: id,
        clipStart: cs,
        clipDuration: cd,
        sourceDuration: sd,
        rate: rate,
      );
  w.edit(
    SetCaptions(CaptionStore([local, sourced])),
    expectedRevision: w.current.revision,
  );
  // cs+0.5+0.25 = cs+0.75, last clip is 1.5s long starting at 1.5, so 1.5-3.0.
  // local [1.5, 2.0), source [2.0, 2.25) — both on last clip. Good.
  final seq = w.current.toJson()['rootSequenceId'] as String;
  w.edit(
    SetMarkers(
      MarkerStore([
        TimelineMarker(
          'mark-local',
          sequenceId: seq,
          label: 'follow',
          time: cs + Q.of(1, 4),
        ).anchoredToClip(id, cs, cd),
        TimelineMarker(
          'mark-abs',
          sequenceId: seq,
          label: 'stay',
          time: Q.of(1, 4),
        ),
      ]),
    ),
    expectedRevision: w.current.revision,
  );
}

EditOperation fallbackEdit(ProjectDocument p, int n) {
  final cues = [
    for (final c in cuesOf(p))
      CaptionCue.fromProjectJson(Map<String, dynamic>.from(c)),
  ];
  cues[0] = cues[0].editText('local-$n');
  return SetCaptions(CaptionStore(cues));
}

EditOperation? randomOp(ProjectDocument p, Random rng, int n) {
  final videos = moveVideos(p);
  if (videos.isEmpty) {
    return null;
  }
  final last = videos.last;
  final id = last['id'] as String;
  final kind = rng.nextInt(12);
  final frames = rng.nextInt(8) + 1;
  switch (kind) {
    case 0:
    case 1:
    case 2:
      return MoveClips(
        [id],
        Q.of(rng.nextBool() ? frames : -frames, 30),
        includeLinks: rng.nextBool(),
      );
    case 3:
      return MoveClips(
        [id],
        Q.of(frames, 30),
        mode: 'insert',
        includeLinks: false,
      );
    case 4:
      return RippleDeleteClips(
        const [],
        range: TimeRange(Q.of(rng.nextInt(30), 30), Q.of(1, 30)),
      );
    case 5:
      return RippleTrimClip(id, 'out', Q.of(rng.nextBool() ? 1 : -1, 30));
    case 6:
      final marks = [
        for (final m in markersOf(p))
          TimelineMarker.fromJson(Map<String, dynamic>.from(m)),
      ];
      if (marks.isEmpty) {
        return fallbackEdit(p, n);
      }
      marks[0] = TimelineMarker(
        marks[0].id,
        sequenceId: marks[0].sequenceId,
        label: 'stay-$n',
        time: marks[0].time,
        duration: marks[0].duration,
        ripple: marks[0].ripple,
        anchorKind: marks[0].anchorKind,
        anchorClipId: marks[0].anchorClipId,
        colorRGBA: marks[0].colorRGBA,
      );
      return SetMarkers(MarkerStore(marks));
    default:
      return fallbackEdit(p, n);
  }
}

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('nle-random-undo-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
    attachBaseline(w);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('locked-or-negative move refuses atomically; 1000 seeded NLE edits undo to the same content hash', () async {
    final first = moveVideos(w.current).first['id'] as String;
    final start = w.current;
    final startHash = contents(start);
    expect(
      () => w.edit(
        MoveClips([first], Q.of(-1)),
        expectedRevision: w.current.revision,
      ),
      code('NEGATIVE_TIMELINE_START'),
    );
    expect(contents(w.current), startHash);
    expect(cuesOf(w.current).map((c) => c['text']), ['local', 'source']);

    final rng = Random(0x10005e05);
    var applied = 0;
    var attempts = 0;
    while (applied < 1000) {
      attempts++;
      expect(
        attempts,
        lessThan(5000),
        reason: 'could not collect 1000 legal edits',
      );
      final before = w.current;
      final beforeHash = contents(before);
      final op =
          randomOp(before, rng, applied) ?? fallbackEdit(before, applied);
      try {
        w.edit(op, expectedRevision: before.revision);
        if (contents(w.current) == beforeHash) {
          continue;
        }
        final sourceStill = [
          for (final c in cuesOf(w.current))
            if (c['anchor']['kind'] == 'source') c['id'],
        ];
        expect(sourceStill, contains('cue-source'));
        applied++;
      } on StudioException {
        expect(contents(w.current), beforeHash);
        expect(cuesOf(w.current).map((c) => c['id']).toList(), [
          'cue-local',
          'cue-source',
        ]);
      }
    }
    expect(applied, 1000);
    for (var i = 0; i < 1000; i++) {
      w.undo(expectedRevision: w.current.revision);
    }
    expect(contents(w.current), startHash);
    expect(cuesOf(w.current).map((c) => c['text']), ['local', 'source']);
    expect(
      {for (final m in markersOf(w.current)) m['id']: m['label']},
      {'mark-local': 'follow', 'mark-abs': 'stay'},
    );
    for (var i = 0; i < 1000; i++) {
      w.redo(expectedRevision: w.current.revision);
    }
    final redone = contents(w.current);
    w.undo(expectedRevision: w.current.revision);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), redone);
  }, timeout: Timeout(const Duration(minutes: 10)));

  test('short opened-NLE path: one command, undo/redo, archive fork, sidecar, no MP4 burn-in', () async {
    final last = moveVideos(w.current).last['id'] as String;
    final start = contents(w.current);
    w.edit(
      MoveClips([last], Q.of(1, 2), includeLinks: false),
      expectedRevision: w.current.revision,
    );
    expect(contents(w.current), isNot(start));
    expect(
      cuesOf(w.current).any((c) => c['anchor']['kind'] == 'source'),
      isTrue,
    );
    final moved = w.current;
    w.undo(expectedRevision: w.current.revision);
    expect(contents(w.current), start);
    w.redo(expectedRevision: w.current.revision);
    expect(contents(w.current), contents(moved));
    final archive = File('${root.path}/nle-random.studio-project');
    await w.saveArchive(archive);
    await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
    expect(w.canUndo, false);
    expect(cuesOf(w.current).map((c) => c['text']).toSet(), {
      'local',
      'source',
    });
    expect(
      cuesOf(w.current).any((c) => c['anchor']['kind'] == 'source'),
      isTrue,
    );
    expect(markersOf(w.current).map((m) => m['label']).toSet(), {
      'follow',
      'stay',
    });
    final sidecar = File('${root.path}/nle.vtt');
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
