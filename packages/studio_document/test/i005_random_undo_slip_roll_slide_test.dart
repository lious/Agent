import 'dart:math';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

/// Increment 1.88 official I-005 seed. Distinct from Increment 1.38
/// (`0x51500500` in nle_random_undo_test.dart), the SDK 1.38 companion
/// (`0x10005e05`), I-006 1.84 (`0x16061E84`), and the slip/inverse cases
/// (`251125`). This file does not rewrite those suites.
const i005RandomUndoSeed = 0x18800505;
const i005RandomUndoTrials = 1000;

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

Map clipOf(ProjectDocument p, String id) =>
    media(p).singleWhere((c) => c['id'] == id);

Q rateOf(Map clip) => Q.fromJson(clip['timeMap']['rate']);

Q qStart(Map clip) => Q.fromJson(clip['timelineRange']['start']);

Q qDur(Map clip) => Q.fromJson(clip['timelineRange']['duration']);

Q qEnd(Map clip) => qStart(clip) + qDur(clip);

Q qSrcStart(Map clip) => Q.fromJson(clip['sourceRange']['start']);

Q qSrcDur(Map clip) => Q.fromJson(clip['sourceRange']['duration']);

Q streamDuration(ProjectDocument p, Map clip) {
  final source = clip['source'] as Map;
  final assets = (p.toJson()['assets'] as List).where(
    (a) => a['id'] == source['id'],
  );
  final streams = (assets.single['streams'] as List).where(
    (s) => s['id'] == source['streamId'],
  );
  return Q.fromJson(streams.single['duration']);
}

int? framesAt30(Q q) {
  final frames = q * Q.of(30);
  if (frames.d != BigInt.one) return null;
  return frames.n.toInt();
}

Q? pickSignedDelta(Random rng, Q negativeHeadroom, Q positiveHeadroom) {
  final neg = framesAt30(negativeHeadroom) ?? 0;
  final pos = framesAt30(positiveHeadroom) ?? 0;
  final choices = <int>[
    if (neg > 0)
      for (var f = 1; f <= neg && f <= 15; f++) -f,
    if (pos > 0)
      for (var f = 1; f <= pos && f <= 15; f++) f,
  ];
  if (choices.isEmpty) return null;
  return Q.of(choices[rng.nextInt(choices.length)], 30);
}

List<Map> trackMedia(ProjectDocument p, Map clip) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    final clips = [
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
    ];
    if (clips.any((c) => c['id'] == clip['id'])) {
      clips.sort((a, b) => qStart(a).compareTo(qStart(b)));
      return clips;
    }
  }
  return const [];
}

Map? previousMedia(ProjectDocument p, Map clip) {
  final clips = trackMedia(p, clip);
  final i = clips.indexWhere((c) => c['id'] == clip['id']);
  return i > 0 ? clips[i - 1] : null;
}

Map? nextMedia(ProjectDocument p, Map clip) {
  final clips = trackMedia(p, clip);
  final i = clips.indexWhere((c) => c['id'] == clip['id']);
  return i >= 0 && i < clips.length - 1 ? clips[i + 1] : null;
}

List<(Map, Map)> packedPairs(ProjectDocument p) {
  final out = <(Map, Map)>[];
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    final clips = [
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
    ]..sort((a, b) => qStart(a).compareTo(qStart(b)));
    for (var i = 0; i < clips.length - 1; i++) {
      if (qEnd(clips[i]) == qStart(clips[i + 1])) {
        out.add((clips[i], clips[i + 1]));
      }
    }
  }
  return out;
}

List<(Map, Map, Map)> packedTriples(ProjectDocument p) {
  final out = <(Map, Map, Map)>[];
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    final clips = [
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
    ]..sort((a, b) => qStart(a).compareTo(qStart(b)));
    for (var i = 0; i < clips.length - 2; i++) {
      if (qEnd(clips[i]) == qStart(clips[i + 1]) &&
          qEnd(clips[i + 1]) == qStart(clips[i + 2])) {
        out.add((clips[i], clips[i + 1], clips[i + 2]));
      }
    }
  }
  return out;
}

ProjectDocument packedBaseline(Random rng) {
  var p = avFixture();
  final video = media(p).first['id'] as String;
  if (rng.nextBool()) {
    final stream =
        (p.toJson()['assets'][0]['streams'] as List).singleWhere(
              (s) => s['type'] == 'audio',
            )['id']
            as String;
    p = move.change(p, ExtractAudioClip(video, stream));
  }
  p = move.change(p, SplitClip(video, Q.of(1), 'i088-mid'));
  p = move.change(p, SplitClip('i088-mid', Q.of(2), 'i088-right'));
  p = move.change(
    p,
    SetCaptions(
      CaptionStore([
        CaptionCue(
          'cue-abs',
          TimeRange(Q.of(1, 2), Q.of(1, 2)),
          'stay',
          manualFields: {'text', 'timing'},
        ).makeAbsolute(),
      ]),
    ),
  );
  final forced = [
    for (final c in p.toJson()['captions'] as List)
      CaptionCue.fromProjectJson(Map<String, dynamic>.from(c as Map))
          .makeAbsolute(),
  ];
  return move.change(p, SetCaptions(CaptionStore(forced)));
}

