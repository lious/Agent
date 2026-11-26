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

CaptionCue toSource(ProjectDocument p, CaptionCue cue, String clipId) {
  final host = clipOf(p, clipId);
  return cue.anchoredToSource(
    clipId: clipId,
    clipStart: Q.fromJson(host['timelineRange']['start']),
    clipDuration: Q.fromJson(host['timelineRange']['duration']),
    sourceDuration: Q.fromJson(host['sourceRange']['duration']),
    rate: Q.fromJson(host['timeMap']['rate']),
  );
}

void main() {
  test('overwrite move follows the moving cue, rebinds a dest remnant, and keeps carved text as absolute', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-left',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
      CaptionCue(
        'cue-hole',
        TimeRange(Q.of(3, 2), Q.of(1, 4)),
        'carved',
        manualFields: {'text', 'timing'},
      ),
      CaptionCue(
        'cue-later',
        TimeRange(Q.of(2), Q.of(1, 5)),
        'stay',
        manualFields: {'text', 'timing'},
      ),
    ]);
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-hole')['anchor']['clipId'], 'right');
    p = move.change(p, MoveClips([a], Q.of(1), mode: 'overwrite'));
    expect(startOf(p, a), Q.of(1));
    expect(startOf(p, 'right'), Q.of(2));
    expect(durOf(p, 'right'), Q.of(1));
    expect(cueOf(p, 'cue-left')['text'], 'hello');
    expect(cueOf(p, 'cue-left')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-left')['anchor']['clipId'], a);
    expect(Q.fromJson(cueOf(p, 'cue-left')['timelineRange']['start']), Q.of(1));
    expect(cueOf(p, 'cue-hole')['text'], 'carved');
    expect(cueOf(p, 'cue-hole')['anchor']['kind'], 'absolute');
    expect(
      Q.fromJson(cueOf(p, 'cue-hole')['timelineRange']['start']),
      Q.of(3, 2),
    );
    expect(cueOf(p, 'cue-later')['text'], 'stay');
    expect(cueOf(p, 'cue-later')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-later')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-later')['timelineRange']['start']),
      Q.of(2),
    );
  });

  test('overwrite move that would overlap a followed cue and a dest remnant is CAPTION_OVERLAP', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-left',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
      CaptionCue(
        'cue-hole',
        TimeRange(Q.of(1), Q.of(1, 2)),
        'carved',
        manualFields: {'text', 'timing'},
      ),
    ]);
    assertPure(p, () {
      expect(
        () => move.change(p, MoveClips([a], Q.of(1), mode: 'overwrite')),
        code('CAPTION_OVERLAP'),
      );
    });
  });

  test('linked overwrite move carves both tracks and does not shift later captions', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-later',
        TimeRange(Q.of(2), Q.of(1, 5)),
        'stay',
        manualFields: {'text', 'timing'},
      ),
    ]);
    p = move.change(p, MoveClips([a], Q.of(1), mode: 'overwrite'));
    expect(startOf(p, a), Q.of(1));
    expect(startOf(p, 'right'), Q.of(2));
    final audios = [
      for (final c
          in (p.toJson()['sequences'][0]['tracks'] as List).singleWhere(
            (t) => t['kind'] == 'audio',
          )['items'])
        if (c['source'] != null) c as Map,
    ];
    expect(audios, hasLength(2));
    expect(
      {for (final c in audios) Q.fromJson(c['timelineRange']['start'])},
      {Q.of(1), Q.of(2)},
    );
    expect(cueOf(p, 'cue-later')['text'], 'stay');
    expect(
      Q.fromJson(cueOf(p, 'cue-later')['timelineRange']['start']),
      Q.of(2),
    );
  });

  test(
    'overwrite that uncovers a source cue is whole-group ANCHOR_OUT_OF_RANGE',
    () {
      var p = avFixture();
      final a = algebra.firstId(p);
      p = move.change(p, SplitClip(a, Q.of(1), 'right'));
      final host = clipOf(p, 'right');
      final cue =
          CaptionCue(
            'cue-src',
            TimeRange(Q.of(1), Q.of(1, 2)),
            'src',
            manualFields: {'text', 'timing'},
          ).anchoredToSource(
            clipId: 'right',
            clipStart: Q.fromJson(host['timelineRange']['start']),
            clipDuration: Q.fromJson(host['timelineRange']['duration']),
            sourceDuration: Q.fromJson(host['sourceRange']['duration']),
            rate: Q.fromJson(host['timeMap']['rate']),
          );
      p = move.change(p, SetCaptions(CaptionStore([cue])));
      expect(cueOf(p, 'cue-src')['anchor']['kind'], 'source');
      assertPure(p, () {
        expect(
          () => move.change(p, MoveClips([a], Q.of(1), mode: 'overwrite')),
          code('ANCHOR_OUT_OF_RANGE'),
        );
      });
    },
  );

  test('overwrite paste keeps dest cue text; uniquely covered cues may rebind to the pasted clip', () {
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, SplitClip(a, Q.of(1), 'right'));
    p = attachDefaults(p, [
      CaptionCue(
        'cue-hole',
        TimeRange(Q.of(1), Q.of(1, 2)),
        'carved',
        manualFields: {'text', 'timing'},
      ),
      CaptionCue(
        'cue-later',
        TimeRange(Q.of(2), Q.of(1, 5)),
        'stay',
        manualFields: {'text', 'timing'},
      ),
    ]);
    final payload = buildClipboard(p, [a]);
    p = move.change(p, PasteClips(payload, at: Q.of(1), mode: 'overwrite'));
    expect(startOf(p, 'right'), Q.of(2));
    expect(durOf(p, 'right'), Q.of(1));
    expect(cueOf(p, 'cue-hole')['text'], 'carved');
    expect(Q.fromJson(cueOf(p, 'cue-hole')['timelineRange']['start']), Q.of(1));
    // Unique cover is the pasted clip at [1,2).
    expect(cueOf(p, 'cue-hole')['anchor']['kind'], 'clipLocal');
    expect(cueOf(p, 'cue-hole')['anchor']['clipId'], isNot('right'));
    expect(cueOf(p, 'cue-later')['text'], 'stay');
    expect(cueOf(p, 'cue-later')['anchor']['clipId'], 'right');
    expect(
      Q.fromJson(cueOf(p, 'cue-later')['timelineRange']['start']),
      Q.of(2),
    );
  });
}
