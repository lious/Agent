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

CaptionCue toSource(ProjectDocument p, CaptionCue cue, String clipId) {
  final host = clipOf(p, clipId);
  return cue.anchoredToSource(
    clipId: clipId,
    clipStart: Q.fromJson(host['timelineRange']['start']),
    clipDuration: Q.fromJson(host['timelineRange']['duration']),
    sourceDuration: Q.fromJson(host['sourceRange']['duration']),
    rate: Q.fromJson(host['timeMap']['rate']),
  );
}

TimelineMarker absolute(
  ProjectDocument p,
  String id, {
  required Q time,
  String label = 'mark',
}) => TimelineMarker(
  id,
  sequenceId: p.toJson()['rootSequenceId'] as String,
  label: label,
  time: time,
);

void main() {
  test(
    'grouping does not retarget cues; a group move follows both clipLocal cues',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = move.change(p, SplitClip(a, Q.of(1), 'right'));
      p = attachDefaults(p, [
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
      expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
      expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
      expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
      expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
      final before = content(p);
      p = move.change(p, GroupClips([a, 'right']));
      expect(p.toJson()['selectionGroups'], hasLength(1));
      expect(
        Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']),
        Q.of(0),
      );
      expect(
        Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
        Q.of(3, 2),
      );
      expect(cueOf(p, 'cue-left')['text'], 'hello');
      expect(cueOf(p, 'cue-right')['text'], 'stay');
      expect(content(p) == before, isFalse);
      p = move.change(p, MoveClips([a], Q.of(1)));
      expect(startOf(p, a), Q.of(1));
      expect(startOf(p, 'right'), Q.of(2));
      expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
      expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
      expect(
        Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']),
        Q.of(1),
      );
      expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
      expect(
        Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
        Q.of(5, 2),
      );
    },
  );

  test('ungroup then moving one member leaves the other cue in place', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = attachDefaults(p, [
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
    p = move.change(p, GroupClips([a, 'right']));
    p = move.change(p, MoveClips([a], Q.of(1)));
    final gid = (p.toJson()['selectionGroups'] as List).single['id'] as String;
    p = move.change(p, UngroupClips([gid]));
    expect(p.toJson()['selectionGroups'], isEmpty);
    p = move.change(p, MoveClips(['right'], Q.of(1)));
    expect(startOf(p, a), Q.of(1));
    expect(startOf(p, 'right'), Q.of(3));
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(1));
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(7, 2),
    );
    expect(cueOf(p, 'cue-left')['text'], 'hello');
    expect(cueOf(p, 'cue-right')['text'], 'stay');
  });

  test('an ungrouped half-step collides; a grouped half-step moves both cues together', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = attachDefaults(p, [
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
    assertPure(p, () {
      expect(
        () => move.change(p, MoveClips([a], Q.of(1, 2))),
        code('COLLISION'),
      );
    });
    p = move.change(p, GroupClips([a, 'right']));
    p = move.change(p, MoveClips([a], Q.of(1, 2)));
    expect(startOf(p, a), Q.of(1, 2));
    expect(startOf(p, 'right'), Q.of(3, 2));
    expect(
      Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']),
      Q.of(1, 2),
    );
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(2),
    );
  });

  test('includeLinks=false after grouping moves only the explicit member and its cue', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = attachDefaults(p, [
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
    p = move.change(p, GroupClips([a, 'right']));
    p = move.change(p, MoveClips([a], Q.of(1)));
    p = move.change(p, MoveClips(['right'], Q.of(1), includeLinks: false));
    expect(startOf(p, a), Q.of(1));
    expect(startOf(p, 'right'), Q.of(3));
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(1));
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(7, 2),
    );
    expect(p.toJson()['selectionGroups'], hasLength(1));
  });

  test('source cues reproject on a group move; lifting a clipLocal-marker host still refuses', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = attachDefaults(p, [
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
    final sourced = toSource(
      p,
      CaptionCue.fromProjectJson(
        Map<String, dynamic>.from(cueOf(p, 'cue-left')),
      ),
      a,
    );
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          sourced,
          CaptionCue.fromProjectJson(
            Map<String, dynamic>.from(cueOf(p, 'cue-right')),
          ),
        ]),
      ),
    );
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'source');
    p = move.change(
      p,
      SetMarkers(
        MarkerStore([
          absolute(p, 'follow', time: Q.of(1, 4)).anchoredToClip(
            a,
            startOf(p, a),
            Q.fromJson(clipOf(p, a)['timelineRange']['duration']),
          ),
        ]),
      ),
    );
    p = move.change(p, GroupClips([a, 'right']));
    p = move.change(p, MoveClips([a], Q.of(1)));
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'source');
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(1));
    expect(cueOf(p, 'cue-left')['text'], 'hello');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
    expect(
      Q.fromJson((p.toJson()['markers'] as List).single['time']),
      Q.of(5, 4),
    );
    assertPure(p, () {
      expect(() => move.change(p, LiftClips([a])), code('REF_NOT_FOUND'));
    });
  });
}
