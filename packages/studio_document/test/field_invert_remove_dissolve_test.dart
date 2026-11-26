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

Map? dissolveOf(ProjectDocument p) {
  final list = p.toJson()['transitions'] as List;
  return list.isEmpty ? null : list.single as Map;
}

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

SetDissolve firstDissolve(String a) =>
    SetDissolve(a, 'right', Q.of(1, 5), Q.of(1, 5));

void expectRestoredDissolve(ProjectDocument p, String a) {
  final dissolve = dissolveOf(p)!;
  expect(dissolve['kind'], 'dissolve');
  expect(dissolve['leftClipId'], a);
  expect(dissolve['rightClipId'], 'right');
  expect(Q.fromJson(dissolve['cut']), Q.of(1));
  expect(Q.fromJson(dissolve['before']), Q.of(1, 5));
  expect(Q.fromJson(dissolve['after']), Q.of(1, 5));
}

void main() {
  test('inverting a RemoveDissolve after a later marker edit restores the dissolve and keeps clips, cues, and duration', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    p = move.change(p, firstDissolve(a));
    final tid = dissolveOf(p)!['id'] as String;
    expectRestoredDissolve(p, a);
    final beforeRemove = p;
    p = move.change(p, RemoveDissolve(tid));
    final afterRemove = p;
    expect(p.toJson()['transitions'], isEmpty);
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, 'right'), Q.of(1));
    expect(durationOf(p, 'right'), Q.of(2));
    expect(seqDur(p), Q.of(3));
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cueOf(p, 'cue-right')['text'], 'stay');
    expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    p = afterMarkers(p);
    final changes = documentFieldChanges(
      beforeRemove.toJson()..remove('revision'),
      afterRemove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expectRestoredDissolve(restored, a);
    expect(clipCount(restored), 2);
    expect(startOf(restored, a), Q.of(0));
    expect(startOf(restored, 'right'), Q.of(1));
    expect(durationOf(restored, 'right'), Q.of(2));
    expect(seqDur(restored), Q.of(3));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
    expect(cueOf(restored, 'cue-right')['anchor']['kind'], 'clipLocal');
    expect(cueOf(restored, 'cue-right')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
  });

  test('inverting a RemoveDissolve after a later text edit of the followed right cue keeps the new text', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    p = move.change(p, firstDissolve(a));
    final tid = dissolveOf(p)!['id'] as String;
    final beforeRemove = p;
    p = move.change(p, RemoveDissolve(tid));
    final afterRemove = p;
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
      beforeRemove.toJson()..remove('revision'),
      afterRemove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expectRestoredDissolve(restored, a);
    expect(clipCount(restored), 2);
    expect(startOf(restored, 'right'), Q.of(1));
    expect(seqDur(restored), Q.of(3));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'revised');
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });

  test('inverting a RemoveDissolve after a later text edit of the unmoved left cue keeps the new text', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    p = move.change(p, firstDissolve(a));
    final tid = dissolveOf(p)!['id'] as String;
    final beforeRemove = p;
    p = move.change(p, RemoveDissolve(tid));
    final afterRemove = p;
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
      beforeRemove.toJson()..remove('revision'),
      afterRemove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expectRestoredDissolve(restored, a);
    expect(startOf(restored, a), Q.of(0));
    expect(startOf(restored, 'right'), Q.of(1));
    expect(seqDur(restored), Q.of(3));
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

  test('a later SetDissolve of the same pair after removal is not a write-set conflict and invert then refuses TRANSITION_WINDOW_OVERLAP', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    p = move.change(p, firstDissolve(a));
    final tid = dissolveOf(p)!['id'] as String;
    final beforeRemove = p;
    p = move.change(p, RemoveDissolve(tid));
    final afterRemove = p;
    expect(p.toJson()['transitions'], isEmpty);
    p = move.change(p, SetDissolve(a, 'right', Q.of(3, 10), Q.of(3, 10)));
    expect(Q.fromJson(dissolveOf(p)!['before']), Q.of(3, 10));
    expect(Q.fromJson(dissolveOf(p)!['after']), Q.of(3, 10));
    final changes = documentFieldChanges(
      beforeRemove.toJson()..remove('revision'),
      afterRemove.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    assertPure(p, () {
      expect(
        () => ProjectDocument.fromJson(
          applyFieldInvert(p.toJson(), changes)
            ..['revision'] = p.revision.toString(),
        ),
        code('TRANSITION_WINDOW_OVERLAP'),
      );
    });
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, 'right'), Q.of(1));
    expect(clipCount(p), 2);
    expect(Q.fromJson(dissolveOf(p)!['before']), Q.of(3, 10));
    expect(Q.fromJson(dissolveOf(p)!['after']), Q.of(3, 10));
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });
}
