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

ProjectDocument extractSplitCues() {
  var p = avFixture();
  final a = algebra.firstId(p);
  p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
  p = move.change(p, SplitClip(a, Q.of(1), 'right'));
  return withCues(p);
}

String groupOf(ProjectDocument p, String clipId) =>
    clipOf(p, clipId)['linkGroupId'] as String;

int groupCount(ProjectDocument p) => (p.toJson()['linkGroups'] as List).length;

void main() {
  test('inverting an unlink after a later aligned leave-gap move keeps moved cues and restores the link', () {
    var p = extractSplitCues();
    final a = algebra.firstId(p);
    expect(groupCount(p), 2);
    final gid = groupOf(p, 'right');
    final audioId =
        media(p).singleWhere(
              (c) => c['id'] != 'right' && c['linkGroupId'] == gid,
            )['id']
            as String;
    final beforeUnlink = p;
    p = move.change(p, UnlinkAudioVideo(gid));
    final afterUnlink = p;
    expect(groupCount(p), 1);
    expect(clipOf(p, 'right')['linkGroupId'], isNull);
    p = move.change(p, MoveClips(['right', audioId], Q.of(1)));
    expect(startOf(p, 'right'), Q.of(2));
    expect(startOf(p, audioId), Q.of(2));
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
    final changes = documentFieldChanges(
      beforeUnlink.toJson()..remove('revision'),
      afterUnlink.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(groupCount(restored), 2);
    expect(clipOf(restored, 'right')['linkGroupId'], isNotNull);
    expect(startOf(restored, a), Q.of(0));
    expect(startOf(restored, 'right'), Q.of(2));
    expect(startOf(restored, audioId), Q.of(2));
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

  test('a later relink conflicts with invert of the original unlink', () {
    var p = extractSplitCues();
    final gid = groupOf(p, 'right');
    final audioId =
        media(p).singleWhere(
              (c) => c['id'] != 'right' && c['linkGroupId'] == gid,
            )['id']
            as String;
    final beforeUnlink = p;
    p = move.change(p, UnlinkAudioVideo(gid));
    final afterUnlink = p;
    p = move.change(p, LinkAudioVideo('right', audioId));
    expect(groupCount(p), 2);
    final changes = documentFieldChanges(
      beforeUnlink.toJson()..remove('revision'),
      afterUnlink.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isTrue);
    assertPure(p, () {
      expect(
        () => applyFieldInvert(p.toJson(), changes),
        code('UNDO_CONFLICT'),
      );
    });
    expect(clipOf(p, 'right')['linkGroupId'], isNotNull);
    expect(cueOf(p, 'cue-left')['text'], 'hello');
  });

  test('inverting an unlink after an unrelated marker edit leaves markers and unmoved cues', () {
    var p = extractSplitCues();
    final a = algebra.firstId(p);
    final gid = groupOf(p, 'right');
    final beforeUnlink = p;
    p = move.change(p, UnlinkAudioVideo(gid));
    final afterUnlink = p;
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
      beforeUnlink.toJson()..remove('revision'),
      afterUnlink.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final restored = ProjectDocument.fromJson(
      applyFieldInvert(p.toJson(), changes)
        ..['revision'] = p.revision.toString(),
    );
    expect(groupCount(restored), 2);
    expect(clipOf(restored, 'right')['linkGroupId'], isNotNull);
    expect(startOf(restored, a), Q.of(0));
    expect(startOf(restored, 'right'), Q.of(1));
    expect(
      Q.fromJson(cueOf(restored, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
    expect((restored.toJson()['markers'] as List).single['label'], 'later');
    expect(cueOf(restored, 'cue-right')['text'], 'stay');
  });

  test(
    'inverting a relink after a later leave-gap move restores the unlink only',
    () {
      var p = extractSplitCues();
      final a = algebra.firstId(p);
      final gid = groupOf(p, 'right');
      final audioId =
          media(p).singleWhere(
                (c) => c['id'] != 'right' && c['linkGroupId'] == gid,
              )['id']
              as String;
      p = move.change(p, UnlinkAudioVideo(gid));
      final beforeLink = p;
      p = move.change(p, LinkAudioVideo('right', audioId));
      final afterLink = p;
      p = move.change(p, MoveClips(['right'], Q.of(1)));
      expect(startOf(p, 'right'), Q.of(2));
      // Linked move also translates the audio remnant.
      expect(startOf(p, audioId), Q.of(2));
      final changes = documentFieldChanges(
        beforeLink.toJson()..remove('revision'),
        afterLink.toJson()..remove('revision'),
      );
      expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
      final restored = ProjectDocument.fromJson(
        applyFieldInvert(p.toJson(), changes)
          ..['revision'] = p.revision.toString(),
      );
      expect(clipOf(restored, 'right')['linkGroupId'], isNull);
      expect(groupCount(restored), 1);
      expect(startOf(restored, a), Q.of(0));
      expect(startOf(restored, 'right'), Q.of(2));
      expect(startOf(restored, audioId), Q.of(2));
      expect(
        Q.fromJson(cueOf(restored, 'cue-right')['timelineRange']['start']),
        Q.of(5, 2),
      );
      expect(cueOf(restored, 'cue-left')['text'], 'hello');
    },
  );

  test('inverting an unlink after a diverging move is refused as LINK_OFFSET_MISMATCH', () {
    var p = extractSplitCues();
    final gid = groupOf(p, 'right');
    final beforeUnlink = p;
    p = move.change(p, UnlinkAudioVideo(gid));
    final afterUnlink = p;
    p = move.change(p, MoveClips(['right'], Q.of(1)));
    expect(startOf(p, 'right'), Q.of(2));
    final changes = documentFieldChanges(
      beforeUnlink.toJson()..remove('revision'),
      afterUnlink.toJson()..remove('revision'),
    );
    expect(fieldInvertConflicts(p.toJson(), changes), isFalse);
    final inverted = applyFieldInvert(p.toJson(), changes);
    assertPure(p, () {
      expect(
        () => ProjectDocument.fromJson(
          inverted..['revision'] = p.revision.toString(),
        ),
        code('LINK_OFFSET_MISMATCH'),
      );
    });
    expect(clipOf(p, 'right')['linkGroupId'], isNull);
    expect(startOf(p, 'right'), Q.of(2));
    expect(cueOf(p, 'cue-right')['text'], 'stay');
  });
}
