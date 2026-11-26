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

ProjectDocument firstSplitWithCues() {
  var p = avFixture();
  final a = algebra.firstId(p);
  p = move.change(p, SplitClip(a, Q.of(2), 'right'));
  return attachDefaults(p, [
    CaptionCue(
      'cue-left',
      TimeRange(Q.of(0), Q.of(1, 2)),
      'hello',
      manualFields: {'text', 'timing'},
    ),
    CaptionCue(
      'cue-right',
      TimeRange(Q.of(5, 2), Q.of(1, 2)),
      'stay',
      manualFields: {'text', 'timing'},
    ),
  ]);
}

void main() {
  test('inverting split after a later leave-gap move of an uninvolved remnant keeps moved cues', () {
    var p = firstSplitWithCues();
    final a = algebra.firstId(p);
    expect(startOf(p, a), Q.of(0));
    expect(durationOf(p, a), Q.of(2));
    expect(startOf(p, 'right'), Q.of(2));
    final beforeSplit = p;
    p = move.change(p, SplitClip(a, Q.of(1), 'mid'));
    final afterSplit = p;
    expect(clipCount(p), 3);
    expect(durationOf(p, a), Q.of(1));
    expect(startOf(p, 'mid'), Q.of(1));
    p = move.change(p, MoveClips(['right'], Q.of(1)));
    expect(startOf(p, 'right'), Q.of(3));
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(7, 2),
    );
    final changes = documentFieldChanges(
      beforeSplit.toJson()..remove('revision'),
      afterSplit.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(clipCount(restored), 2);
    expect(() => clipOf(restored, 'mid'), throwsStateError);
    expect(startOf(restored, a), Q.of(0));
    expect(durationOf(restored, a), Q.of(2));
    expect(startOf(restored, 'right'), Q.of(3));
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(7, 2),
    );
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
  });

  test('a later leave-gap move of a split remnant conflicts with invert', () {
    var p = firstSplitWithCues();
    final a = algebra.firstId(p);
    final beforeSplit = p;
    p = move.change(p, SplitClip(a, Q.of(1), 'mid'));
    final afterSplit = p;
    p = move.change(p, MoveClips(['mid'], Q.of(2)));
    expect(startOf(p, 'mid'), Q.of(3));
    final changes = documentFieldChanges(
      beforeSplit.toJson()..remove('revision'),
      afterSplit.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(clipCount(p), 3);
    expect(startOf(p, 'mid'), Q.of(3));
    expect(cueOf(p, 'cue-left')['text'], 'hello');
  });

  test('inverting split after an unrelated marker edit leaves markers and unmoved cues', () {
    var p = firstSplitWithCues();
    final a = algebra.firstId(p);
    final beforeSplit = p;
    p = move.change(p, SplitClip(a, Q.of(1), 'mid'));
    final afterSplit = p;
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
    final changes = documentFieldChanges(
      beforeSplit.toJson()..remove('revision'),
      afterSplit.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(clipCount(restored), 2);
    expect(() => clipOf(restored, 'mid'), throwsStateError);
    expect(durationOf(restored, a), Q.of(2));
    expect(startOf(restored, 'right'), Q.of(2));
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
  });

  test('a later out-trim of the left remnant that changes the recorded duration numerator conflicts with invert', () {
    var p = firstSplitWithCues();
    final a = algebra.firstId(p);
    final beforeSplit = p;
    p = move.change(p, SplitClip(a, Q.of(1), 'mid'));
    final afterSplit = p;
    p = move.change(p, TrimClip(a, 'out', Q.of(-1, 30)));
    expect(durationOf(p, a), Q.of(29, 30));
    final changes = documentFieldChanges(
      beforeSplit.toJson()..remove('revision'),
      afterSplit.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(clipCount(p), 3);
    expect(durationOf(p, a), Q.of(29, 30));
    expect(cueOf(p, 'cue-left')['text'], 'hello');
  });
}
