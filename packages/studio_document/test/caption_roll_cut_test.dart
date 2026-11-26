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

Q sourceStartOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['start']);

Q sourceDurationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['duration']);

Map cueOf(ProjectDocument p, String id) => (p.toJson()['captions'] as List)
    .cast<Map>()
    .singleWhere((c) => c['id'] == id);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

Map timeMapOf(ProjectDocument p, String id) =>
    Map<String, dynamic>.from(clipOf(p, id)['timeMap'] as Map);

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

/// +15 frames at 30fps, moving the 1s cut to 1.5s.
final rollDelta = Q.of(1, 2);

void expectSplit(ProjectDocument p, String a) {
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(1));
  expect(sourceStartOf(p, a), Q.of(0));
  expect(sourceDurationOf(p, a), Q.of(1));
  expect(startOf(p, 'right'), Q.of(1));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(sourceStartOf(p, 'right'), Q.of(1));
  expect(sourceDurationOf(p, 'right'), Q.of(2));
  expect(seqDur(p), Q.of(3));
}

void expectRolled(ProjectDocument p, String a) {
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(3, 2));
  expect(sourceStartOf(p, a), Q.of(0));
  expect(sourceDurationOf(p, a), Q.of(3, 2));
  expect(startOf(p, 'right'), Q.of(3, 2));
  expect(durationOf(p, 'right'), Q.of(3, 2));
  expect(sourceStartOf(p, 'right'), Q.of(3, 2));
  expect(sourceDurationOf(p, 'right'), Q.of(3, 2));
  expect(seqDur(p), Q.of(3));
}