EditOperation? trySlip(ProjectDocument p, Random rng) {
  final clips = [...media(p)]..shuffle(rng);
  for (final c in clips) {
    final head = qSrcStart(c);
    final tail = streamDuration(p, c) - (qSrcStart(c) + qSrcDur(c));
    final delta = pickSignedDelta(rng, head, tail);
    if (delta == null) continue;
    return SlipClip(c['id'] as String, delta);
  }
  return null;
}

EditOperation? tryRoll(ProjectDocument p, Random rng) {
  final pairs = packedPairs(p)..shuffle(rng);
  for (final (left, right) in pairs) {
    final ra = rateOf(left);
    final rb = rateOf(right);
    final posLeftSrc =
        streamDuration(p, left) - (qSrcStart(left) + qSrcDur(left));
    final posLeftTime = posLeftSrc / ra;
    final posRightTime = qDur(right) - Q.of(1, 30);
    final posHeadroom = posLeftTime < posRightTime ? posLeftTime : posRightTime;
    final negRightSrc = qSrcStart(right);
    final negRightTime = negRightSrc / rb;
    final negLeftTime = qDur(left) - Q.of(1, 30);
    final negHeadroom = negRightTime < negLeftTime ? negRightTime : negLeftTime;
    final delta = pickSignedDelta(rng, negHeadroom, posHeadroom);
    if (delta == null) continue;
    return RollCut(left['id'] as String, right['id'] as String, delta);
  }
  return null;
}

EditOperation? trySlide(ProjectDocument p, Random rng) {
  final triples = packedTriples(p)..shuffle(rng);
  for (final (left, mid, right) in triples) {
    final ra = rateOf(left);
    final rb = rateOf(right);
    final posLeftSrc =
        streamDuration(p, left) - (qSrcStart(left) + qSrcDur(left));
    final posLeftTime = posLeftSrc / ra;
    final posRightTime = qDur(right) - Q.of(1, 30);
    final posHeadroom = posLeftTime < posRightTime ? posLeftTime : posRightTime;
    final negRightSrc = qSrcStart(right);
    final negRightTime = negRightSrc / rb;
    final negLeftTime = qDur(left) - Q.of(1, 30);
    final negHeadroom = negRightTime < negLeftTime ? negLeftTime : negLeftTime;
    final delta = pickSignedDelta(rng, negHeadroom, posHeadroom);
    if (delta == null) continue;
    return SlideClip(
      left['id'] as String,
      mid['id'] as String,
      right['id'] as String,
      delta,
    );
  }
  return null;
}

EditOperation? tryLeaveGapTrim(ProjectDocument p, Random rng) {
  final clips = [...media(p)]..shuffle(rng);
  for (final c in clips) {
    final rate = rateOf(c);
    final start = qStart(c);
    final duration = qDur(c);
    final srcStart = qSrcStart(c);
    final srcDur = qSrcDur(c);
    final prev = previousMedia(p, c);
    final next = nextMedia(p, c);
    final prevEnd = prev == null ? Q.of(0) : qEnd(prev);
    final nextStart = next == null ? null : qStart(next);
    final inPosTime = duration - Q.of(1, 30);
    final inNegGap = start - prevEnd;
    final inNegSrc = srcStart / rate;
    final inNegTime = inNegGap < inNegSrc ? inNegGap : inNegSrc;
    final outNegTime = duration - Q.of(1, 30);
    final outPosGap = nextStart == null
        ? streamDuration(p, c)
        : nextStart - qEnd(c);
    final outPosSrc = (streamDuration(p, c) - (srcStart + srcDur)) / rate;
    final outPosTime = outPosGap < outPosSrc ? outPosGap : outPosSrc;
    final edge = rng.nextBool() ? 'in' : 'out';
    final delta = edge == 'in'
        ? pickSignedDelta(rng, inNegTime, inPosTime)
        : pickSignedDelta(rng, outNegTime, outPosTime);
    if (delta == null) continue;
    return TrimClip(c['id'] as String, edge, delta);
  }
  return null;
}

EditOperation? tryRippleTrim(ProjectDocument p, Random rng) {
  final clips = [...media(p)]..shuffle(rng);
  for (final c in clips) {
    final rate = rateOf(c);
    final duration = qDur(c);
    final srcStart = qSrcStart(c);
    final srcDur = qSrcDur(c);
    final inPosTime = duration - Q.of(1, 30);
    final inNegSrc = srcStart / rate;
    final outNegTime = duration - Q.of(1, 30);
    final outPosSrc = (streamDuration(p, c) - (srcStart + srcDur)) / rate;
    final edge = rng.nextBool() ? 'in' : 'out';
    final delta = edge == 'in'
        ? pickSignedDelta(rng, inNegSrc, inPosTime)
        : pickSignedDelta(rng, outNegTime, outPosSrc);
    if (delta == null) continue;
    return RippleTrimClip(c['id'] as String, edge, delta);
  }
  return null;
}

