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

ProjectDocument prepared({required bool extract}) {
  var p = avFixture();
  final a = algebra.firstId(p);
  if (extract) {
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
  }
  p = move.change(p, SplitClip(a, Q.of(1), 'right'));
  p = attachDefaults(p, [
    CaptionCue(
      'cue-left',
      TimeRange(Q.of(0), Q.of(1, 2)),
      'hello',
      manualFields: {'text', 'timing'},
    ),
    CaptionCue(
      'cue-later',
      TimeRange(Q.of(3, 2), Q.of(1, 5)),
      'stay',
      manualFields: {'text', 'timing'},
    ),
  ]);
  return p;
}

void main() {
  test('video-only LiftClips leaves an absolute remnant and does not shift later cues', () {
    final p = prepared(extract: false);
    final a = algebra.firstId(p);
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
    final payload = buildClipboard(p, [a]);
    expect(payload.toJson().containsKey('captions'), isFalse);
    final out = move.change(p, LiftClips([a]));
    expect(media(out).map((c) => c['id']), isNot(contains(a)));
    expect(startOf(out, 'right'), Q.of(1));
    expect(durOf(out, 'right'), Q.of(2));
    final remnant = cueOf(out, 'cue-left');
    expect(remnant['text'], 'hello');
    expect(remnant['anchor']['kind'], 'absolute');
    expect(Q.fromJson(remnant['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(remnant['timelineRange']['duration']), Q.of(1, 2));
    expect(cueOf(out, 'cue-later')['text'], 'stay');
    expect(
      Q.fromJson(cueOf(out, 'cue-later')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(startOf(p, 'right'), Q.of(1));
    final pasted = move.change(
      out,
      PasteClips(payload, at: Q.of(0), mode: 'reject'),
    );
    expect((pasted.toJson()['captions'] as List), hasLength(2));
    expect(cueOf(pasted, 'cue-left')['anchor']['kind'], 'absolute');
    expect(
      Q.fromJson(cueOf(pasted, 'cue-left')['timelineRange']['start']),
      Q.of(0),
    );
  });

  test('linked LiftClips removes both members, leaves a gap, and keeps later cues unmoved', () {
    final p = prepared(extract: true);
    final a = algebra.firstId(p);
    final out = move.change(p, LiftClips([a]));
    for (final kind in ['video', 'audio']) {
      final items = mediaOf(out, kind);
      expect(items, hasLength(1), reason: kind);
      expect(Q.fromJson(items.single['timelineRange']['start']), Q.of(1));
      expect(Q.fromJson(items.single['timelineRange']['duration']), Q.of(2));
    }
    final remnant = cueOf(out, 'cue-left');
    expect(remnant['text'], 'hello');
    expect(remnant['anchor']['kind'], 'absolute');
    expect(Q.fromJson(remnant['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(remnant['timelineRange']['duration']), Q.of(1, 2));
    expect(
      Q.fromJson(cueOf(out, 'cue-later')['timelineRange']['start']),
      Q.of(3, 2),
    );
  });

  test('leave-gap trim still does not close the hole', () {
    final p = prepared(extract: true);
    final a = algebra.firstId(p);
    final leave = move.change(p, TrimClip(a, 'out', Q.of(-1, 2)));
    expect(durOf(leave, a), Q.of(1, 2));
    expect(startOf(leave, 'right'), Q.of(1));
  });

  test('uncovering a source cue refuses; lifting a clipLocal-marker host still refuses', () {
    var sourced = avFixture();
    final a = algebra.firstId(sourced);
    sourced = move.change(sourced, ExtractAudioClip(a, 'audio-stream'));
    sourced = move.change(sourced, SplitClip(a, Q.of(1), 'right'));
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
    assertPure(sourced, () {
      expect(
        () => move.change(sourced, LiftClips([a])),
        code('ANCHOR_OUT_OF_RANGE'),
      );
    });
    expect(cueOf(sourced, 'cue-src')['text'], 'source-wide');

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
    expect((marked.toJson()['markers'] as List), hasLength(1));
    // leave-gap DeleteClip still converts the same marker, and is not LiftClips.
    final deleted = move.change(marked, DeleteClip(a));
    expect(deleted.toJson()['markers'].single['label'], 'on-a');
    expect(deleted.toJson()['markers'].single['anchor']['kind'], 'absolute');
    expect(Q.fromJson(deleted.toJson()['markers'].single['time']), Q.of(1, 5));
  });
}
