import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as algebra;
import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

Map clipOf(ProjectDocument p, String id) =>
    media(p).singleWhere((c) => c['id'] == id);

Q startOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['start']);

Q durationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

Q sourceStartOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['start']);

Q sourceDurationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['duration']);

Map cueOf(ProjectDocument p, String id) => (p.toJson()['captions'] as List)
    .cast<Map>()
    .singleWhere((c) => c['id'] == id);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

void assertPure(ProjectDocument before, void Function() action) {
  final start = content(before);
  final raw = jsonEncode(before.toJson());
  action();
  expect(content(before), start);
  expect(jsonEncode(before.toJson()), raw);
}

ProjectDocument attachDefaults(ProjectDocument p, List<CaptionCue> cues) {
  var out = move.change(p, SetCaptions(CaptionStore(cues)));
  final next = [
    for (final c in (out.toJson()['captions'] as List))
      CaptionCue.fromProjectJson(Map<String, dynamic>.from(c as Map)),
  ];
  return move.change(out, SetCaptions(CaptionStore(next)));
}

ProjectDocument splitWithCues() {
  var p = avFixture();
  final a = algebra.firstId(p);
  p = move.change(p, SplitClip(a, Q.of(1), 'right'));
  return attachDefaults(p, [
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
  ]);
}

ProjectDocument splitTripleWithCues() {
  var p = avFixture();
  final a = algebra.firstId(p);
  p = move.change(p, SplitClip(a, Q.of(1), 'mid'));
  p = move.change(p, SplitClip('mid', Q.of(2), 'right'));
  return attachDefaults(p, [
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
  ]);
}

/// +15 frames at 30fps, matching the s3 slip/roll/slide examples.
final delta = Q.of(1, 2);

ProjectDocument invert(
  ProjectDocument current,
  ProjectDocument before,
  ProjectDocument after,
) {
  final changes = documentFieldChanges(
    before.toJson()..remove('revision'),
    after.toJson()..remove('revision'),
  );
  expect(fieldInvertConflicts(current.toJson(), changes), isFalse);
  return ProjectDocument.fromJson(
    applyFieldInvert(current.toJson(), changes)
      ..['revision'] = current.revision.toString(),
  );
}

void expectConflict(
  ProjectDocument current,
  ProjectDocument before,
  ProjectDocument after,
) {
  final changes = documentFieldChanges(
    before.toJson()..remove('revision'),
    after.toJson()..remove('revision'),
  );
  expect(fieldInvertConflicts(current.toJson(), changes), isTrue);
  assertPure(current, () {
    expect(
      () => applyFieldInvert(current.toJson(), changes),
      code('UNDO_CONFLICT'),
    );
  });
}

