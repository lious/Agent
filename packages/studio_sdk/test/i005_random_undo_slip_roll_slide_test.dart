import 'dart:io';
import 'dart:math';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:test/test.dart';

import 'multi_move_fixture.dart';

/// Increment 1.88 official I-005 SDK seed. Distinct from the document 1.88
/// seed (`0x18800505`), Increment 1.38 (`0x51500500`), the SDK 1.38 companion
/// (`0x10005e05`), I-006 1.84 (`0x16061E84`), and the slip/inverse cases
/// (`251125`). This file does not rewrite those suites.
const i005SdkRandomUndoSeed = 0x188005E5;
const i005SdkRandomUndoCount = 1000;

String contents(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

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

EditOperation fallbackEdit(ProjectDocument p, int n) {
  final cues = [
    for (final c in (p.toJson()['captions'] as List).cast<Map>())
      CaptionCue.fromProjectJson(Map<String, dynamic>.from(c)),
  ];
  cues[0] = cues[0].editText('stay-$n');
  return SetCaptions(CaptionStore(cues));
}

String familyOf(EditOperation op) => switch (op) {
  SlipClip() => 'slip',
  RollCut() => 'roll',
  SlideClip() => 'slide',
  TrimClip() => 'leave-gap-trim',
  RippleTrimClip() => 'ripple-trim',
  MoveClips() => 'move',
  SetCaptions() => 'set-captions',
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

void attachStayCue(StudioWorkspace w) {
  w.edit(
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
    expectedRevision: w.current.revision,
  );
  final forced = [
    for (final c in w.current.toJson()['captions'] as List)
      CaptionCue.fromProjectJson(Map<String, dynamic>.from(c as Map))
          .makeAbsolute(),
  ];
  w.edit(
    SetCaptions(CaptionStore(forced)),
    expectedRevision: w.current.revision,
  );
}

void main() {
  late Directory root;
  late StudioWorkspace w;
  setUp(() async {
    root = Directory.systemTemp.createTempSync('i005-random-undo-');
    w = openMoveWorkspace(root);
    await installLinkedMoveFixture(w, root);
    final first = moveVideos(w.current).first['id'] as String;
    w.edit(
      SplitClip(first, Q.of(1), 'i088-mid'),
      expectedRevision: w.current.revision,
    );
    attachStayCue(w);
  });
  tearDown(() async {
    await w.closeAsync();
    root.deleteSync(recursive: true);
  });

  test('1000 official random sequences including Slip/Roll/Slide undo via restoreSnapshot to the start content hash', () async {
    final originHash = contents(w.current);
    var legal = 0;
    var refusals = 0;
    final families = <String, int>{
      'slip': 0,
      'roll': 0,
      'slide': 0,
      'leave-gap-trim': 0,
      'ripple-trim': 0,
      'move': 0,
      'set-captions': 0,
    };
    for (var trial = 0; trial < i005SdkRandomUndoCount; trial++) {
      expect(
        contents(w.current),
        originHash,
        reason: 'trial $trial did not start at origin',
      );
      final rng = Random(i005SdkRandomUndoSeed + trial);
      var applied = 0;
      final steps = 1 + rng.nextInt(5);
      for (var step = 0; step < steps; step++) {
        final before = w.current;
        final beforeHash = contents(before);
        final op = pickOfficial(before, rng) ?? fallbackEdit(before, legal);
        try {
          w.edit(op, expectedRevision: before.revision);
          if (contents(w.current) == beforeHash) {
            continue;
          }
          applied++;
          legal++;
          families[familyOf(op)] = (families[familyOf(op)] ?? 0) + 1;
        } on StudioException {
          expect(contents(w.current), beforeHash);
          refusals++;
        }
      }
      for (var i = 0; i < applied; i++) {
        w.undo(expectedRevision: w.current.revision);
      }
      expect(
        contents(w.current),
        originHash,
        reason: 'undo sequence hash mismatch trial $trial',
      );
    }
    // ignore: avoid_print
    print(
      'i005-1.88 sdk: $i005SdkRandomUndoCount sequences, '
      'legal=$legal refusals=$refusals families=$families '
      'seed=0x${i005SdkRandomUndoSeed.toRadixString(16)}',
    );
    expect(legal, greaterThan(0));
    expect(families['slip']!, greaterThan(0));
    expect(families['roll']!, greaterThan(0));
    expect(families['slide']!, greaterThan(0));
  }, timeout: Timeout(const Duration(minutes: 10)));
}
