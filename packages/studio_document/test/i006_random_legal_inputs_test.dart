import 'dart:convert';
import 'dart:math';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

/// Increment 1.84 official I-006 seed. Distinct from the I-005 undo suite
/// (`0x51500500` in nle_random_undo_test.dart), the SDK undo driver
/// (`0x10005e05`), and the slip/inverse cases (`251125`). This file is not a
/// substitute for those suites and does not rewrite them.
const i006LegalInputSeed = 0x16061E84;
const i006LegalInputCount = 1000;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

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

Q endOf(ProjectDocument p, String id) => startOf(p, id) + durationOf(p, id);

Q sourceStartOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['start']);

Q sourceDurationOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['duration']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

Q rateOf(Map clip) => Q.fromJson(clip['timeMap']['rate']);

Q qStart(Map clip) => Q.fromJson(clip['timelineRange']['start']);

Q qDur(Map clip) => Q.fromJson(clip['timelineRange']['duration']);

Q qEnd(Map clip) => qStart(clip) + qDur(clip);

Q qSrcStart(Map clip) => Q.fromJson(clip['sourceRange']['start']);

Q qSrcDur(Map clip) => Q.fromJson(clip['sourceRange']['duration']);

String firstVideoId(ProjectDocument p) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    if (t['kind'] != 'video') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  throw StateError('no video clip');
}

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

bool sourceFits(ProjectDocument p, Map clip, Q sourceStart, Q sourceDuration) {
  if (sourceStart < Q.of(0) || sourceDuration <= Q.of(0)) return false;
  return sourceStart + sourceDuration <= streamDuration(p, clip);
}

bool durationOk(Q duration) => duration >= Q.of(1, 30);

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

Map? previousMedia(ProjectDocument p, Map clip) {
  Map? prev;
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    final clips = [
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
    ]..sort((a, b) => qStart(a).compareTo(qStart(b)));
    for (final c in clips) {
      if (c['id'] == clip['id']) return prev;
      prev = c;
    }
    prev = null;
  }
  return null;
}

Map? nextMedia(ProjectDocument p, Map clip) {
  var seen = false;
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    final clips = [
      for (final c in t['items'])
        if (c['source'] != null) c as Map,
    ]..sort((a, b) => qStart(a).compareTo(qStart(b)));
    for (final c in clips) {
      if (seen) return c;
      if (c['id'] == clip['id']) seen = true;
    }
    seen = false;
  }
  return null;
}

Set<String> mediaIds(ProjectDocument p) => {
  for (final c in media(p)) c['id'] as String,
};

Set<String> sourceFingerprints(ProjectDocument p) {
  final assets = {
    for (final a in p.toJson()['assets'] as List) a['id'] as String: a,
  };
  return {
    for (final a in assets.values)
      if (a['originalBlobHash'] != null)
        'asset:${a['id']}:${a['originalBlobHash']}',
    for (final b in p.toJson()['blobs'] as List) 'blob:${b['hash']}',
    for (final c in media(p))
      'clip:${c['id']}:${c['source']['kind']}:${c['source']['id']}:${c['source']['streamId']}',
  };
}

Q coverOf(ProjectDocument p) {
  var end = Q.of(0);
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    for (final item in t['items']) {
      final itemEnd =
          Q.fromJson(item['timelineRange']['start']) +
          Q.fromJson(item['timelineRange']['duration']);
      if (itemEnd > end) end = itemEnd;
    }
  }
  for (final c in p.toJson()['captions'] as List) {
    final cueEnd =
        Q.fromJson(c['timelineRange']['start']) +
        Q.fromJson(c['timelineRange']['duration']);
    if (cueEnd > end) end = cueEnd;
  }
  return end;
}