void main() {
  test('roll of a packed 1s cut by +15 frames keeps outer ends and follows the right clipLocal cue', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    expectSplit(p, a);
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    final leftMap = timeMapOf(p, a);
    final rightMap = timeMapOf(p, 'right');
    p = move.change(p, RollCut(a, 'right', rollDelta));
    expectRolled(p, a);
    expect(timeMapOf(p, a), leftMap);
    expect(timeMapOf(p, 'right'), rightMap);
    expect(cueOf(p, 'cue-left')['text'], 'hello');
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-right')['text'], 'stay');
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(2),
    );
  });

  test('an absolute cue stays at author time when the cut is rolled', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-left')),
    );
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-right')),
    );
    p = move.change(p, SetCaptions(CaptionStore([hello, stay.makeAbsolute()])));
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'absolute');
    p = move.change(p, RollCut(a, 'right', rollDelta));
    expectRolled(p, a);
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'absolute');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });

  test('a source-anchored cue on the right reprojects while a third remnant stays put', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = move.change(p, SplitClip('right', Q.of(2), 'tail'));
    final host = clipOf(p, 'right');
    final sourceCue =
        CaptionCue(
          'cue-src',
          TimeRange(Q.of(7, 4), Q.of(1, 8)),
          'src',
          manualFields: {'text', 'timing'},
        ).anchoredToSource(
          clipId: 'right',
          clipStart: Q.fromJson(host['timelineRange']['start']),
          clipDuration: Q.fromJson(host['timelineRange']['duration']),
          sourceDuration: Q.fromJson(host['sourceRange']['duration']),
          rate: Q.fromJson(host['timeMap']['rate']),
        );
    p = move.change(p, SetCaptions(CaptionStore([sourceCue])));
    expect(startOf(p, 'tail'), Q.of(2));
    expect(durationOf(p, 'tail'), Q.of(1));
    expect(sourceStartOf(p, 'tail'), Q.of(2));
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['start']),
      Q.of(7, 4),
    );
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['anchor']['range']['start']),
      Q.of(3, 4),
    );
    p = move.change(p, RollCut(a, 'right', rollDelta));
    expect(startOf(p, a), Q.of(0));
    expect(durationOf(p, a), Q.of(3, 2));
    expect(startOf(p, 'right'), Q.of(3, 2));
    expect(durationOf(p, 'right'), Q.of(1, 2));
    expect(sourceStartOf(p, 'right'), Q.of(3, 2));
    expect(sourceDurationOf(p, 'right'), Q.of(1, 2));
    expect(startOf(p, 'tail'), Q.of(2));
    expect(durationOf(p, 'tail'), Q.of(1));
    expect(sourceStartOf(p, 'tail'), Q.of(2));
    expect(seqDur(p), Q.of(3));
    expect(cueOf(p, 'cue-src')['anchor']['kind'], 'source');
    expect(cueOf(p, 'cue-src')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['anchor']['range']['start']),
      Q.of(1, 4),
    );
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['start']),
      Q.of(7, 4),
    );
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['duration']),
      Q.of(1, 8),
    );
  });

  test(
    'uncovering a source-anchored cue or a non-adjacent cut refuses wholly',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = move.change(p, SplitClip(a, Q.of(1), 'right'));
      final host = clipOf(p, 'right');
      final sourceCue =
          CaptionCue(
            'cue-src',
            TimeRange(Q.of(5, 4), Q.of(1, 2)),
            'src',
            manualFields: {'text', 'timing'},
          ).anchoredToSource(
            clipId: 'right',
            clipStart: Q.fromJson(host['timelineRange']['start']),
            clipDuration: Q.fromJson(host['timelineRange']['duration']),
            sourceDuration: Q.fromJson(host['sourceRange']['duration']),
            rate: Q.fromJson(host['timeMap']['rate']),
          );
      p = move.change(p, SetCaptions(CaptionStore([sourceCue])));
      assertPure(p, () {
        expect(
          () => move.change(p, RollCut(a, 'right', rollDelta)),
          code('ANCHOR_OUT_OF_RANGE'),
        );
      });
      expect(startOf(p, 'right'), Q.of(1));
      expect(sourceStartOf(p, 'right'), Q.of(1));

      var packed = splitWithCues();
      final left = algebra.firstId(packed);
      packed = move.change(packed, MoveClip('right', Q.of(1)));
      assertPure(packed, () {
        expect(
          () => move.change(packed, RollCut(left, 'right', rollDelta)),
          code('NOT_ADJACENT'),
        );
      });
    },
  );

  test('source exhaustion or a locked sourceRange refuses the whole roll', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    // Exhaust later source on the left, then a further roll cannot grow it.
    p = move.change(p, SlipClip(a, Q.of(2)));
    expect(sourceStartOf(p, a), Q.of(2));
    assertPure(p, () {
      expect(
        () => move.change(p, RollCut(a, 'right', Q.of(1, 30))),
        code('SOURCE_OUT_OF_RANGE'),
      );
    });
    expect(durationOf(p, a), Q.of(1));
    expect(startOf(p, 'right'), Q.of(1));

    var lockedDoc = splitWithCues();
    final left = algebra.firstId(lockedDoc);
    final d = lockedDoc.toJson();
    for (final t in d['sequences'][0]['tracks'] as List) {
      for (final item in t['items'] as List) {
        if (item['id'] == left) {
          item['lockedFields'] = ['sourceRange'];
        }
      }
    }
    final locked = ProjectDocument.fromJson(d);
    assertPure(locked, () {
      expect(
        () => move.change(locked, RollCut(left, 'right', rollDelta)),
        code('FIELD_LOCKED'),
      );
    });
    expect(durationOf(locked, left), Q.of(1));
    expect(startOf(locked, 'right'), Q.of(1));
  });

  test('linked AV roll with captions uses each member source rate and follows the right cue', () {
    var p = avFixture();
    final video = algebra.firstId(p);
    p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
    p = move.change(p, SplitClip(video, Q.of(1), 'right'));
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
    final audioLeft =
        media(p).singleWhere(
              (c) =>
                  c['id'] != video &&
                  c['id'] != 'right' &&
                  startOf(p, c['id'] as String) == Q.of(0),
            )['id']
            as String;
    final audioRight =
        media(p).singleWhere(
              (c) =>
                  c['id'] != video &&
                  c['id'] != 'right' &&
                  c['id'] != audioLeft &&
                  startOf(p, c['id'] as String) == Q.of(1),
            )['id']
            as String;
    expect(clipOf(p, audioLeft)['linkGroupId'], isNotNull);
    expect(
      clipOf(p, video)['linkGroupId'],
      clipOf(p, audioLeft)['linkGroupId'],
    );
    final leftRate = Q.fromJson(clipOf(p, audioLeft)['timeMap']['rate']);
    final rightRate = Q.fromJson(clipOf(p, audioRight)['timeMap']['rate']);
    final audioLeftSrc = sourceStartOf(p, audioLeft);
    final audioLeftSrcDur = sourceDurationOf(p, audioLeft);
    final audioRightSrc = sourceStartOf(p, audioRight);
    p = move.change(p, RollCut(video, 'right', rollDelta));
    expect(startOf(p, video), Q.of(0));
    expect(durationOf(p, video), Q.of(3, 2));
    expect(sourceDurationOf(p, video), Q.of(3, 2));
    expect(startOf(p, 'right'), Q.of(3, 2));
    expect(durationOf(p, 'right'), Q.of(3, 2));
    expect(startOf(p, audioLeft), Q.of(0));
    expect(durationOf(p, audioLeft), Q.of(3, 2));
    expect(sourceStartOf(p, audioLeft), audioLeftSrc);
    expect(
      sourceDurationOf(p, audioLeft),
      audioLeftSrcDur + leftRate * rollDelta,
    );
    expect(startOf(p, audioRight), Q.of(3, 2));
    expect(durationOf(p, audioRight), Q.of(3, 2));
    expect(sourceStartOf(p, audioRight), audioRightSrc + rightRate * rollDelta);
    expect(seqDur(p), Q.of(3));
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(2),
    );
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
  });
}
