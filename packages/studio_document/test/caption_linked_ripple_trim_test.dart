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

void main() {
  test('linked ripple TrimClip shortens both members and matches RippleTrimClip cues', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(0), Q.of(7, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
    ]);
    final viaCommand = move.change(p, RippleTrimClip(a, 'out', Q.of(-1, 2)));
    final viaFlag = move.change(
      p,
      TrimClip(a, 'out', Q.of(-1, 2), ripple: true),
    );
    expect(durOf(viaFlag, a), Q.of(5, 2));
    for (final kind in ['video', 'audio']) {
      final items = mediaOf(viaFlag, kind);
      expect(items, hasLength(1), reason: kind);
      expect(Q.fromJson(items.single['timelineRange']['duration']), Q.of(5, 2));
    }
    expect(
      (viaFlag.toJson()['captions'] as List).cast<Map>().map(cueGeom).toSet(),
      (viaCommand.toJson()['captions'] as List)
          .cast<Map>()
          .map(cueGeom)
          .toSet(),
    );
    final left = cueOf(viaFlag);
    final right = (viaFlag.toJson()['captions'] as List)
        .cast<Map>()
        .singleWhere((c) => c['id'] != left['id']);
    expect(left['text'], 'hello');
    expect(Q.fromJson(left['timelineRange']['duration']), Q.of(5, 2));
    expect(right['text'], 'hello');
    expect(Q.fromJson(right['timelineRange']['start']), Q.of(5, 2));
    expect(Q.fromJson(right['timelineRange']['duration']), Q.of(1, 2));
  });

  test(
    'leave-gap trim and MoveClip stay unchanged; ripple delete still refuses',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
      p = move.change(p, SplitClip(a, Q.of(2), 'right'));
      p = attachDefaults(p, [
        CaptionCue(
          'cue-later',
          TimeRange(Q.of(5, 2), Q.of(1, 5)),
          'stay',
          manualFields: {'text', 'timing'},
        ),
      ]);
      final leave = move.change(p, TrimClip(a, 'out', Q.of(-1, 2)));
      expect(durOf(leave, a), Q.of(3, 2));
      expect(startOf(leave, 'right'), Q.of(2));
      expect(
        Q.fromJson(cueOf(leave, 'cue-later')['timelineRange']['start']),
        Q.of(5, 2),
      );
      assertPure(p, () {
        expect(
          () => move.change(p, MoveClip(a, Q.of(1))),
          code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
        );
        expect(
          () => move.change(p, DeleteClip(a, ripple: true)),
          code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
        );
      });
    },
  );

  test('uncovering a source cue refuses; lifting a clipLocal-marker host still refuses', () {
    var sourced = avFixture();
    final a = algebra.firstId(sourced);
    sourced = move.change(sourced, ExtractAudioClip(a, 'audio-stream'));
    final host = clipOf(sourced, a);
    final cue =
        CaptionCue(
          'cue-src',
          TimeRange(Q.of(0), Q.of(3)),
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
        () =>
            move.change(sourced, TrimClip(a, 'out', Q.of(-1, 2), ripple: true)),
        code('ANCHOR_OUT_OF_RANGE'),
      );
    });
    expect(cueOf(sourced, 'cue-src')['text'], 'source-wide');

    var p = avFixture();
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
    ]);
    p = move.change(
      p,
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
    assertPure(p, () {
      expect(() => move.change(p, LiftClips([a])), code('REF_NOT_FOUND'));
    });
    expect((p.toJson()['markers'] as List), hasLength(1));
  });
}
