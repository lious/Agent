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

Q durOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['timelineRange']['duration']);

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

ProjectDocument attachCues(ProjectDocument p, List<CaptionCue> cues) =>
    move.change(p, SetCaptions(CaptionStore(cues)));

ProjectDocument attachDefaults(ProjectDocument p, List<CaptionCue> cues) {
  var out = attachCues(p, cues);
  final next = [
    for (final c in (out.toJson()['captions'] as List))
      CaptionCue.fromProjectJson(Map<String, dynamic>.from(c as Map)),
  ];
  return move.change(out, SetCaptions(CaptionStore(next)));
}

void main() {
  test('ripple TrimClip out matches RippleTrimClip caption interval crop/split/shift', () {
    var p = avFixture();
    final a = algebra.firstId(p);
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
    expect(durOf(viaFlag, a), durOf(viaCommand, a));
    List<Map> captions(ProjectDocument doc) =>
        (doc.toJson()['captions'] as List).cast<Map>();
    ({String text, String kind, Q start, Q duration}) geom(Map cue) => (
      text: cue['text'] as String,
      kind: cue['anchor']['kind'] as String,
      start: Q.fromJson(cue['timelineRange']['start']),
      duration: Q.fromJson(cue['timelineRange']['duration']),
    );
    void expectSameCues(ProjectDocument left, ProjectDocument right) {
      final aCues = captions(left).map(geom).toSet();
      final bCues = captions(right).map(geom).toSet();
      expect(aCues, bCues);
    }

    expectSameCues(viaFlag, viaCommand);
    final left = cueOf(viaFlag);
    final right = captions(viaFlag).singleWhere((c) => c['id'] != left['id']);
    expect(left['text'], 'hello');
    expect(Q.fromJson(left['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(left['timelineRange']['duration']), Q.of(5, 2));
    expect(right['text'], 'hello');
    expect(Q.fromJson(right['timelineRange']['start']), Q.of(5, 2));
    expect(Q.fromJson(right['timelineRange']['duration']), Q.of(1, 2));
  });

  test('ripple TrimClip in pins start, remaps source, and closes later content', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(2), 'right'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-abs',
        TimeRange(Q.of(5, 2), Q.of(1)),
        'later',
        manualFields: {'text', 'timing'},
      ),
    ]);
    // Force the later cue absolute so it uses interval shift, not host follow.
    final forced = (p.toJson()['captions'] as List).cast<Map>().single;
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(forced))
              .makeAbsolute(),
        ]),
      ),
    );
    expect(cueOf(p, 'cue-abs')['anchor']['kind'], 'absolute');
    final trimmed = move.change(p, TrimClip(a, 'in', Q.of(1, 2), ripple: true));
    expect(Q.fromJson(clipOf(trimmed, a)['timelineRange']['start']), Q.of(0));
    expect(durOf(trimmed, a), Q.of(3, 2));
    expect(
      Q.fromJson(clipOf(trimmed, 'right')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(
      Q.fromJson(cueOf(trimmed, 'cue-abs')['timelineRange']['start']),
      Q.of(2),
    );
    expect(cueOf(trimmed, 'cue-abs')['text'], 'later');
  });

  test('leave-gap TrimClip still does not shift later cues', () {
    var p = avFixture();
    final a = algebra.firstId(p);
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
    expect(
      Q.fromJson(clipOf(leave, 'right')['timelineRange']['start']),
      Q.of(2),
    );
    expect(
      Q.fromJson(cueOf(leave, 'cue-later')['timelineRange']['start']),
      Q.of(5, 2),
    );
  });

  test('uncovering a source cue refuses the whole ripple TrimClip; locked tracks refuse', () {
    var sourced = avFixture();
    final a = algebra.firstId(sourced);
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
    sourced = attachCues(sourced, [cue]);
    assertPure(sourced, () {
      expect(
        () =>
            move.change(sourced, TrimClip(a, 'out', Q.of(-1, 2), ripple: true)),
        code('ANCHOR_OUT_OF_RANGE'),
      );
    });
    expect(cueOf(sourced, 'cue-src')['text'], 'source-wide');

    var p = avFixture();
    p = attachDefaults(p, [
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(0), Q.of(7, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
    ]);
    final lockedJson = p.toJson();
    for (final t in lockedJson['sequences'][0]['tracks'] as List) {
      if (t['kind'] == 'caption') {
        t['locked'] = true;
      }
    }
    final locked = ProjectDocument.fromJson(
      jsonDecode(jsonEncode(lockedJson)) as Map<String, dynamic>,
    );
    assertPure(locked, () {
      expect(
        () =>
            move.change(locked, TrimClip(a, 'out', Q.of(-1, 2), ripple: true)),
        code('FIELD_LOCKED'),
      );
    });
  });
}
