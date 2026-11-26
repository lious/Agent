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

ProjectDocument splitTripleWithCues() {
  var p = avFixture();
  final a = algebra.firstId(p);
  p = move.change(p, SplitClip(a, Q.of(1), 'mid'));
  p = move.change(p, SplitClip('mid', Q.of(2), 'right'));
  return attachDefaults(p, [
    CaptionCue(
      'cue-left',
      TimeRange(Q.of(0), Q.of(1, 2)),
      'hello',
      manualFields: {'text', 'timing'},
    ),
    CaptionCue(
      'cue-mid',
      TimeRange(Q.of(1), Q.of(1, 2)),
      'there',
      manualFields: {'text', 'timing'},
    ),
    CaptionCue(
      'cue-right',
      TimeRange(Q.of(2), Q.of(1, 2)),
      'stay',
      manualFields: {'text', 'timing'},
    ),
  ]);
}

/// +15 frames at 30fps, sliding the middle remnant by 0.5s.
final slideDelta = Q.of(1, 2);

void expectTriple(ProjectDocument p, String a) {
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(1));
  expect(sourceStartOf(p, a), Q.of(0));
  expect(sourceDurationOf(p, a), Q.of(1));
  expect(startOf(p, 'mid'), Q.of(1));
  expect(durationOf(p, 'mid'), Q.of(1));
  expect(sourceStartOf(p, 'mid'), Q.of(1));
  expect(sourceDurationOf(p, 'mid'), Q.of(1));
  expect(startOf(p, 'right'), Q.of(2));
  expect(durationOf(p, 'right'), Q.of(1));
  expect(sourceStartOf(p, 'right'), Q.of(2));
  expect(sourceDurationOf(p, 'right'), Q.of(1));
  expect(seqDur(p), Q.of(3));
}

void expectSlid(ProjectDocument p, String a) {
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(3, 2));
  expect(sourceStartOf(p, a), Q.of(0));
  expect(sourceDurationOf(p, a), Q.of(3, 2));
  expect(startOf(p, 'mid'), Q.of(3, 2));
  expect(durationOf(p, 'mid'), Q.of(1));
  expect(sourceStartOf(p, 'mid'), Q.of(1));
  expect(sourceDurationOf(p, 'mid'), Q.of(1));
  expect(startOf(p, 'right'), Q.of(5, 2));
  expect(durationOf(p, 'right'), Q.of(1, 2));
  expect(sourceStartOf(p, 'right'), Q.of(5, 2));
  expect(sourceDurationOf(p, 'right'), Q.of(1, 2));
  expect(seqDur(p), Q.of(3));
}

