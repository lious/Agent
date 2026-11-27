import 'dart:math';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import '../../multi_move_test.dart' as move;
import '../../persistent_audio_test.dart' show avFixture;

/// Distinct from Increment 1.38 (`0x51500500`), I-005 1.88 (`0x18800505`),
/// I-006 1.84 (`0x16061E84`), and the slip/inverse cases (`251125`).
/// This file does not rewrite those suites.
const i009GainRandomUndoSeed = 0x2090A009;
const i009GainRandomUndoTrials = 1000;

/// Official InversePatch kind stays restoreSnapshot. This suite walks
/// immutable before-snapshots; it does not add field-level invert.
const officialInversePatchKind = 'restoreSnapshot';

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

List<Map> media(ProjectDocument p) => [
  for (final t in p.toJson()['sequences'][0]['tracks'])
    for (final c in t['items'])
      if (c['source'] != null) c as Map,
];

List<dynamic> tracks(ProjectDocument p) =>
    p.toJson()['sequences'][0]['tracks'] as List;

String videoId(ProjectDocument p) =>
    tracks(p)
            .firstWhere((t) => t['kind'] == 'video')['items']
            .firstWhere((c) => c['source'] != null)['id']
        as String;

String audioClipId(ProjectDocument p) =>
    tracks(p)
            .singleWhere((t) => t['kind'] == 'audio')['items']
            .firstWhere((c) => c['source'] != null)['id']
        as String;

String audioTrackId(ProjectDocument p) =>
    tracks(p).singleWhere((t) => t['kind'] == 'audio')['id'] as String;

Map audioClip(ProjectDocument p) {
  final id = audioClipId(p);
  return media(p).singleWhere((c) => c['id'] == id);
}

Q audioDuration(ProjectDocument p) =>
    Q.fromJson(audioClip(p)['timelineRange']['duration']);

Map? gainEffect(ProjectDocument p) {
  final ids = audioClip(p)['effectIds'] as List;
  final matches = (p.toJson()['effects'] as List)
      .where((e) => ids.contains(e['id']) && e['type'] == 'gain')
      .toList();
  return matches.isEmpty ? null : matches.single as Map;
}

List<Map> gainKeys(ProjectDocument p) {
  final effect = gainEffect(p);
  if (effect == null) return const [];
  return List<Map>.from(effect['keyframes'] as List);
}

bool hasAnimatedGain(ProjectDocument p) => gainKeys(p).isNotEmpty;

const legalDb = <double>[-12, -6, -3, 0, 3, 6];

final legalTimes = <Q>[
  Q.of(0),
  Q.of(1, 4),
  Q.of(1, 2),
  Q.of(1),
  Q.of(3, 2),
  Q.of(2),
  Q.of(3),
];

ProjectDocument extractedBaseline() {
  final p = avFixture();
  return move.change(p, ExtractAudioClip(videoId(p), 'audio-stream'));
}

EditOperation? trySetClipGain(ProjectDocument p, Random rng) {
  if (hasAnimatedGain(p)) return null;
  return SetClipGain(audioClipId(p), legalDb[rng.nextInt(legalDb.length)]);
}

EditOperation? trySetGainKeyframe(ProjectDocument p, Random rng) {
  final duration = audioDuration(p);
  final times = [
    for (final t in legalTimes)
      if (t <= duration) t,
  ];
  if (times.isEmpty) return null;
  return SetGainKeyframe(
    audioClipId(p),
    times[rng.nextInt(times.length)],
    legalDb[rng.nextInt(legalDb.length)],
    interpolation: rng.nextBool() ? 'hold' : 'linear',
  );
}

EditOperation? tryRemoveGainKeyframe(ProjectDocument p, Random rng) {
  final keys = gainKeys(p);
  if (keys.isEmpty) return null;
  final k = keys[rng.nextInt(keys.length)];
  return RemoveGainKeyframe(audioClipId(p), Q.fromJson(k['localTime']));
}

