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

RippleTrimClip lengthenLeft(String a) => RippleTrimClip(a, 'out', Q.of(1));

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

void expectSplit(ProjectDocument p, String a) {
  expect(clipCount(p), 2);
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(1));
  expect(startOf(p, 'right'), Q.of(1));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(seqDur(p), Q.of(3));
  expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
  expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
  expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
  expect(Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']), Q.of(3, 2));
}

void expectLengthened(ProjectDocument p, String a) {
  expect(clipCount(p), 2);
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(2));
  expect(startOf(p, 'right'), Q.of(2));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(seqDur(p), Q.of(4));
  expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
  expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
  expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
  expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
  expect(Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']), Q.of(5, 2));
}

void main() {
  test('inverting a ripple-trim-lengthen of the left remnant after a later marker edit restores duration and later starts, and keeps later markers', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    expectSplit(p, a);
    final beforeOp = p;
    p = move.change(p, lengthenLeft(a));
    final afterOp = p;
    expectLengthened(p, a);
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
    expectSplit(restored, a);
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(
      Q.fromJson((restored.toJson()['markers'] as List).single['time']),
      Q.of(2),
    );
  });

  test('inverting a ripple-trim-lengthen after a later text edit of the followed right cue keeps the new text', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforeOp = p;
    p = move.change(p, lengthenLeft(a));
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
    expectSplit(restored, a);
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'revised');
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });

  test('inverting a ripple-trim-lengthen after a later text edit of the unmoved left cue keeps the new text', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforeOp = p;
    p = move.change(p, lengthenLeft(a));
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
    expectSplit(restored, a);
    expect(cueOf(restored, 'cue-left')['text'], 'revised-left');
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });

  test('a later ripple-trim-lengthen rewrite of the same remnant conflicts with invert', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforeOp = p;
    p = move.change(p, lengthenLeft(a));
    final afterOp = p;
    expectLengthened(p, a);
    p = move.change(p, RippleTrimClip(a, 'out', Q.of(1)));
    expect(durationOf(p, a), Q.of(3));
    expect(startOf(p, 'right'), Q.of(3));
    expect(seqDur(p), Q.of(5));
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
    expect(durationOf(p, a), Q.of(3));
    expect(startOf(p, 'right'), Q.of(3));
    expect(clipCount(p), 2);
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(7, 2),
    );
  });
}