EditOperation? tryMove(ProjectDocument p, Random rng) {
  final clips = [...media(p)]..shuffle(rng);
  for (final c in clips) {
    final prev = previousMedia(p, c);
    final next = nextMedia(p, c);
    final choices = <Q>[];
    if (next == null) {
      for (var f = 1; f <= 8; f++) {
        choices.add(Q.of(f, 30));
      }
    } else {
      final gap = framesAt30(qStart(next) - qEnd(c)) ?? 0;
      for (var f = 1; f <= gap && f <= 8; f++) {
        choices.add(Q.of(f, 30));
      }
    }
    final leftRoom = prev == null ? qStart(c) : qStart(c) - qEnd(prev);
    final left = framesAt30(leftRoom) ?? 0;
    for (var f = 1; f <= left && f <= 8; f++) {
      choices.add(Q.of(-f, 30));
    }
    if (choices.isEmpty) continue;
    return MoveClips(
      [c['id'] as String],
      choices[rng.nextInt(choices.length)],
      includeLinks: true,
    );
  }
  return null;
}

String familyOf(EditOperation op) => switch (op) {
  SlipClip() => 'slip',
  RollCut() => 'roll',
  SlideClip() => 'slide',
  TrimClip() => 'leave-gap-trim',
  RippleTrimClip() => 'ripple-trim',
  MoveClips() => 'move',
  _ => op.runtimeType.toString(),
};

EditOperation? pickOfficial(ProjectDocument p, Random rng) {
  final families = [
    trySlip,
    tryRoll,
    trySlide,
    tryLeaveGapTrim,
    tryRippleTrim,
    tryMove,
  ]..shuffle(rng);
  for (final tryFamily in families) {
    final op = tryFamily(p, rng);
    if (op != null) return op;
  }
  return null;
}

EditOperation refusalOp(ProjectDocument p, Random rng) {
  final clips = media(p);
  if (clips.isNotEmpty && rng.nextBool()) {
    return MoveClips([clips.first['id'] as String], Q.of(-10));
  }
  final pairs = packedPairs(p);
  if (pairs.length >= 2) {
    return RollCut(
      pairs.first.$1['id'] as String,
      pairs.last.$2['id'] as String,
      Q.of(1, 30),
    );
  }
  return MoveClips([clips.first['id'] as String], Q.of(-10));
}

void main() {
  test('1000 seeded random official sequences including Slip/Roll/Slide undo to the start content hash', () {
    var legal = 0;
    var refusals = 0;
    final families = <String, int>{
      'slip': 0,
      'roll': 0,
      'slide': 0,
      'leave-gap-trim': 0,
      'ripple-trim': 0,
      'move': 0,
    };
    for (var trial = 0; trial < i005RandomUndoTrials; trial++) {
      final rng = Random(i005RandomUndoSeed + trial);
      final start = packedBaseline(rng);
      final startHash = content(start);
      var current = start;
      final stack = <ProjectDocument>[start];
      final steps = 1 + rng.nextInt(5);
      for (var step = 0; step < steps; step++) {
        final beforeHash = content(current);
        final op = rng.nextInt(12) == 0
            ? refusalOp(current, rng)
            : pickOfficial(current, rng);
        if (op == null) continue;
        try {
          final next = move.change(current, op);
          expect(
            content(current),
            beforeHash,
            reason: 'applyEdit must be pure; trial $trial step $step',
          );
          if (content(next) == beforeHash) continue;
          current = next;
          stack.add(next);
          legal++;
          families[familyOf(op)] = (families[familyOf(op)] ?? 0) + 1;
        } on StudioException {
          expect(
            content(current),
            beforeHash,
            reason: 'refusal must not half-write; trial $trial step $step',
          );
          refusals++;
        }
      }
      // Official InversePatch kind is restoreSnapshot: walking the
      // immutable before-snapshots restores the start content hash.
      expect(content(start), startHash, reason: 'start drifted trial $trial');
      expect(
        content(stack.first),
        startHash,
        reason: 'restoreSnapshot walk missed start trial $trial',
      );
      var restored = current;
      for (var i = stack.length - 1; i > 0; i--) {
        restored = stack[i - 1];
      }
      expect(
        content(restored),
        startHash,
        reason: 'undo sequence hash mismatch trial $trial',
      );
    }
    expect(legal, greaterThan(0));
    expect(families['slip']!, greaterThan(0));
    expect(families['roll']!, greaterThan(0));
    expect(families['slide']!, greaterThan(0));
    // ignore: avoid_print
    print(
      'i005-1.88 document: $i005RandomUndoTrials sequences, '
      'legal=$legal refusals=$refusals families=$families '
      'seed=0x${i005RandomUndoSeed.toRadixString(16)}',
    );
  });
}
