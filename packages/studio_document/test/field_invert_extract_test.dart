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

Map cueOf(ProjectDocument p, String id) => (p.toJson()['captions'] as List)
    .cast<Map>()
    .singleWhere((c) => c['id'] == id);

Map? trackOf(ProjectDocument p, String kind) {
  final matches = (p.toJson()['sequences'][0]['tracks'] as List)
      .cast<Map>()
      .where((t) => t['kind'] == kind)
      .toList();
  if (matches.isEmpty) return null;
  return matches.single;
}

int groupCount(ProjectDocument p) => (p.toJson()['linkGroups'] as List).length;

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

ProjectDocument withCues(ProjectDocument p) => attachDefaults(p, [
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

ProjectDocument splitCues() {
  var p = avFixture();
  final a = algebra.firstId(p);
  p = move.change(p, SplitClip(a, Q.of(1), 'right'));
  return withCues(p);
}

void main() {
  test('inverting extract after a later leave-gap move of an uninvolved remnant keeps moved cues', () {
    var p = splitCues();
    final a = algebra.firstId(p);
    expect(trackOf(p, 'audio'), isNull);
    final beforeExtract = p;
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    final afterExtract = p;
    expect(trackOf(p, 'audio'), isNotNull);
    expect(groupCount(p), 1);
    p = move.change(p, MoveClips(['right'], Q.of(1)));
    expect(startOf(p, 'right'), Q.of(2));
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
    final changes = documentFieldChanges(
      beforeExtract.toJson()..remove('revision'),
      afterExtract.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(trackOf(restored, 'audio'), isNull);
    expect(groupCount(restored), 0);
    expect(clipOf(restored, a)['linkGroupId'], isNull);
    expect(startOf(restored, a), Q.of(0));
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
  });

  test('a later linked move of the extracted host conflicts with invert', () {
    var p = splitCues();
    final beforeExtract = p;
    p = move.change(p, ExtractAudioClip('right', 'audio-stream'));
    final afterExtract = p;
    p = move.change(p, MoveClips(['right'], Q.of(1)));
    expect(startOf(p, 'right'), Q.of(2));
    final changes = documentFieldChanges(
      beforeExtract.toJson()..remove('revision'),
      afterExtract.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(trackOf(p, 'audio'), isNotNull);
    expect(groupCount(p), 1);
    expect(cueOf(p, 'cue-left')['text'], 'hello');
  });

  test('inverting extract after an unrelated marker edit leaves markers and unmoved cues', () {
    var p = splitCues();
    final a = algebra.firstId(p);
    final beforeExtract = p;
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    final afterExtract = p;
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
      beforeExtract.toJson()..remove('revision'),
      afterExtract.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(trackOf(restored, 'audio'), isNull);
    expect(groupCount(restored), 0);
    expect(startOf(restored, a), Q.of(0));
    expect(startOf(restored, 'right'), Q.of(1));
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
  });

  test('a later mute of the extracted audio track conflicts with invert', () {
    var p = splitCues();
    final a = algebra.firstId(p);
    final beforeExtract = p;
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    final afterExtract = p;
    final audio = trackOf(p, 'audio')!['id'] as String;
    p = move.change(p, SetAudioTrackState(audio, muted: true, solo: false));
    final changes = documentFieldChanges(
      beforeExtract.toJson()..remove('revision'),
      afterExtract.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(trackOf(p, 'audio')!['muted'], isTrue);
    expect(cueOf(p, 'cue-left')['text'], 'hello');
  });
}
