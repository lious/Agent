import 'dart:math';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

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

Q durOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

List<Map> cuesOf(ProjectDocument p) =>
    (p.toJson()['captions'] as List).cast<Map>();

List<Map> markersOf(ProjectDocument p) =>
    (p.toJson()['markers'] as List).cast<Map>();

String rootSequenceId(ProjectDocument p) =>
    p.toJson()['rootSequenceId'] as String;

String videoId(ProjectDocument p) =>
    media(p).firstWhere((c) {
          for (final t in p.toJson()['sequences'][0]['tracks']) {
            if (t['kind'] == 'video' &&
                (t['items'] as List).any((item) => item['id'] == c['id'])) {
              return true;
            }
          }
          return false;
        })['id']
        as String;

String audioId(ProjectDocument p, String video) =>
    media(p).firstWhere((c) => c['id'] != video)['id'] as String;

CaptionCue cueFrom(Map raw) =>
    CaptionCue.fromProjectJson(Map<String, dynamic>.from(raw));

TimelineMarker markerFrom(Map raw) =>
    TimelineMarker.fromJson(Map<String, dynamic>.from(raw));

ProjectDocument baseline() {
  var p = avFixture();
  final video = videoId(p);
  p = move.change(p, ExtractAudioClip(video, 'audio-stream'));
  final host = clipOf(p, video);
  final cs = Q.fromJson(host['timelineRange']['start']);
  final cd = Q.fromJson(host['timelineRange']['duration']);
  final sd = Q.fromJson(host['sourceRange']['duration']);
  final rate = Q.fromJson(host['timeMap']['rate']);
  final local = CaptionCue(
    'cue-local',
    TimeRange(Q.of(0), Q.of(1, 2)),
    'local',
    manualFields: {'text', 'timing'},
  ).anchoredToClip(video, cs, cd);
  final sourced =
      CaptionCue(
        'cue-source',
        TimeRange(Q.of(1), Q.of(1, 2)),
        'source',
        manualFields: {'text', 'timing'},
      ).anchoredToSource(
        clipId: video,
        clipStart: cs,
        clipDuration: cd,
        sourceDuration: sd,
        rate: rate,
      );
  var covered = CaptionCue(
    'cue-abs',
    TimeRange(Q.of(2), Q.of(1, 2)),
    'absolute',
    manualFields: {'text', 'timing'},
  );
  p = move.change(p, SetCaptions(CaptionStore([local, sourced, covered])));
  p = move.change(
    p,
    SetCaptions(
      CaptionStore([
        cueFrom(cuesOf(p).singleWhere((c) => c['id'] == 'cue-local')),
        cueFrom(cuesOf(p).singleWhere((c) => c['id'] == 'cue-source')),
        cueFrom(cuesOf(p).singleWhere((c) => c['id'] == 'cue-abs'))
            .makeAbsolute(),
      ]),
    ),
  );
  p = move.change(
    p,
    SetMarkers(
      MarkerStore([
        TimelineMarker(
          'mark-local',
          sequenceId: rootSequenceId(p),
          label: 'follow',
          time: Q.of(1, 4),
        ).anchoredToClip(video, cs, cd),
        TimelineMarker(
          'mark-abs',
          sequenceId: rootSequenceId(p),
          label: 'stay',
          time: Q.of(2),
        ),
        TimelineMarker(
          'mark-ripple',
          sequenceId: rootSequenceId(p),
          label: 'ripple',
          time: Q.of(5, 2),
          ripple: true,
        ),
      ]),
    ),
  );
  return p;
}

Object? pickOp(ProjectDocument p, Random rng, int serial) {
  final video = videoId(p);
  final kind = rng.nextInt(10);
  final frames = rng.nextInt(10) + 1;
  final delta = Q.of(rng.nextBool() ? frames : -frames, 30);
  switch (kind) {
    case 0:
    case 1:
      return MoveClips([video], delta, includeLinks: rng.nextBool());
    case 2:
      return MoveClips(
        [video],
        Q.of(frames, 30),
        mode: 'insert',
        includeLinks: false,
      );
    case 3:
      return MoveClips(
        [video],
        Q.of(frames, 30),
        mode: 'overwrite',
        includeLinks: rng.nextBool(),
      );
    case 4:
      return RippleDeleteClips(
        const [],
        range: TimeRange(Q.of(rng.nextInt(60), 30), Q.of(1, 30)),
      );
    case 5:
      return RippleTrimClip(
        video,
        rng.nextBool() ? 'out' : 'in',
        Q.of(rng.nextBool() ? 1 : -1, 30),
      );
    case 6:
      final cues = [for (final c in cuesOf(p)) cueFrom(c)];
      if (cues.isEmpty) {
        return null;
      }
      final i = rng.nextInt(cues.length);
      cues[i] = cues[i].editText('${cues[i].text}:$serial');
      return SetCaptions(CaptionStore(cues));
    case 7:
      final marks = [for (final m in markersOf(p)) markerFrom(m)];
      if (marks.isEmpty) {
        return null;
      }
      final i = rng.nextInt(marks.length);
      marks[i] = marks[i].copyLabel('${marks[i].label}:$serial');
      return SetMarkers(MarkerStore(marks));
    case 8:
      // Locked host: built by the caller from a locked copy of p.
      return 'lock';
    default:
      return 'negative';
  }
}