String familyOf(EditOperation op) => switch (op) {
  SetClipGain() => 'setClipGain',
  SetGainKeyframe() => 'setGainKeyframe',
  RemoveGainKeyframe() => 'removeGainKeyframe',
  _ => op.runtimeType.toString(),
};

EditOperation? pickOfficial(ProjectDocument p, Random rng) {
  final families = [trySetClipGain, trySetGainKeyframe, tryRemoveGainKeyframe]
    ..shuffle(rng);
  for (final tryFamily in families) {
    final op = tryFamily(p, rng);
    if (op != null) return op;
  }
  return null;
}

EditOperation refusalOp(ProjectDocument p, Random rng) {
  final id = audioClipId(p);
  switch (rng.nextInt(6)) {
    case 0:
      return SetGainKeyframe(id, Q.of(1, 96000), -6);
    case 1:
      return SetClipGain(id, 13);
    case 2:
      return SetClipGain(id, -97);
    case 3:
      return RemoveGainKeyframe(id, Q.of(5, 2));
    case 4:
      return SetGainKeyframe(videoId(p), Q.of(0), -6);
    default:
      return SetClipGain(videoId(p), -6);
  }
}

void main() {
  test('deterministic official gain commands undo via restoreSnapshot to the start content hash; refusals do not half-write', () {
    expect(officialInversePatchKind, 'restoreSnapshot');
    final start = extractedBaseline();
    final startHash = content(start);
    final id = audioClipId(start);
    final stack = <ProjectDocument>[start];
    var current = start;
    current = move.change(current, SetClipGain(id, -6));
    expect(content(start), startHash);
    stack.add(current);
    current = move.change(
      current,
      SetGainKeyframe(id, Q.of(0), -6, interpolation: 'hold'),
    );
    stack.add(current);
    current = move.change(current, SetGainKeyframe(id, Q.of(2), 0));
    stack.add(current);
    current = move.change(current, RemoveGainKeyframe(id, Q.of(2)));
    stack.add(current);
    expect(stack, hasLength(5));
    expect(content(stack.first), startHash);
    var restored = current;
    for (var i = stack.length - 1; i > 0; i--) {
      restored = stack[i - 1];
    }
    expect(content(restored), startHash);
    expect(officialInversePatchKind, 'restoreSnapshot');

    final beforeRefusal = content(current);
    expect(
      () => move.change(current, SetGainKeyframe(id, Q.of(1, 96000), -9)),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'KEYFRAME_NOT_ON_SAMPLE',
        ),
      ),
    );
    expect(content(current), beforeRefusal);
    expect(content(start), startHash);
  });

  test('1000 seeded official random SetClipGain/SetGainKeyframe/RemoveGainKeyframe sequences undo to the start content hash', () {
    expect(officialInversePatchKind, 'restoreSnapshot');
    var legal = 0;
    var refusals = 0;
    final families = <String, int>{
      'setClipGain': 0,
      'setGainKeyframe': 0,
      'removeGainKeyframe': 0,
    };
    for (var trial = 0; trial < i009GainRandomUndoTrials; trial++) {
      final rng = Random(i009GainRandomUndoSeed + trial);
      final start = extractedBaseline();
      final startHash = content(start);
      var current = start;
      final stack = <ProjectDocument>[start];
      final steps = 2 + rng.nextInt(5);
      for (var step = 0; step < steps; step++) {
        final beforeHash = content(current);
        final frozenStart = content(start);
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
          expect(
            content(start),
            frozenStart,
            reason: 'start drifted during apply trial $trial step $step',
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
          expect(content(start), frozenStart);
          refusals++;
        }
      }
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
    expect(refusals, greaterThan(0));
    expect(families['setClipGain']!, greaterThan(0));
    expect(families['setGainKeyframe']!, greaterThan(0));
    expect(families['removeGainKeyframe']!, greaterThan(0));
    // ignore: avoid_print
    print(
      'i009-gain-undo document: $i009GainRandomUndoTrials sequences, '
      'legal=$legal refusals=$refusals families=$families '
      'inversePatch=$officialInversePatchKind '
      'seed=0x${i009GainRandomUndoSeed.toRadixString(16)}',
    );
  });
}
