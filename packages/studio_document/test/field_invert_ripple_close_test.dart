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

Map cueOf(ProjectDocument p, String id) => (p.toJson()['captions'] as List)
    .cast<Map>()
    .singleWhere((c) => c['id'] == id);

int clipCount(ProjectDocument p) => media(p).length;

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

ProjectDocument holeWithCues() {
  var p = splitWithCues();
  return move.change(p, MoveClip('right', Q.of(1)));
}

RippleDeleteClips closeHole() =>
    RippleDeleteClips(const [], range: TimeRange(Q.of(1), Q.of(1)));

ProjectDocument afterMarkers(ProjectDocument p) => move.change(
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

void expectClosed(ProjectDocument p, String a) {
  expect(clipCount(p), 2);
  expect(startOf(p, a), Q.of(0));
  expect(startOf(p, 'right'), Q.of(1));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(seqDur(p), Q.of(3));
  expect(cueOf(p, 'cue-left')['text'], 'hello');
  expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
  expect(cueOf(p, 'cue-right')['text'], 'stay');
  expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
  expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
  expect(Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']), Q.of(3, 2));
}

void expectHoleOpen(ProjectDocument p, String a) {
  expect(clipCount(p), 2);
  expect(startOf(p, a), Q.of(0));
  expect(startOf(p, 'right'), Q.of(2));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(seqDur(p), Q.of(4));
  expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
  expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
  expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
  expect(Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']), Q.of(5, 2));
  expect(
    media(p).where((c) => startOf(p, c['id'] as String) == Q.of(1)),
    isEmpty,
  );
}

void main() {
  test('inverting a ripple-close of a vacated leave-gap hole after a later marker edit reopens the hole and keeps clips, cues, and later markers', () {
    var p = holeWithCues();
    final a = algebra.firstId(p);
    expectHoleOpen(p, a);
    final beforeOp = p;
    p = move.change(p, closeHole());
    final afterOp = p;
    expectClosed(p, a);
    p = afterMarkers(p);
    final changes = documentFieldChanges(
      beforeOp.toJson()..remove('revision'),
      afterOp.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expectHoleOpen(restored, a);
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(
      Q.fromJson((restored.toJson()['markers'] as List).single['time']),
      Q.of(2),
    );
  });

  test('inverting a ripple-close after a later text edit of the followed right cue keeps the new text', () {
    var p = holeWithCues();
    final a = algebra.firstId(p);
    final beforeOp = p;
    p = move.change(p, closeHole());
    final afterOp = p;
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-left')),
    );
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-right')),
    );
    p = move.change(
      p,
      SetCaptions(CaptionStore([hello, stay.editText('revised')])),
    );
    final changes = documentFieldChanges(
      beforeOp.toJson()..remove('revision'),
      afterOp.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expectHoleOpen(restored, a);
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'revised');
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
  });

  test('inverting a ripple-close after a later text edit of the unmoved left cue keeps the new text', () {
    var p = holeWithCues();
    final a = algebra.firstId(p);
    final beforeOp = p;
    p = move.change(p, closeHole());
    final afterOp = p;
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-left')),
    );
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-right')),
    );
    p = move.change(
      p,
      SetCaptions(CaptionStore([hello.editText('revised-left'), stay])),
    );
    final changes = documentFieldChanges(
      beforeOp.toJson()..remove('revision'),
      afterOp.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expectHoleOpen(restored, a);
    expect(cueOf(restored, 'cue-left')['text'], 'revised-left');
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
  });

  test('a later leave-gap move of the packed right remnant conflicts with invert', () {
    var p = holeWithCues();
    final a = algebra.firstId(p);
    final beforeOp = p;
    p = move.change(p, closeHole());
    final afterOp = p;
    expectClosed(p, a);
    p = move.change(p, MoveClip('right', Q.of(1)));
    expect(startOf(p, 'right'), Q.of(2));
    expect(seqDur(p), Q.of(4));
    final changes = documentFieldChanges(
      beforeOp.toJson()..remove('revision'),
      afterOp.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, 'right'), Q.of(2));
    expect(clipCount(p), 2);
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
  });
}