void assertLengthAndSourceConservation(
  ProjectDocument before,
  ProjectDocument after,
  EditOperation op,
) {
  expect(
    seqDur(after),
    coverOf(after),
    reason: 'sequence duration is the cover',
  );
  expect(
    sourceFingerprints(after).containsAll(
      sourceFingerprints(before)
          .where((s) => s.startsWith('asset:') || s.startsWith('blob:')),
    ),
    isTrue,
    reason: 'source media hashes must be unchanged',
  );
  for (final a in before.toJson()['assets'] as List) {
    final b = (after.toJson()['assets'] as List).singleWhere(
      (x) => x['id'] == a['id'],
    );
    expect(b['originalBlobHash'], a['originalBlobHash']);
  }
  for (final clip in media(after)) {
    expect(clip['timeMap']['kind'], 'linear');
    final rate = rateOf(clip);
    expect(rate > Q.of(0), isTrue);
    expect(
      qSrcDur(clip),
      rate * qDur(clip),
      reason: 'sourceDuration == rate * timelineDuration for ${clip['id']}',
    );
    expect(qSrcStart(clip) >= Q.of(0), isTrue);
    expect(
      qSrcStart(clip) + qSrcDur(clip) <= streamDuration(after, clip),
      isTrue,
      reason: 'sourceRange stays inside the available stream for ${clip['id']}',
    );
    if (mediaIds(before).contains(clip['id'])) {
      final old = clipOf(before, clip['id'] as String);
      expect(clip['source']['kind'], old['source']['kind']);
      expect(clip['source']['id'], old['source']['id']);
      expect(clip['source']['streamId'], old['source']['streamId']);
    }
  }
  switch (op) {
    case SlipClip(:final clipId):
      expect(
        seqDur(after),
        seqDur(before),
        reason: 'slip keeps sequence duration',
      );
      expect(startOf(after, clipId), startOf(before, clipId));
      expect(durationOf(after, clipId), durationOf(before, clipId));
      expect(
        mediaIds(after),
        mediaIds(before),
        reason: 'slip must not delete a neighbor',
      );
    case RollCut(:final leftId, :final rightId):
      expect(
        seqDur(after),
        seqDur(before),
        reason: 'roll keeps sequence duration',
      );
      expect(startOf(after, leftId), startOf(before, leftId));
      expect(endOf(after, rightId), endOf(before, rightId));
      expect(
        mediaIds(after),
        mediaIds(before),
        reason: 'roll must not delete a neighbor',
      );
    case SlideClip(:final leftId, :final clipId, :final rightId):
      expect(
        seqDur(after),
        seqDur(before),
        reason: 'slide keeps sequence duration',
      );
      expect(startOf(after, leftId), startOf(before, leftId));
      expect(endOf(after, rightId), endOf(before, rightId));
      expect(sourceStartOf(after, clipId), sourceStartOf(before, clipId));
      expect(sourceDurationOf(after, clipId), sourceDurationOf(before, clipId));
      expect(durationOf(after, clipId), durationOf(before, clipId));
      expect(
        mediaIds(after),
        mediaIds(before),
        reason: 'slide must not delete a neighbor',
      );
    case TrimClip(:final clipId) when !op.ripple:
      expect(
        mediaIds(after),
        mediaIds(before),
        reason: 'leave-gap trim must not delete a neighbor',
      );
      expect(mediaIds(after).contains(clipId), isTrue);
    case RippleTrimClip(:final clipId):
      expect(mediaIds(after).contains(clipId), isTrue);
      for (final id in mediaIds(before)) {
        final group = clipOf(before, id)['linkGroupId'];
        final hostGroup = clipOf(before, clipId)['linkGroupId'];
        if (id == clipId || (group != null && group == hostGroup)) {
          expect(mediaIds(after).contains(id), isTrue);
        }
      }
    default:
      fail('unexpected official I-006 operation ${op.runtimeType}');
  }
}

