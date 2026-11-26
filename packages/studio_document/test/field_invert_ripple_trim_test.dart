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

void main() {
  test('inverting ripple out-trim after an unrelated marker edit leaves markers and unmoved cues', () {
    var p = splitWithCues();
    expect(startOf(p, 'right'), Q.of(1));
    expect(durationOf(p, 'right'), Q.of(2));
    final beforeTrim = p;
    p = move.change(p, RippleTrimClip('right', 'out', Q.of(-1, 2)));
    final afterTrim = p;
    expect(durationOf(p, 'right'), Q.of(3, 2));
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
      beforeTrim.toJson()..remove('revision'),
      afterTrim.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(startOf(restored, 'right'), Q.of(1));
    expect(durationOf(restored, 'right'), Q.of(2));
    expect(startOf(restored, algebra.firstId(restored)), Q.of(0));
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
  });

  test('a later out-trim that changes the recorded duration numerator conflicts with invert', () {
    var p = splitWithCues();
    final beforeTrim = p;
    p = move.change(p, RippleTrimClip('right', 'out', Q.of(-1, 2)));
    final afterTrim = p;
    p = move.change(p, RippleTrimClip('right', 'out', Q.of(-1, 2)));
    expect(durationOf(p, 'right'), Q.of(1));
    final changes = documentFieldChanges(
      beforeTrim.toJson()..remove('revision'),
      afterTrim.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(durationOf(p, 'right'), Q.of(1));
    expect(cueOf(p, 'cue-left')['text'], 'hello');
  });

  test('inverting ripple out-trim of a left remnant after a later marker edit leaves shifted right cues unmoved by invert', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforeTrim = p;
    p = move.change(p, RippleTrimClip(a, 'out', Q.of(-1, 2)));
    final afterTrim = p;
    expect(durationOf(p, a), Q.of(1, 2));
    expect(startOf(p, 'right'), Q.of(1, 2));
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(1),
    );
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
      beforeTrim.toJson()..remove('revision'),
      afterTrim.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(durationOf(restored, a), Q.of(1));
    expect(startOf(restored, 'right'), Q.of(1));
    expect(
      Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
  });

  test('a later leave-gap move of a remnant shifted by the ripple trim conflicts with invert', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforeTrim = p;
    p = move.change(p, RippleTrimClip(a, 'out', Q.of(-1, 2)));
    final afterTrim = p;
    expect(startOf(p, 'right'), Q.of(1, 2));
    p = move.change(p, MoveClips(['right'], Q.of(1)));
    expect(startOf(p, 'right'), Q.of(3, 2));
    final changes = documentFieldChanges(
      beforeTrim.toJson()..remove('revision'),
      afterTrim.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(startOf(p, 'right'), Q.of(3, 2));
    expect(durationOf(p, a), Q.of(1, 2));
    expect(cueOf(p, 'cue-left')['text'], 'hello');
  });
}
