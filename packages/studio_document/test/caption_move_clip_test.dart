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

Q durOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

List<Map> mediaOf(ProjectDocument p, String kind) => [
  for (final c in (p.toJson()['sequences'][0]['tracks'] as List).singleWhere(
    (t) => t['kind'] == kind,
  )['items'])
    if (c['source'] != null) c as Map,
];

Map cueOf(ProjectDocument p, [String id = 'cue-1']) =>
    (p.toJson()['captions'] as List).cast<Map>().singleWhere(
      (c) => c['id'] == id,
    );

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

void main() {
  test('video-only MoveClip translates a clipLocal cue and leaves the source gap; absolute stays', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = attachDefaults(p, [
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
      CaptionCue(
        'cue-abs',
        TimeRange(Q.of(2), Q.of(1, 5)),
        'stay',
        manualFields: {'text', 'timing'},
      ),
    ]);
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(
            Map<String, dynamic>.from(cueOf(p, 'cue-1')),
          ),
          CaptionCue.fromProjectJson(
            Map<String, dynamic>.from(cueOf(p, 'cue-abs')),
          ).makeAbsolute(),
        ]),
      ),
    );
    expect(cueOf(p, 'cue-1')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-abs')['anchor']['kind'], 'absolute');
    final out = move.change(p, MoveClip(a, Q.of(1, 2)));
    expect(startOf(out, a), Q.of(1, 2));
    expect(durOf(out, a), Q.of(3));
    expect(cueOf(out, 'cue-1')['text'], 'hello');
    expect(cueOf(out, 'cue-1')['anchor']['kind'], 'clipLocal');
    expect(cueOf(out, 'cue-1')['anchor']['clipId'], a);
    expect(
      Q.fromJson(cueOf(out, 'cue-1')['timelineRange']['start']),
      Q.of(1, 2),
    );
    expect(
      Q.fromJson(cueOf(out, 'cue-1')['timelineRange']['duration']),
      Q.of(1, 2),
    );
    expect(cueOf(out, 'cue-abs')['text'], 'stay');
    expect(cueOf(out, 'cue-abs')['anchor']['kind'], 'absolute');
    expect(
      Q.fromJson(cueOf(out, 'cue-abs')['timelineRange']['start']),
      Q.of(2),
    );
  });

  test('linked MoveClip shifts both members and follows the cue', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
    ]);
    final out = move.change(p, MoveClip(a, Q.of(1, 2)));
    for (final kind in ['video', 'audio']) {
      final items = mediaOf(out, kind);
      expect(items, hasLength(1), reason: kind);
      expect(Q.fromJson(items.single['timelineRange']['start']), Q.of(1, 2));
    }
    expect(cueOf(out)['text'], 'hello');
    expect(Q.fromJson(cueOf(out)['timelineRange']['start']), Q.of(1, 2));
    expect(cueOf(out)['anchor']['kind'], 'clipLocal');
  });

  test('collision refuses atomically; leave-gap trim still does not close the hole', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
    ]);
    assertPure(p, () {
      expect(() => move.change(p, MoveClip(a, Q.of(1, 2))), code('COLLISION'));
    });
    final leave = move.change(p, TrimClip(a, 'out', Q.of(-1, 2)));
    expect(durOf(leave, a), Q.of(1, 2));
    expect(startOf(leave, 'right'), Q.of(1));
  });

  test('source cue reprojects with the host; lifting a clipLocal-marker host still refuses', () {
    var sourced = avFixture();
    final a = algebra.firstId(sourced);
    sourced = move.change(sourced, ExtractAudioClip(a, 'audio-stream'));
    final host = clipOf(sourced, a);
    final cue =
        CaptionCue(
          'cue-src',
          TimeRange(Q.of(0), Q.of(1)),
          'source-wide',
          manualFields: {'text', 'timing'},
        ).anchoredToSource(
          clipId: a,
          clipStart: Q.fromJson(host['timelineRange']['start']),
          clipDuration: Q.fromJson(host['timelineRange']['duration']),
          sourceDuration: Q.fromJson(host['sourceRange']['duration']),
          rate: Q.fromJson(host['timeMap']['rate']),
        );
    sourced = move.change(sourced, SetCaptions(CaptionStore([cue])));
    final moved = move.change(sourced, MoveClip(a, Q.of(1, 2)));
    expect(startOf(moved, a), Q.of(1, 2));
    expect(cueOf(moved, 'cue-src')['anchor']['kind'], 'source');
    expect(cueOf(moved, 'cue-src')['text'], 'source-wide');
    expect(
      Q.fromJson(cueOf(moved, 'cue-src')['timelineRange']['start']),
      Q.of(1, 2),
    );

    var marked = avFixture();
    marked = move.change(marked, ExtractAudioClip(a, 'audio-stream'));
    marked = attachDefaults(marked, [
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
    ]);
    marked = move.change(
      marked,
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-local',
            sequenceId: 'sequence-main',
            label: 'on-a',
            time: Q.of(1, 5),
            anchorKind: 'clipLocal',
            anchorClipId: a,
          ),
        ]),
      ),
    );
    assertPure(marked, () {
      expect(() => move.change(marked, LiftClips([a])), code('REF_NOT_FOUND'));
    });
    final followed = move.change(marked, MoveClip(a, Q.of(1, 2)));
    expect(followed.toJson()['markers'].single['label'], 'on-a');
    expect(followed.toJson()['markers'].single['anchor']['kind'], 'clipLocal');
    expect(
      Q.fromJson(followed.toJson()['markers'].single['time']),
      Q.of(7, 10),
    );
  });
}