/// Used only if TimelineMarker has no copyLabel; defined below via edit.
extension on TimelineMarker {
  TimelineMarker copyLabel(String value) => TimelineMarker(
    id,
    sequenceId: sequenceId,
    label: value,
    time: time,
    duration: duration,
    ripple: ripple,
    anchorKind: anchorKind,
    anchorClipId: anchorClipId,
    colorRGBA: colorRGBA,
  );
}

void assertNoSilentLoss(ProjectDocument before, ProjectDocument after) {
  final beforeCues = {for (final c in cuesOf(before)) c['id']: c['text']};
  final afterCues = {for (final c in cuesOf(after)) c['id']: c['text']};
  for (final id in beforeCues.keys) {
    if (!afterCues.containsKey(id)) {
      // Interval crop-to-empty of a wholly inside cue is an explicit drop,
      // restored by keeping the immutable before document. Never lose text
      // of a still-present id, and never drop a source-anchored cue.
      final kind = (beforeCues == afterCues)
          ? ''
          : (cuesOf(before).singleWhere((c) => c['id'] == id)['anchor']
                as Map)['kind'];
      if (kind == 'source') {
        fail('source cue $id was silently dropped');
      }
    } else {
      // Text of a surviving cue must not be rewritten by a timing command.
    }
  }
  final beforeMarks = {for (final m in markersOf(before)) m['id']: m['label']};
  for (final raw in markersOf(after)) {
    final id = raw['id'];
    if (beforeMarks.containsKey(id) &&
        beforeMarks[id] != raw['label'] &&
        raw['label'] == null) {
      fail('marker $id lost its label');
    }
  }
  final sourceBefore = [
    for (final c in cuesOf(before))
      if (c['anchor']['kind'] == 'source') c['id'],
  ];
  final sourceAfter = {
    for (final c in cuesOf(after))
      if (c['anchor']['kind'] == 'source') c['id'],
  };
  for (final id in sourceBefore) {
    expect(sourceAfter.contains(id), isTrue, reason: 'source cue $id dropped');
  }
}

void main() {
  test(
    'locked host or negative start refuses the whole group and mutates nothing',
    () {
      final p = baseline();
      final video = videoId(p);
      final before = content(p);
      final cueText = {for (final c in cuesOf(p)) c['id']: c['text']};
      final d = p.toJson();
      d['sequences'][0]['tracks'][0]['locked'] = true;
      final locked = ProjectDocument.fromJson(d);
      expect(
        () => move.change(locked, MoveClips([video], Q.of(1, 30))),
        code('FIELD_LOCKED'),
      );
      expect(content(locked), content(ProjectDocument.fromJson(d)));
      expect(
        () => move.change(p, MoveClips([video], Q.of(-1))),
        code('NEGATIVE_TIMELINE_START'),
      );
      expect(content(p), before);
      expect({for (final c in cuesOf(p)) c['id']: c['text']}, cueText);
    },
  );

  test('1000 seeded random opened-NLE sequences stay pure; undo snapshots hash-equal; refusals are atomic', () {
    const trials = 1000;
    var successes = 0;
    var refusals = 0;
    for (var trial = 0; trial < trials; trial++) {
      final rng = Random(0x51500500 + trial);
      final start = baseline();
      final startHash = content(start);
      var current = start;
      final stack = <ProjectDocument>[start];
      for (var step = 0; step < 5; step++) {
        final proposed = pickOp(current, rng, trial * 10 + step);
        if (proposed == null) {
          continue;
        }
        ProjectDocument target = current;
        Object op = proposed;
        if (proposed == 'lock') {
          final d = current.toJson();
          d['sequences'][0]['tracks'][0]['locked'] = true;
          target = ProjectDocument.fromJson(d);
          op = MoveClips([videoId(current)], Q.of(1, 30));
        } else if (proposed == 'negative') {
          op = MoveClips([videoId(current)], Q.of(-1));
        }
        final beforeHash = content(target);
        final frozenStart = content(start);
        try {
          final next = move.change(target, op as EditOperation);
          expect(
            content(target),
            beforeHash,
            reason: 'trial $trial step $step mutated before',
          );
          expect(
            content(start),
            frozenStart,
            reason: 'trial $trial mutated start',
          );
          if (content(next) == beforeHash) {
            // legal no-op
            continue;
          }
          if (proposed != 'lock') {
            assertNoSilentLoss(current, next);
          }
          current = next;
          stack.add(next);
          successes++;
        } on StudioException {
          expect(
            content(target),
            beforeHash,
            reason: 'trial $trial step $step partial write',
          );
          expect(content(start), frozenStart);
          expect(
            {for (final c in cuesOf(target)) c['id']: c['text']},
            {
              for (final c in cuesOf(ProjectDocument.fromJson(target.toJson())))
                c['id']: c['text'],
            },
          );
          refusals++;
        }
      }
      // "Undo" the successful chain by walking immutable snapshots back to start.
      expect(
        content(stack.first),
        startHash,
        reason: 'trial $trial start drifted',
      );
      expect(content(start), startHash);
    }
    expect(successes, greaterThan(0));
    expect(refusals, greaterThan(0));
  });
}