void main() {
  test('inverting slip after a later leave-gap move of the other remnant keeps moved cues', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    expect(sourceStartOf(p, a), Q.of(0));
    expect(startOf(p, a), Q.of(0));
    expect(durationOf(p, a), Q.of(1));
    final before = p;
    p = move.change(p, SlipClip(a, delta));
    final after = p;
    expect(sourceStartOf(p, a), Q.of(1, 2));
    expect(startOf(p, a), Q.of(0));
    expect(durationOf(p, a), Q.of(1));
    expect(seqDur(p), Q.of(3));
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    p = move.change(p, MoveClips(['right'], Q.of(1)));
    expect(startOf(p, 'right'), Q.of(2));
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
    final restored = invert(p, before, after);
    expect(sourceStartOf(restored, a), Q.of(0));
    expect(sourceDurationOf(restored, a), Q.of(1));
    expect(startOf(restored, a), Q.of(0));
    expect(durationOf(restored, a), Q.of(1));
    expect(startOf(restored, 'right'), Q.of(2));
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect(seqDur(restored), Q.of(4));
  });

  test('a later slip that changes the recorded source-start numerator conflicts with invert', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final before = p;
    p = move.change(p, SlipClip(a, delta));
    final after = p;
    p = move.change(p, SlipClip(a, Q.of(1, 30)));
    expect(sourceStartOf(p, a), Q.of(16, 30));
    expectConflict(p, before, after);
    expect(sourceStartOf(p, a), Q.of(16, 30));
    expect(startOf(p, a), Q.of(0));
    expect(cueOf(p, 'cue-left')['text'], 'hello');
  });

  test('inverting roll after an unrelated marker edit leaves markers and restores the cut', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final before = p;
    p = move.change(p, RollCut(a, 'right', delta));
    final after = p;
    expect(durationOf(p, a), Q.of(3, 2));
    expect(startOf(p, 'right'), Q.of(3, 2));
    expect(seqDur(p), Q.of(3));
    p = move.change(
      p,
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-1',
            sequenceId: p.toJson()['rootSequenceId'] as String,
            label: 'later',
            time: Q.of(2),
          ),
        ]),
      ),
    );
    final restored = invert(p, before, after);
    expect(startOf(restored, a), Q.of(0));
    expect(durationOf(restored, a), Q.of(1));
    expect(sourceStartOf(restored, a), Q.of(0));
    expect(sourceDurationOf(restored, a), Q.of(1));
    expect(startOf(restored, 'right'), Q.of(1));
    expect(durationOf(restored, 'right'), Q.of(2));
    expect(sourceStartOf(restored, 'right'), Q.of(1));
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect(seqDur(restored), Q.of(3));
  });

  test('a later leave-gap move of a rolled remnant conflicts with invert', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final before = p;
    p = move.change(p, RollCut(a, 'right', delta));
    final after = p;
    p = move.change(p, MoveClips(['right'], Q.of(1)));
    expect(startOf(p, 'right'), Q.of(5, 2));
    expectConflict(p, before, after);
    expect(startOf(p, 'right'), Q.of(5, 2));
    expect(durationOf(p, a), Q.of(3, 2));
    expect(cueOf(p, 'cue-left')['text'], 'hello');
  });

  test('inverting slide after an unrelated marker edit leaves markers and restores the triple', () {
    var p = splitTripleWithCues();
    final a = algebra.firstId(p);
    final before = p;
    p = move.change(p, SlideClip(a, 'mid', 'right', delta));
    final after = p;
    expect(durationOf(p, a), Q.of(3, 2));
    expect(startOf(p, 'mid'), Q.of(3, 2));
    expect(sourceStartOf(p, 'mid'), Q.of(1));
    expect(startOf(p, 'right'), Q.of(5, 2));
    expect(seqDur(p), Q.of(3));
    p = move.change(
      p,
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-1',
            sequenceId: p.toJson()['rootSequenceId'] as String,
            label: 'later',
            time: Q.of(2),
          ),
        ]),
      ),
    );
    final restored = invert(p, before, after);
    expect(startOf(restored, a), Q.of(0));
    expect(durationOf(restored, a), Q.of(1));
    expect(sourceDurationOf(restored, a), Q.of(1));
    expect(startOf(restored, 'mid'), Q.of(1));
    expect(durationOf(restored, 'mid'), Q.of(1));
    expect(sourceStartOf(restored, 'mid'), Q.of(1));
    expect(startOf(restored, 'right'), Q.of(2));
    expect(durationOf(restored, 'right'), Q.of(1));
    expect(sourceStartOf(restored, 'right'), Q.of(2));
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(cueOf(restored, 'cue-mid')['timelineRange']['start']),
      Q.of(1),
    );
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(2),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(cueOf(restored, 'cue-mid')['text'], 'there');
    expect(seqDur(restored), Q.of(3));
  });

  test('a later leave-gap out-trim of the lengthened left remnant conflicts with invert', () {
    var p = splitTripleWithCues();
    final a = algebra.firstId(p);
    final before = p;
    p = move.change(p, SlideClip(a, 'mid', 'right', delta));
    final after = p;
    p = move.change(p, TrimClip(a, 'out', Q.of(-1, 30)));
    expect(durationOf(p, a), Q.of(44, 30));
    expectConflict(p, before, after);
    expect(durationOf(p, a), Q.of(44, 30));
    expect(startOf(p, 'mid'), Q.of(3, 2));
    expect(startOf(p, 'right'), Q.of(5, 2));
    expect(cueOf(p, 'cue-mid')['text'], 'there');
  });
}