ProjectDocument packedBaseline(Random rng) {
  var p = avFixture();
  final video = firstVideoId(p);
  if (rng.nextBool()) {
    p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  }
  p = move.change(p, SplitClip(video, Q.of(1), 'i006-mid'));
  p = move.change(p, SplitClip('i006-mid', Q.of(2), 'i006-right'));
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
  // SetCaptions may default a new cue to clipLocal if it is covered; force
  // the official absolute stay cue so legal I-006 ops are not blocked.
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
    // +delta: left grows, right shrinks.
    final posLeftSrc =
        streamDuration(p, left) - (qSrcStart(left) + qSrcDur(left));
    final posLeftTime = posLeftSrc / ra;
    final posRightTime = (qDur(right) - Q.of(1, 30));
    final posHeadroom = posLeftTime < posRightTime ? posLeftTime : posRightTime;
    // -delta: left shrinks, right grows.
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
    final negHeadroom = negRightTime < negLeftTime ? negRightTime : negLeftTime;
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
    // in +delta shortens (start moves later); in -delta lengthens into a gap.
    final inPosTime = duration - Q.of(1, 30);
    final inNegGap = start - prevEnd;
    final inNegSrc = srcStart / rate;
    final inNegTime = inNegGap < inNegSrc ? inNegGap : inNegSrc;
    // out +delta lengthens into a gap; out -delta shortens.
    final outPosSrc = streamDuration(p, c) - (srcStart + srcDur);
    final outPosHeadroom = () {
      final srcTime = outPosSrc / rate;
      final gap = nextStart == null
          ? srcTime
          : (nextStart - (start + duration));
      return gap < srcTime ? gap : srcTime;
    }();
    final outNegTime = duration - Q.of(1, 30);
    final edge = rng.nextBool() ? 'in' : 'out';
    final delta = edge == 'in'
        ? pickSignedDelta(rng, inNegTime, inPosTime)
        : pickSignedDelta(rng, outNegTime, outPosHeadroom);
    if (delta == null) continue;
    final nextDur = edge == 'in' ? duration - delta : duration + delta;
    if (!durationOk(nextDur)) continue;
    if (edge == 'in') {
      final newStart = start + delta;
      if (newStart < prevEnd || newStart < Q.of(0)) continue;
      if (!sourceFits(p, c, srcStart + rate * delta, srcDur - rate * delta)) {
        continue;
      }
    } else {
      final newEnd = start + duration + delta;
      if (nextStart != null && newEnd > nextStart) continue;
      if (!sourceFits(p, c, srcStart, srcDur + rate * delta)) continue;
    }
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
    // in +delta shortens the source head, duration shrinks.
    final inPosTime = duration - Q.of(1, 30);
    // in -delta lengthens the source head.
    final inNegTime = srcStart / rate;
    // out +delta lengthens the tail; out -delta shortens.
    final outPosTime = (streamDuration(p, c) - (srcStart + srcDur)) / rate;
    final outNegTime = duration - Q.of(1, 30);
    final edge = rng.nextBool() ? 'in' : 'out';
    final delta = edge == 'in'
        ? pickSignedDelta(rng, inNegTime, inPosTime)
        : pickSignedDelta(rng, outNegTime, outPosTime);
    if (delta == null) continue;
    final durationDelta = edge == 'out' ? delta : Q.of(0) - delta;
    if (!durationOk(duration + durationDelta)) continue;
    var nextSrcStart = srcStart;
    if (edge == 'in') nextSrcStart = srcStart + rate * delta;
    if (!sourceFits(p, c, nextSrcStart, rate * (duration + durationDelta))) {
      continue;
    }
    return RippleTrimClip(c['id'] as String, edge, delta);
  }
  return null;
}

EditOperation? pickLegalI006(ProjectDocument p, Random rng) {
  final families = [trySlip, tryRoll, trySlide, tryLeaveGapTrim, tryRippleTrim]
    ..shuffle(rng);
  for (final family in families) {
    final op = family(p, rng);
    if (op != null) return op;
  }
  return null;
}

String familyName(EditOperation op) => switch (op) {
  SlipClip() => 'slip',
  RollCut() => 'roll',
  SlideClip() => 'slide',
  TrimClip() => 'leave-gap-trim',
  RippleTrimClip() => 'ripple-trim',
  _ => op.runtimeType.toString(),
};

void assertUnchanged(ProjectDocument p, String before, void Function() body) {
  final raw = jsonEncode(p.toJson());
  body();
  expect(content(p), before);
  expect(jsonEncode(p.toJson()), raw);
}