void main() {
  test('slide of a packed middle remnant by +15 frames keeps outer ends and follows mid/right clipLocal cues', () {
    var p = splitTripleWithCues();
    final a = algebra.firstId(p);
    expectTriple(p, a);
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-mid')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-mid')['anchor']['clipId'], 'mid');
    expect(Q.fromJson(cueOf(p, 'cue-mid')['timelineRange']['start']), Q.of(1));
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(2),
    );
    final leftMap = timeMapOf(p, a);
    final midMap = timeMapOf(p, 'mid');
    final rightMap = timeMapOf(p, 'right');
    p = move.change(p, SlideClip(a, 'mid', 'right', slideDelta));
    expectSlid(p, a);
    expect(timeMapOf(p, a), leftMap);
    expect(timeMapOf(p, 'mid'), midMap);
    expect(timeMapOf(p, 'right'), rightMap);
    expect(cueOf(p, 'cue-left')['text'], 'hello');
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-mid')['text'], 'there');
    expect(cueOf(p, 'cue-mid')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-mid')['anchor']['clipId'], 'mid');
    expect(
      Q.fromJson(cueOf(p, 'cue-mid')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(cueOf(p, 'cue-right')['text'], 'stay');
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
  });

  test('an absolute cue stays at author time when the middle is slid', () {
    var p = splitTripleWithCues();
    final a = algebra.firstId(p);
    final hello = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-left')),
    );
    final mid = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-mid')),
    );
    final stay = CaptionCue.fromProjectJson(
      Map<String, dynamic>.from(cueOf(p, 'cue-right')),
    );
    p = move.change(
      p,
      SetCaptions(CaptionStore([hello, mid, stay.makeAbsolute()])),
    );
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'absolute');
    p = move.change(p, SlideClip(a, 'mid', 'right', slideDelta));
    expectSlid(p, a);
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-mid')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(p, 'cue-mid')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'absolute');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(2),
    );
  });

  test('a source-anchored cue on the right reprojects while the window still covers it', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'mid'));
    p = move.change(p, SplitClip('mid', Q.of(2), 'right'));
    final host = clipOf(p, 'right');
    final sourceCue =
        CaptionCue(
          'cue-src',
          TimeRange(Q.of(11, 4), Q.of(1, 8)),
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
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['start']),
      Q.of(11, 4),
    );
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['anchor']['range']['start']),
      Q.of(3, 4),
    );
    p = move.change(p, SlideClip(a, 'mid', 'right', slideDelta));
    expect(startOf(p, a), Q.of(0));
    expect(durationOf(p, a), Q.of(3, 2));
    expect(startOf(p, 'mid'), Q.of(3, 2));
    expect(durationOf(p, 'mid'), Q.of(1));
    expect(sourceStartOf(p, 'mid'), Q.of(1));
    expect(startOf(p, 'right'), Q.of(5, 2));
    expect(durationOf(p, 'right'), Q.of(1, 2));
    expect(sourceStartOf(p, 'right'), Q.of(5, 2));
    expect(sourceDurationOf(p, 'right'), Q.of(1, 2));
    expect(seqDur(p), Q.of(3));
    expect(cueOf(p, 'cue-src')['anchor']['kind'], 'source');
    expect(cueOf(p, 'cue-src')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['anchor']['range']['start']),
      Q.of(1, 4),
    );
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['start']),
      Q.of(11, 4),
    );
    expect(
      Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['duration']),
      Q.of(1, 8),
    );
  });

  test(
    'uncovering a source-anchored cue or a non-adjacent triple refuses wholly',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = move.change(p, SplitClip(a, Q.of(1), 'mid'));
      p = move.change(p, SplitClip('mid', Q.of(2), 'right'));
      final host = clipOf(p, 'right');
      final sourceCue =
          CaptionCue(
            'cue-src',
            TimeRange(Q.of(17, 8), Q.of(1, 2)),
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
          () => move.change(p, SlideClip(a, 'mid', 'right', slideDelta)),
          code('ANCHOR_OUT_OF_RANGE'),
        );
      });
      expect(startOf(p, 'right'), Q.of(2));
      expect(sourceStartOf(p, 'right'), Q.of(2));
      expect(startOf(p, 'mid'), Q.of(1));

      var packed = splitTripleWithCues();
      final left = algebra.firstId(packed);
      packed = move.change(packed, MoveClip('right', Q.of(1)));
      assertPure(packed, () {
        expect(
          () =>
              move.change(packed, SlideClip(left, 'mid', 'right', slideDelta)),
          code('NOT_ADJACENT'),
        );
      });
    },
  );

  test('source exhaustion or a locked sourceRange refuses the whole slide', () {
    var p = splitTripleWithCues();
    final a = algebra.firstId(p);
    p = move.change(p, SlipClip(a, Q.of(2)));
    expect(sourceStartOf(p, a), Q.of(2));
    assertPure(p, () {
      expect(
        () => move.change(p, SlideClip(a, 'mid', 'right', Q.of(1, 30))),
        code('SOURCE_OUT_OF_RANGE'),
      );
    });
    expect(durationOf(p, a), Q.of(1));
    expect(startOf(p, 'mid'), Q.of(1));
    expect(startOf(p, 'right'), Q.of(2));

    var lockedDoc = splitTripleWithCues();
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
        () => move.change(locked, SlideClip(left, 'mid', 'right', slideDelta)),
        code('FIELD_LOCKED'),
      );
    });
    expect(durationOf(locked, left), Q.of(1));
    expect(startOf(locked, 'mid'), Q.of(1));
    expect(startOf(locked, 'right'), Q.of(2));
  });

  test('linked AV slide with captions uses each member source rate and follows mid/right cues', () {
    var p = avFixture();
    final video = algebra.firstId(p);
    p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
    p = move.change(p, SplitClip(video, Q.of(1), 'mid'));
    p = move.change(p, SplitClip('mid', Q.of(2), 'right'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-left',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
      CaptionCue(
        'cue-mid',
        TimeRange(Q.of(1), Q.of(1, 2)),
        'there',
        manualFields: {'text', 'timing'},
      ),
      CaptionCue(
        'cue-right',
        TimeRange(Q.of(2), Q.of(1, 2)),
        'stay',
        manualFields: {'text', 'timing'},
      ),
    ]);
    String audioAt(Q start) =>
        media(p).singleWhere(
              (c) =>
                  c['id'] != video &&
                  c['id'] != 'mid' &&
                  c['id'] != 'right' &&
                  startOf(p, c['id'] as String) == start,
            )['id']
            as String;
    final audioLeft = audioAt(Q.of(0));
    final audioMid = audioAt(Q.of(1));
    final audioRight = audioAt(Q.of(2));
    expect(clipOf(p, audioLeft)['linkGroupId'], isNotNull);
    expect(
      clipOf(p, video)['linkGroupId'],
      clipOf(p, audioLeft)['linkGroupId'],
    );
    final leftRate = Q.fromJson(clipOf(p, audioLeft)['timeMap']['rate']);
    final rightRate = Q.fromJson(clipOf(p, audioRight)['timeMap']['rate']);
    final audioLeftSrc = sourceStartOf(p, audioLeft);
    final audioLeftSrcDur = sourceDurationOf(p, audioLeft);
    final audioMidSrc = sourceStartOf(p, audioMid);
    final audioMidSrcDur = sourceDurationOf(p, audioMid);
    final audioRightSrc = sourceStartOf(p, audioRight);
    p = move.change(p, SlideClip(video, 'mid', 'right', slideDelta));
    expect(startOf(p, video), Q.of(0));
    expect(durationOf(p, video), Q.of(3, 2));
    expect(sourceDurationOf(p, video), Q.of(3, 2));
    expect(startOf(p, 'mid'), Q.of(3, 2));
    expect(durationOf(p, 'mid'), Q.of(1));
    expect(sourceStartOf(p, 'mid'), Q.of(1));
    expect(startOf(p, 'right'), Q.of(5, 2));
    expect(durationOf(p, 'right'), Q.of(1, 2));
    expect(startOf(p, audioLeft), Q.of(0));
    expect(durationOf(p, audioLeft), Q.of(3, 2));
    expect(sourceStartOf(p, audioLeft), audioLeftSrc);
    expect(
      sourceDurationOf(p, audioLeft),
      audioLeftSrcDur + leftRate * slideDelta,
    );
    expect(startOf(p, audioMid), Q.of(3, 2));
    expect(durationOf(p, audioMid), Q.of(1));
    expect(sourceStartOf(p, audioMid), audioMidSrc);
    expect(sourceDurationOf(p, audioMid), audioMidSrcDur);
    expect(startOf(p, audioRight), Q.of(5, 2));
    expect(durationOf(p, audioRight), Q.of(1, 2));
    expect(
      sourceStartOf(p, audioRight),
      audioRightSrc + rightRate * slideDelta,
    );
    expect(seqDur(p), Q.of(3));
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(p, 'cue-mid')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(cueOf(p, 'cue-mid')['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(5, 2),
    );
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
  });
}
