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

String pastedId(ProjectDocument p, String a, String right) =>
    media(p).singleWhere((c) => c['id'] != a && c['id'] != right)['id'] as String;

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
      'cue-hole',
      TimeRange(Q.of(1), Q.of(1, 2)),
      'carved',
      manualFields: {'text', 'timing'},
    ),
    CaptionCue(
      'cue-later',
      TimeRange(Q.of(2), Q.of(1, 5)),
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
        time: Q.of(5, 2),
      ),
    ]),
  ),
);

PasteClips overwritePaste(ProjectDocument p, String a) =>
    PasteClips(buildClipboard(p, [a]), at: Q.of(1), mode: 'overwrite');

void main() {
  test('inverting an overwrite PasteClips after a later marker edit restores the carved dest and rebinds leftover cues', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, 'right'), Q.of(1));
    expect(durationOf(p, 'right'), Q.of(2));
    expect(seqDur(p), Q.of(3));
    expect(cueOf(p, 'cue-hole')['anchor']['clipId'], 'right');
    final beforePaste = p;
    p = move.change(p, overwritePaste(p, a));
    final afterPaste = p;
    final pasted = pastedId(p, a, 'right');
    expect(clipCount(p), 3);
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, pasted), Q.of(1));
    expect(durationOf(p, pasted), Q.of(1));
    expect(startOf(p, 'right'), Q.of(2));
    expect(durationOf(p, 'right'), Q.of(1));
    expect(seqDur(p), Q.of(3));
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cueOf(p, 'cue-hole')['text'], 'carved');
    expect(cueOf(p, 'cue-hole')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-hole')['anchor']['clipId'], pasted);
    expect(
      Q.fromJson(cueOf(p, 'cue-hole')['timelineRange']['start']),
      Q.of(1),
    );
    expect(cueOf(p, 'cue-later')['text'], 'stay');
    expect(cueOf(p, 'cue-later')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-later')['timelineRange']['start']),
      Q.of(2),
    );
    p = afterMarkers(p);
    final changes = documentFieldChanges(
      beforePaste.toJson()..remove('revision'),
      afterPaste.toJson()..remove('revision'),
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
    expect(seqDur(restored), Q.of(3));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect(cueOf(restored, 'cue-hole')['text'], 'carved');
    expect(cueOf(restored, 'cue-hole')['anchor']['kind'], 'clipLocal');
    expect(cueOf(restored, 'cue-hole')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(restored, 'cue-hole')['timelineRange']['start']),
      Q.of(1),
    );
    expect(cueOf(restored, 'cue-later')['text'], 'stay');
    expect(cueOf(restored, 'cue-later')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(restored, 'cue-later')['timelineRange']['start']),
      Q.of(2),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
  });

  test('inverting an overwrite PasteClips after a later text edit of the leftover carved cue keeps the new text', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforePaste = p;
    p = move.change(p, overwritePaste(p, a));
    final afterPaste = p;
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-left')),
    );
    final carved = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-hole')),
    );
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-later')),
    );
    p = move.change(
      p,
      SetCaptions(CaptionStore([hello, carved.editText('revised'), stay])),
    );
    final changes = documentFieldChanges(
      beforePaste.toJson()..remove('revision'),
      afterPaste.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(clipCount(restored), 2);
    expect(startOf(restored, 'right'), Q.of(1));
    expect(durationOf(restored, 'right'), Q.of(2));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-hole')['text'], 'revised');
    expect(cueOf(restored, 'cue-hole')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(restored, 'cue-hole')['timelineRange']['start']),
      Q.of(1),
    );
    expect(cueOf(restored, 'cue-later')['text'], 'stay');
  });

  test('inverting an overwrite PasteClips after a later text edit of the unmoved stay cue keeps the new text', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforePaste = p;
    p = move.change(p, overwritePaste(p, a));
    final afterPaste = p;
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-left')),
    );
    final carved = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-hole')),
    );
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-later')),
    );
    p = move.change(
      p,
      SetCaptions(CaptionStore([hello, carved, stay.editText('revised-stay')])),
    );
    final changes = documentFieldChanges(
      beforePaste.toJson()..remove('revision'),
      afterPaste.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(startOf(restored, algebra.firstId(restored)), Q.of(0));
    expect(startOf(restored, 'right'), Q.of(1));
    expect(cueOf(restored, 'cue-left')['text'], 'hello');
    expect(cueOf(restored, 'cue-hole')['text'], 'carved');
    expect(cueOf(restored, 'cue-later')['text'], 'revised-stay');
    expect(
      Q.fromJson(cueOf(restored, 'cue-later')['timelineRange']['start']),
      Q.of(2),
    );
    expect(cueOf(restored, 'cue-later')['anchor']['clipId'], 'right');
  });

  test('a later leave-gap move of the carved dest remnant conflicts with invert', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final beforePaste = p;
    p = move.change(p, overwritePaste(p, a));
    final afterPaste = p;
    expect(startOf(p, 'right'), Q.of(2));
    expect(durationOf(p, 'right'), Q.of(1));
    // A later leave-gap out-trim of right can change unrecorded sourceRange
    // canonicity without being seen as a write-set conflict; official conflict
    // is a later leave-gap move that changes the recorded dest start.
    p = move.change(p, MoveClip('right', Q.of(1)));
    expect(startOf(p, 'right'), Q.of(3));
    expect(startOf(p, a), Q.of(0));
    final changes = documentFieldChanges(
      beforePaste.toJson()..remove('revision'),
      afterPaste.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, 'right'), Q.of(3));
    expect(durationOf(p, 'right'), Q.of(1));
    expect(clipCount(p), 3);
    expect(
      Q.fromJson(cueOf(p, 'cue-later')['timelineRange']['start']),
      Q.of(3),
    );
  });
}
