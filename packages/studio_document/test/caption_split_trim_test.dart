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

Map cueOf(ProjectDocument p, [String id = 'cue-1']) =>
    (p.toJson()['captions'] as List).cast<Map>().singleWhere(
      (c) => c['id'] == id,
    );

Q cueStart(ProjectDocument p, [String id = 'cue-1']) =>
    Q.fromJson(cueOf(p, id)['timelineRange']['start']);

Q cueDur(ProjectDocument p, [String id = 'cue-1']) =>
    Q.fromJson(cueOf(p, id)['timelineRange']['duration']);

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
  test(
    'split keeps a left clipLocal cue at the same time and does not split text',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = attachDefaults(p, [
        CaptionCue(
          'cue-1',
          TimeRange(Q.of(0), Q.of(1, 2)),
          'hello',
          manualFields: {'text', 'timing'},
        ),
      ]);
      expect(cueOf(p)['anchor']['kind'], 'clipLocal');
      final out = move.change(p, SplitClip(a, Q.of(1), 'right'));
      expect(cueOf(out)['text'], 'hello');
      expect(cueOf(out)['anchor']['kind'], 'clipLocal');
      expect(cueOf(out)['anchor']['clipId'], a);
      expect(cueStart(out), Q.of(0));
      expect(cueDur(out), Q.of(1, 2));
      expect(durOf(out, a), Q.of(1));
      expect(startOf(out, 'right'), Q.of(1));
      expect((out.toJson()['captions'] as List), hasLength(1));
      expect(p.toJson()['assets'], out.toJson()['assets']);
    },
  );

  test(
    'split rebinds a right clipLocal cue to the new remnant; times unchanged',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = attachDefaults(p, [
        CaptionCue(
          'cue-1',
          TimeRange(Q.of(2), Q.of(1, 2)),
          'right-side',
          manualFields: {'text', 'timing'},
        ),
      ]);
      final out = move.change(p, SplitClip(a, Q.of(1), 'right'));
      expect(cueOf(out)['text'], 'right-side');
      expect(cueOf(out)['anchor']['kind'], 'clipLocal');
      expect(cueOf(out)['anchor']['clipId'], 'right');
      expect(cueStart(out), Q.of(2));
      expect(cueDur(out), Q.of(1, 2));
    },
  );

  test(
    'split of a spanning cue makes it absolute and does not split or drop text',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = attachDefaults(p, [
        CaptionCue(
          'cue-1',
          TimeRange(Q.of(1, 2), Q.of(1)),
          'spans-cut',
          manualFields: {'text', 'timing'},
        ),
      ]);
      expect(cueOf(p)['anchor']['kind'], 'clipLocal');
      final out = move.change(p, SplitClip(a, Q.of(1), 'right'));
      expect(cueOf(out)['text'], 'spans-cut');
      expect(cueOf(out)['anchor']['kind'], 'absolute');
      expect(cueStart(out), Q.of(1, 2));
      expect(cueDur(out), Q.of(1));
      expect((out.toJson()['captions'] as List), hasLength(1));
      expect(content(p), content(ProjectDocument.fromJson(p.toJson())));
    },
  );

  test('split rebinds a source cue wholly on the right; a spanning source cue refuses', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    final host = clipOf(p, a);
    final onRight =
        CaptionCue(
          'cue-src',
          TimeRange(Q.of(2), Q.of(1, 2)),
          'source-right',
          manualFields: {'text', 'timing'},
        ).anchoredToSource(
          clipId: a,
          clipStart: Q.fromJson(host['timelineRange']['start']),
          clipDuration: Q.fromJson(host['timelineRange']['duration']),
          sourceDuration: Q.fromJson(host['sourceRange']['duration']),
          rate: Q.fromJson(host['timeMap']['rate']),
        );
    p = attachCues(p, [onRight]);
    final out = move.change(p, SplitClip(a, Q.of(1), 'right'));
    expect(cueOf(out, 'cue-src')['anchor']['kind'], 'source');
    expect(cueOf(out, 'cue-src')['anchor']['clipId'], 'right');
    expect(cueStart(out, 'cue-src'), Q.of(2));
    expect(cueOf(out, 'cue-src')['text'], 'source-right');

    var spanned = avFixture();
    final host2 = clipOf(spanned, a);
    final across =
        CaptionCue(
          'cue-span',
          TimeRange(Q.of(1, 2), Q.of(1)),
          'source-span',
          manualFields: {'text', 'timing'},
        ).anchoredToSource(
          clipId: a,
          clipStart: Q.fromJson(host2['timelineRange']['start']),
          clipDuration: Q.fromJson(host2['timelineRange']['duration']),
          sourceDuration: Q.fromJson(host2['sourceRange']['duration']),
          rate: Q.fromJson(host2['timeMap']['rate']),
        );
    spanned = attachCues(spanned, [across]);
    assertPure(spanned, () {
      expect(
        () => move.change(spanned, SplitClip(a, Q.of(1), 'right')),
        code('ANCHOR_OUT_OF_RANGE'),
      );
    });
    expect(cueOf(spanned, 'cue-span')['text'], 'source-span');
    expect(cueOf(spanned, 'cue-span')['anchor']['kind'], 'source');
  });

  test('split rebinds a clipLocal marker on the right; a spanning marker becomes absolute', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(
      p,
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-right',
            sequenceId: 'sequence-main',
            label: 'on-right',
            time: Q.of(2),
            anchorKind: 'clipLocal',
            anchorClipId: a,
          ),
          TimelineMarker(
            'mark-span',
            sequenceId: 'sequence-main',
            label: 'span',
            time: Q.of(1, 2),
            duration: Q.of(1),
            anchorKind: 'clipLocal',
            anchorClipId: a,
          ),
        ]),
      ),
    );
    final out = move.change(p, SplitClip(a, Q.of(1), 'right'));
    final marks = {for (final m in out.toJson()['markers']) m['id']: m};
    expect(marks['mark-right']['anchor']['kind'], 'clipLocal');
    expect(marks['mark-right']['anchor']['clipId'], 'right');
    expect(Q.fromJson(marks['mark-right']['time']), Q.of(2));
    expect(marks['mark-span']['anchor']['kind'], 'absolute');
    expect(Q.fromJson(marks['mark-span']['time']), Q.of(1, 2));
    expect(marks['mark-span']['label'], 'span');
  });

  test('leave-gap out trim keeps a covered cue; a crossing cue leaves an absolute remnant in the gap', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = attachDefaults(p, [
      CaptionCue(
        'cue-keep',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'keep',
        manualFields: {'text', 'timing'},
      ),
      CaptionCue(
        'cue-cross',
        TimeRange(Q.of(2), Q.of(1)),
        'cross',
        manualFields: {'text', 'timing'},
      ),
    ]);
    final out = move.change(p, TrimClip(a, 'out', Q.of(-1, 2)));
    expect(durOf(out, a), Q.of(5, 2));
    expect(Q.fromJson(out.toJson()['sequences'][0]['duration']), Q.of(3));
    expect(cueOf(out, 'cue-keep')['text'], 'keep');
    expect(cueOf(out, 'cue-keep')['anchor']['kind'], 'clipLocal');
    expect(cueStart(out, 'cue-keep'), Q.of(0));
    expect(cueOf(out, 'cue-cross')['text'], 'cross');
    expect(cueOf(out, 'cue-cross')['anchor']['kind'], 'clipLocal');
    expect(cueOf(out, 'cue-cross')['anchor']['clipId'], a);
    expect(cueStart(out, 'cue-cross'), Q.of(2));
    expect(cueDur(out, 'cue-cross'), Q.of(1, 2));
    final gap = (out.toJson()['captions'] as List).cast<Map>().singleWhere(
      (c) => c['anchor']['kind'] == 'absolute',
    );
    expect(gap['text'], 'cross');
    expect(Q.fromJson(gap['timelineRange']['start']), Q.of(5, 2));
    expect(Q.fromJson(gap['timelineRange']['duration']), Q.of(1, 2));
    expect((out.toJson()['captions'] as List), hasLength(3));
  });

  test('leave-gap in trim keeps remaining cue times; the vacated head becomes absolute', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = attachDefaults(p, [
      CaptionCue(
        'cue-cross',
        TimeRange(Q.of(0), Q.of(1)),
        'head',
        manualFields: {'text', 'timing'},
      ),
    ]);
    final out = move.change(p, TrimClip(a, 'in', Q.of(1, 2)));
    expect(startOf(out, a), Q.of(1, 2));
    expect(durOf(out, a), Q.of(5, 2));
    expect(Q.fromJson(out.toJson()['sequences'][0]['duration']), Q.of(3));
    final captions = (out.toJson()['captions'] as List).cast<Map>();
    expect(captions, hasLength(2));
    final abs = captions.singleWhere((c) => c['anchor']['kind'] == 'absolute');
    final local = captions.singleWhere(
      (c) => c['anchor']['kind'] == 'clipLocal',
    );
    expect(abs['text'], 'head');
    expect(Q.fromJson(abs['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(abs['timelineRange']['duration']), Q.of(1, 2));
    expect(local['text'], 'head');
    expect(Q.fromJson(local['timelineRange']['start']), Q.of(1, 2));
    expect(Q.fromJson(local['timelineRange']['duration']), Q.of(1, 2));
    expect(local['anchor']['clipId'], a);
  });

  test('leave-gap trim leaves later clips and absolute cues unmoved; source uncover refuses', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(2), 'tail'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-abs',
        TimeRange(Q.of(5, 2), Q.of(1, 5)),
        'stay',
        manualFields: {'text', 'timing'},
      ),
    ]);
    p = move.change(
      p,
      SetCaptions(
        CaptionStore([
          CaptionCue.fromProjectJson(
            Map<String, dynamic>.from(cueOf(p, 'cue-abs')),
          ).makeAbsolute(),
        ]),
      ),
    );
    final trimmed = move.change(p, TrimClip(a, 'out', Q.of(-1, 2)));
    expect(startOf(trimmed, 'tail'), Q.of(2));
    expect(cueStart(trimmed, 'cue-abs'), Q.of(5, 2));
    expect(cueOf(trimmed, 'cue-abs')['anchor']['kind'], 'absolute');

    var sourced = avFixture();
    final host = clipOf(sourced, a);
    final cue =
        CaptionCue(
          'cue-src',
          TimeRange(Q.of(0), Q.of(2)),
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
        () => move.change(sourced, TrimClip(a, 'out', Q.of(-2))),
        code('ANCHOR_OUT_OF_RANGE'),
      );
    });
    expect(cueOf(sourced, 'cue-src')['text'], 'source-wide');
  });

  test('video-only ripple TrimClip with captions uses the interval transform; lifting a clipLocal-marker host still refuses', () {
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
    final trimmed = move.change(
      p,
      TrimClip(a, 'out', Q.of(-1, 2), ripple: true),
    );
    expect(durOf(trimmed, a), Q.of(5, 2));
    final left = cueOf(trimmed);
    final right = (trimmed.toJson()['captions'] as List)
        .cast<Map>()
        .singleWhere((c) => c['id'] != left['id']);
    expect(left['text'], 'hello');
    expect(Q.fromJson(left['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(left['timelineRange']['duration']), Q.of(5, 2));
    expect(right['text'], 'hello');
    expect(Q.fromJson(right['timelineRange']['start']), Q.of(5, 2));
    expect(Q.fromJson(right['timelineRange']['duration']), Q.of(1, 2));
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

  test('linked AV split and leave-gap trim keep captions on both members', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    expect(p.toJson()['linkGroups'], isNotEmpty);
    p = attachDefaults(p, [
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(1, 5), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
    ]);
    assertPure(p, () {
      expect(
        () => move.change(p, MoveClip(a, Q.of(1))),
        code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
      );
      expect(
        () => move.change(p, TrimClip(a, 'out', Q.of(-1, 2), ripple: true)),
        code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
      );
    });
    final split = move.change(p, SplitClip(a, Q.of(1), 'right'));
    final splitTracks = split.toJson()['sequences'][0]['tracks'] as List;
    List<Map> mediaOf(List tracks, String kind) => [
      for (final c in tracks.singleWhere((t) => t['kind'] == kind)['items'])
        if (c['source'] != null) c as Map,
    ];
    expect(mediaOf(splitTracks, 'video'), hasLength(2));
    expect(mediaOf(splitTracks, 'audio'), hasLength(2));
    expect(cueOf(split)['text'], 'hello');
    expect(cueOf(split)['anchor']['kind'], 'clipLocal');
    expect(cueOf(split)['anchor']['clipId'], a);
    expect(cueStart(split), Q.of(1, 5));
    expect(cueDur(split), Q.of(1, 2));

    final trimmed = move.change(split, TrimClip(a, 'out', Q.of(-1, 2)));
    expect(durOf(trimmed, a), Q.of(1, 2));
    final afterTracks = trimmed.toJson()['sequences'][0]['tracks'] as List;
    for (final kind in ['video', 'audio']) {
      final items = mediaOf(afterTracks, kind);
      expect(items, hasLength(2), reason: kind);
      final left = items.singleWhere(
        (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(0),
      );
      final right = items.singleWhere(
        (c) => Q.fromJson(c['timelineRange']['start']) == Q.of(1),
      );
      expect(Q.fromJson(left['timelineRange']['duration']), Q.of(1, 2));
      expect(Q.fromJson(right['timelineRange']['duration']), Q.of(2));
    }
    final captions = (trimmed.toJson()['captions'] as List).cast<Map>();
    expect(captions, hasLength(2));
    final local = captions.singleWhere(
      (c) => c['anchor']['kind'] == 'clipLocal',
    );
    final abs = captions.singleWhere((c) => c['anchor']['kind'] == 'absolute');
    expect(local['text'], 'hello');
    expect(local['anchor']['clipId'], a);
    expect(Q.fromJson(local['timelineRange']['start']), Q.of(1, 5));
    expect(Q.fromJson(local['timelineRange']['duration']), Q.of(3, 10));
    expect(abs['text'], 'hello');
    expect(Q.fromJson(abs['timelineRange']['start']), Q.of(1, 2));
    expect(Q.fromJson(abs['timelineRange']['duration']), Q.of(1, 5));
  });
}
