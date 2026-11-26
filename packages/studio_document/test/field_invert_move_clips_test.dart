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

MoveClips bothPlusOne(ProjectDocument p) =>
    MoveClips([algebra.firstId(p), 'right'], Q.of(1));

void main() {
  test('inverting a leave-gap MoveClips of both remnants after a later marker edit restores followed cues', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, 'right'), Q.of(1));
    final beforeMove = p;
    p = move.change(p, bothPlusOne(p));
    final afterMove = p;
    expect(startOf(p, a), Q.of(1));
    expect(startOf(p, 'right'), Q.of(2));
    expect(
      Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']),
      Q.of(1),
    );
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
    p = afterMarkers(p);
    final changes = documentFieldChanges(
      beforeMove.toJson()..remove('revision'),
      afterMove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(clipCount(restored), 2);
    expect(startOf(restored, a), Q.of(0));
    expect(startOf(restored, 'right'), Q.of(1));
    expect(durationOf(restored, 'right'), Q.of(2));
    expect(durationOf(restored, a), Q.of(1));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
  });

  test('inverting a leave-gap MoveClips of both remnants after a later text edit of the followed right cue keeps the new text', () {
    var p = splitWithCues();
    final beforeMove = p;
    p = move.change(p, bothPlusOne(p));
    final afterMove = p;
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
      beforeMove.toJson()..remove('revision'),
      afterMove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(startOf(restored, 'right'), Q.of(1));
    expect(startOf(restored, algebra.firstId(restored)), Q.of(0));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'revised');
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
  });

  test('inverting a leave-gap MoveClips of both remnants after a later text edit of the followed left cue keeps the new text', () {
    var p = splitWithCues();
    final beforeMove = p;
    p = move.change(p, bothPlusOne(p));
    final afterMove = p;
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
      beforeMove.toJson()..remove('revision'),
      afterMove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(startOf(restored, 'right'), Q.of(1));
    expect(cueOf(restored, 'cue-left')['text'], 'revised-left');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
  });

  test('a later second leave-gap MoveClips of the same remnants conflicts with invert', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforeMove = p;
    p = move.change(p, bothPlusOne(p));
    final afterMove = p;
    p = move.change(p, MoveClips([a, 'right'], Q.of(1)));
    expect(startOf(p, a), Q.of(2));
    expect(startOf(p, 'right'), Q.of(3));
    final changes = documentFieldChanges(
      beforeMove.toJson()..remove('revision'),
      afterMove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(startOf(p, a), Q.of(2));
    expect(startOf(p, 'right'), Q.of(3));
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(7, 2),
    );
  });
}
