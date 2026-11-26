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

void main() {
  test('inverting leave-gap delete of the right remnant after a later marker edit restores the cue', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    expect(clipCount(p), 2);
    final beforeDelete = p;
    p = move.change(p, DeleteClip('right'));
    final afterDelete = p;
    expect(clipCount(p), 1);
    expect(startOf(p, a), Q.of(0));
    expect(cueOf(p, 'cue-right')['text'], 'stay');
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'absolute');
    p = afterMarkers(p);
    final changes = documentFieldChanges(
      beforeDelete.toJson()..remove('revision'),
      afterDelete.toJson()..remove('revision'),
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
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect(cueOf(restored, 'cue-right')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
  });

  test('inverting leave-gap delete of the right remnant after a later text edit of the left cue keeps the new text', () {
    var p = splitWithCues();
    final beforeDelete = p;
    p = move.change(p, DeleteClip('right'));
    final afterDelete = p;
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
      beforeDelete.toJson()..remove('revision'),
      afterDelete.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(clipCount(restored), 2);
    expect(startOf(restored, 'right'), Q.of(1));
    expect(cueOf(restored, 'cue-left')['text'], 'revised-left');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect(cueOf(restored, 'cue-right')['anchor']['kind'], 'clipLocal');
  });

  test('inverting leave-gap delete of the right remnant after a later text edit of the leftover cue keeps the new text', () {
    var p = splitWithCues();
    final beforeDelete = p;
    p = move.change(p, DeleteClip('right'));
    final afterDelete = p;
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-right')),
    );
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-left')),
    );
    p = move.change(
      p,
      SetCaptions(CaptionStore([hello, stay.editText('revised')])),
    );
    final changes = documentFieldChanges(
      beforeDelete.toJson()..remove('revision'),
      afterDelete.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(clipCount(restored), 2);
    expect(startOf(restored, 'right'), Q.of(1));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'revised');
    expect(cueOf(restored, 'cue-right')['anchor']['kind'], 'clipLocal');
  });

  test('a later leave-gap out-trim of the left remnant remints the filler and conflicts with invert', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforeDelete = p;
    p = move.change(p, DeleteClip('right'));
    final afterDelete = p;
    p = move.change(p, TrimClip(a, 'out', Q.of(-1, 2)));
    expect(durationOf(p, a), Q.of(1, 2));
    final changes = documentFieldChanges(
      beforeDelete.toJson()..remove('revision'),
      afterDelete.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(clipCount(p), 1);
    expect(durationOf(p, a), Q.of(1, 2));
    expect(cueOf(p, 'cue-right')['text'], 'stay');
  });
}
