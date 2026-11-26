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

({String text, String kind, Q start, Q duration}) cueGeom(Map cue) => (
  text: cue['text'] as String,
  kind: cue['anchor']['kind'] as String,
  start: Q.fromJson(cue['timelineRange']['start']),
  duration: Q.fromJson(cue['timelineRange']['duration']),
);

ProjectDocument prepared({required bool extract}) {
  var p = avFixture();
  final a = algebra.firstId(p);
  if (extract) {
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
  }
  p = move.change(p, SplitClip(a, Q.of(1), 'right'));
  return attachDefaults(p, [
    CaptionCue(
      'cue-1',
      TimeRange(Q.of(0), Q.of(5, 2)),
      'hello',
      manualFields: {'text', 'timing'},
    ),
  ]);
}

void main() {
  test(
    'video-only ripple DeleteClip matches RippleDeleteClips caption geometry',
    () {
      final p = prepared(extract: false);
      final a = algebra.firstId(p);
      final viaCommand = move.change(p, RippleDeleteClips([a]));
      final viaFlag = move.change(p, DeleteClip(a, ripple: true));
      expect(media(viaFlag).map((c) => c['id']), isNot(contains(a)));
      expect(startOf(viaFlag, 'right'), Q.of(0));
      expect(durOf(viaFlag, 'right'), Q.of(2));
      expect(
        (viaFlag.toJson()['captions'] as List).cast<Map>().map(cueGeom).toSet(),
        (viaCommand.toJson()['captions'] as List)
            .cast<Map>()
            .map(cueGeom)
            .toSet(),
      );
      final remnant = (viaFlag.toJson()['captions'] as List).cast<Map>().single;
      expect(remnant['text'], 'hello');
      expect(Q.fromJson(remnant['timelineRange']['start']), Q.of(0));
      expect(Q.fromJson(remnant['timelineRange']['duration']), Q.of(3, 2));
    },
  );

  test('linked ripple DeleteClip removes both members and matches RippleDeleteClips cues', () {
    final p = prepared(extract: true);
    final a = algebra.firstId(p);
    final viaCommand = move.change(p, RippleDeleteClips([a]));
    final viaFlag = move.change(p, DeleteClip(a, ripple: true));
    for (final kind in ['video', 'audio']) {
      final items = mediaOf(viaFlag, kind);
      expect(items, hasLength(1), reason: kind);
      expect(Q.fromJson(items.single['timelineRange']['start']), Q.of(0));
      expect(Q.fromJson(items.single['timelineRange']['duration']), Q.of(2));
    }
    expect(
      (viaFlag.toJson()['captions'] as List).cast<Map>().map(cueGeom).toSet(),
      (viaCommand.toJson()['captions'] as List)
          .cast<Map>()
          .map(cueGeom)
          .toSet(),
    );
    final remnant = (viaFlag.toJson()['captions'] as List).cast<Map>().single;
    expect(remnant['text'], 'hello');
    expect(Q.fromJson(remnant['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(remnant['timelineRange']['duration']), Q.of(3, 2));
  });

  test('leave-gap delete and MoveClip stay refused; leave-gap trim still leaves a gap', () {
    final p = prepared(extract: true);
    final a = algebra.firstId(p);
    final leave = move.change(p, TrimClip(a, 'out', Q.of(-1, 2)));
    expect(durOf(leave, a), Q.of(1, 2));
    expect(startOf(leave, 'right'), Q.of(1));
    assertPure(p, () {
      expect(
        () => move.change(p, MoveClip(a, Q.of(1))),
        code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
      );
      expect(
        () => move.change(p, DeleteClip(a)),
        code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
      );
    });
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
        () => move.change(sourced, DeleteClip(a, ripple: true)),
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
  });
}