void main() {
  test('1000 seeded random legal I-006 inputs conserve length and source range; applyEdit stays pure', () {
    const trials = i006LegalInputCount;
    const seed = i006LegalInputSeed;
    var legal = 0;
    var attempt = 0;
    final families = <String, int>{};
    while (legal < trials) {
      attempt++;
      expect(
        attempt,
        lessThan(20000),
        reason: 'could not collect $trials legal I-006 inputs',
      );
      final rng = Random(seed + attempt);
      var current = packedBaseline(rng);
      final steps = 1 + rng.nextInt(3);
      for (var step = 0; step < steps && legal < trials; step++) {
        final op = pickLegalI006(current, rng);
        if (op == null) break;
        final beforeHash = content(current);
        final raw = jsonEncode(current.toJson());
        late final ProjectDocument next;
        try {
          next = move.change(current, op);
        } on StudioException catch (e) {
          fail(
            'legal attempt $attempt step $step refused ${e.code} for '
            '${familyName(op)} ${op.toJson()}',
          );
        }
        expect(
          content(current),
          beforeHash,
          reason: 'legal attempt $attempt step $step mutated before',
        );
        expect(jsonEncode(current.toJson()), raw);
        assertLengthAndSourceConservation(current, next, op);
        families[familyName(op)] = (families[familyName(op)] ?? 0) + 1;
        current = next;
        legal++;
      }
    }
    expect(legal, trials);
    expect(families['slip'], greaterThan(0));
    expect(families['roll'], greaterThan(0));
    expect(families['slide'], greaterThan(0));
    expect(families['leave-gap-trim'], greaterThan(0));
    expect(families['ripple-trim'], greaterThan(0));
    // Printed for evidence; the official count is [trials] legal applies.
    // ignore: avoid_print
    print(
      'I-006 1.84 legal=$legal seed=0x${seed.toRadixString(16)} '
      'attempts=$attempt families=$families',
    );
  });

  test('I-006 refusals leave the document unchanged (no half-write)', () {
    var p = avFixture();
    final video = firstVideoId(p);
    p = move.change(p, SplitClip(video, Q.of(1), 'i006-mid'));
    p = move.change(p, SplitClip('i006-mid', Q.of(2), 'i006-right'));
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue(
            'cue-source',
            TimeRange(Q.of(1), Q.of(1, 2)),
            'source',
            manualFields: {'text', 'timing'},
          ).anchoredToSource(
            clipId: 'i006-mid',
            clipStart: Q.of(1),
            clipDuration: Q.of(1),
            sourceDuration: Q.of(1),
            rate: Q.of(1),
          ),
          CaptionCue(
            'cue-abs',
            TimeRange(Q.of(0), Q.of(1, 4)),
            'stay',
            manualFields: {'text', 'timing'},
          ).makeAbsolute(),
        ]),
      ),
    );

    void refuse(EditOperation op, String expected) {
      final before = content(p);
      assertUnchanged(p, before, () {
        expect(() => move.change(p, op), code(expected));
      });
    }

    refuse(RollCut(video, 'i006-right', Q.of(1, 30)), 'NOT_ADJACENT');
    refuse(
      SlideClip(video, 'i006-right', 'i006-mid', Q.of(1, 30)),
      'NOT_ADJACENT',
    );
    refuse(SlipClip(video, Q.of(-1)), 'INVALID_RANGE');
    refuse(SlipClip(video, Q.of(3)), 'SOURCE_OUT_OF_RANGE');
    refuse(TrimClip(video, 'out', Q.of(2)), 'COLLISION');
    refuse(SlipClip('i006-mid', Q.of(3, 5)), 'ANCHOR_OUT_OF_RANGE');

    final lockedJson = p.toJson();
    for (final t in lockedJson['sequences'][0]['tracks']) {
      for (final c in t['items']) {
        if (c['id'] == 'i006-right' && c['source'] != null) {
          c['lockedFields'] = ['sourceRange'];
        }
      }
    }
    final locked = ProjectDocument.fromJson(lockedJson);
    final lockedHash = content(locked);
    assertUnchanged(locked, lockedHash, () {
      expect(
        () => move.change(locked, SlipClip('i006-right', Q.of(1, 30))),
        code('FIELD_LOCKED'),
      );
    });

    var withDissolve = move.change(
      p,
      SetDissolve(video, 'i006-mid', Q.of(1, 5), Q.of(1, 5)),
    );
    final dissolveHash = content(withDissolve);
    assertUnchanged(withDissolve, dissolveHash, () {
      expect(
        () => move.change(withDissolve, TrimClip(video, 'out', Q.of(-1, 30))),
        code('TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL'),
      );
    });

    final captionBefore = content(p);
    assertUnchanged(p, captionBefore, () {
      expect(
        () => CaptionStore([
          CaptionCue('a', TimeRange(Q.of(0), Q.of(1)), 'a'),
          CaptionCue('b', TimeRange(Q.of(1, 2), Q.of(1)), 'b'),
        ]),
        code('CAPTION_OVERLAP'),
      );
    });
  });
}
