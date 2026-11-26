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

/// +15 source frames at 30fps, matching the s3 slip example delta.
final slipDelta = Q.of(1, 2);

void expectUnmovedTimeline(ProjectDocument p, String a) {
  expect(startOf(p, a), Q.of(0));
  expect(durationOf(p, a), Q.of(1));
  expect(startOf(p, 'right'), Q.of(1));
  expect(durationOf(p, 'right'), Q.of(2));
  expect(seqDur(p), Q.of(3));
}

void main() {
  test('slip of the left remnant by +15 source frames keeps timeline, duration, TimeMap, and clipLocal cues', () {
    var p = splitWithCues();
    final a = algebra.firstId(p);
    expectUnmovedTimeline(p, a);
    expect(sourceStartOf(p, a), Q.of(0));
    expect(sourceDurationOf(p, a), Q.of(1));
    expect(sourceStartOf(p, 'right'), Q.of(1));
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    final mapBefore = timeMapOf(p, a);
    p = move.change(p, SlipClip(a, slipDelta));
    expectUnmovedTimeline(p, a);
    expect(sourceStartOf(p, a), Q.of(1, 2));
    expect(sourceDurationOf(p, a), Q.of(1));
    expect(sourceStartOf(p, 'right'), Q.of(1));
    expect(sourceDurationOf(p, 'right'), Q.of(2));
    expect(timeMapOf(p, a), mapBefore);
    expect(cueOf(p, 'cue-left')['text'], 'hello');
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-right')['text'], 'stay');
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-right')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });

  test('an absolute cue stays at author time when its neighbor is slipped', () {
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
    p = move.change(p, SlipClip(a, slipDelta));
    expectUnmovedTimeline(p, a);
    expect(sourceStartOf(p, a), Q.of(1, 2));
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-right')['anchor']['kind'], 'absolute');
    expect(
      Q.fromJson(cueOf(p, 'cue-right')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });

  test(
    'a source-anchored cue on the slipped host reprojects and stays covered',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = move.change(p, SplitClip(a, Q.of(1), 'right'));
      final host = clipOf(p, a);
      final sourceCue =
          CaptionCue(
            'cue-src',
            TimeRange(Q.of(1, 2), Q.of(1, 4)),
            'src',
            manualFields: {'text', 'timing'},
          ).anchoredToSource(
            clipId: a,
            clipStart: Q.fromJson(host['timelineRange']['start']),
            clipDuration: Q.fromJson(host['timelineRange']['duration']),
            sourceDuration: Q.fromJson(host['sourceRange']['duration']),
            rate: Q.fromJson(host['timeMap']['rate']),
          );
      p = move.change(p, SetCaptions(CaptionStore([sourceCue])));
      expect(cueOf(p, 'cue-src')['anchor']['kind'], 'source');
      expect(
        Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['start']),
        Q.of(1, 2),
      );
      expect(
        Q.fromJson(cueOf(p, 'cue-src')['anchor']['range']['start']),
        Q.of(1, 2),
      );
      p = move.change(p, SlipClip(a, slipDelta));
      expectUnmovedTimeline(p, a);
      expect(sourceStartOf(p, a), Q.of(1, 2));
      expect(cueOf(p, 'cue-src')['anchor']['kind'], 'source');
      expect(cueOf(p, 'cue-src')['anchor']['clipId'], a);
      expect(
        Q.fromJson(cueOf(p, 'cue-src')['anchor']['range']['start']),
        Q.of(0),
      );
      expect(
        Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['start']),
        Q.of(0),
      );
      expect(
        Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['duration']),
        Q.of(1, 4),
      );
    },
  );

  test('uncovering a source-anchored cue refuses ANCHOR_OUT_OF_RANGE and does not write', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    final host = clipOf(p, a);
    final sourceCue =
        CaptionCue(
          'cue-src',
          TimeRange(Q.of(0), Q.of(1, 2)),
          'src',
          manualFields: {'text', 'timing'},
        ).anchoredToSource(
          clipId: a,
          clipStart: Q.fromJson(host['timelineRange']['start']),
          clipDuration: Q.fromJson(host['timelineRange']['duration']),
          sourceDuration: Q.fromJson(host['sourceRange']['duration']),
          rate: Q.fromJson(host['timeMap']['rate']),
        );
    p = move.change(p, SetCaptions(CaptionStore([sourceCue])));
    assertPure(p, () {
      expect(
        () => move.change(p, SlipClip(a, slipDelta)),
        code('ANCHOR_OUT_OF_RANGE'),
      );
    });
    expect(sourceStartOf(p, a), Q.of(0));
    expect(Q.fromJson(cueOf(p, 'cue-src')['timelineRange']['start']), Q.of(0));
  });

  test(
    'slipping past the source tail or a locked sourceRange refuses wholly',
    () {
      var p = splitWithCues();
      final a = algebra.firstId(p);
      assertPure(p, () {
        expect(
          () => move.change(p, SlipClip('right', Q.of(1, 30))),
          code('SOURCE_OUT_OF_RANGE'),
        );
      });
      expect(sourceStartOf(p, 'right'), Q.of(1));
      final d = p.toJson();
      for (final t in d['sequences'][0]['tracks'] as List) {
        for (final item in t['items'] as List) {
          if (item['id'] == a) {
            item['lockedFields'] = ['sourceRange'];
          }
        }
      }
      final locked = ProjectDocument.fromJson(d);
      assertPure(locked, () {
        expect(
          () => move.change(locked, SlipClip(a, slipDelta)),
          code('FIELD_LOCKED'),
        );
      });
      expect(sourceStartOf(locked, a), Q.of(0));
    },
  );

  test('linked AV slip with captions moves each member source start by the same delta', () {
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
    ]);
    final audio =
        media(p).singleWhere(
              (c) =>
                  c['id'] != video &&
                  c['id'] != 'right' &&
                  startOf(p, c['id'] as String) == Q.of(0),
            )['id']
            as String;
    expect(clipOf(p, audio)['linkGroupId'], isNotNull);
    expect(clipOf(p, video)['linkGroupId'], clipOf(p, audio)['linkGroupId']);
    final audioSrc = sourceStartOf(p, audio);
    p = move.change(p, SlipClip(video, slipDelta));
    expect(startOf(p, video), Q.of(0));
    expect(durationOf(p, video), Q.of(1));
    expect(sourceStartOf(p, video), Q.of(1, 2));
    expect(sourceStartOf(p, audio), audioSrc + slipDelta);
    expect(startOf(p, audio), Q.of(0));
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(0));
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
  });
}
