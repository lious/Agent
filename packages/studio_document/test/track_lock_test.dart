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

Map cueOf(ProjectDocument p, [String id = 'cue-1']) =>
    (p.toJson()['captions'] as List).cast<Map>().singleWhere(
      (c) => c['id'] == id,
    );

Map trackOf(ProjectDocument p, String kind) =>
    (p.toJson()['sequences'][0]['tracks'] as List).cast<Map>().singleWhere(
      (t) => t['kind'] == kind,
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
  test(
    'locking the video track refuses clip edits and leaves captions in place',
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
      final video = trackOf(p, 'video')['id'] as String;
      p = move.change(p, SetTrackState(video, locked: true));
      expect(trackOf(p, 'video')['locked'], isTrue);
      expect(cueOf(p)['text'], 'hello');
      expect(cueOf(p)['anchor']['kind'], 'clipLocal');
      expect(cueOf(p)['anchor']['clipId'], a);
      assertPure(p, () {
        expect(
          () => move.change(p, MoveClip(a, Q.of(1))),
          code('FIELD_LOCKED'),
        );
        expect(
          () => move.change(p, TrimClip(a, 'out', Q.of(0) - Q.of(1, 2))),
          code('FIELD_LOCKED'),
        );
        expect(
          () => move.change(p, SplitClip(a, Q.of(1), 'right')),
          code('FIELD_LOCKED'),
        );
      });
      expect(startOf(p, a), Q.of(0));
      expect(Q.fromJson(cueOf(p)['timelineRange']['start']), Q.of(0));
    },
  );

  test('unlock is not blocked by the track lock, then a leave-gap move follows the cue', () {
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
    final video = trackOf(p, 'video')['id'] as String;
    p = move.change(p, SetTrackState(video, locked: true));
    p = move.change(p, SetTrackState(video, locked: false));
    expect(trackOf(p, 'video')['locked'], isFalse);
    p = move.change(p, MoveClip(a, Q.of(1)));
    expect(startOf(p, a), Q.of(1));
    expect(cueOf(p)['anchor']['kind'], 'clipLocal');
    expect(Q.fromJson(cueOf(p)['timelineRange']['start']), Q.of(1));
    expect(cueOf(p)['text'], 'hello');
  });

  test(
    'a locked caption track refuses SetCaptions; a locked video track does not',
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
      final video = trackOf(p, 'video')['id'] as String;
      final caption = trackOf(p, 'caption')['id'] as String;
      p = move.change(p, SetTrackState(video, locked: true));
      p = move.change(
        p,
        SetCaptions(
          CaptionStore([
            CaptionCue(
              'cue-1',
              TimeRange(Q.of(0), Q.of(1, 2)),
              'hello',
              manualFields: {'text', 'timing'},
            ),
            CaptionCue(
              'cue-2',
              TimeRange(Q.of(2), Q.of(1, 5)),
              'later',
              manualFields: {'text', 'timing'},
            ),
          ]),
        ),
      );
      expect((p.toJson()['captions'] as List), hasLength(2));
      expect(() => move.change(p, MoveClip(a, Q.of(1))), code('FIELD_LOCKED'));
      p = move.change(p, SetTrackState(caption, locked: true));
      final cues = [
        for (final c in (p.toJson()['captions'] as List))
          CaptionCue.fromProjectJson(Map<String, dynamic>.from(c as Map)),
      ];
      assertPure(p, () {
        expect(
          () => move.change(
            p,
            SetCaptions(
              CaptionStore([
                cues.first,
                CaptionCue(
                  'cue-2',
                  TimeRange(Q.of(2), Q.of(1, 5)),
                  'changed',
                  manualFields: {'text', 'timing'},
                ),
              ]),
            ),
          ),
          code('FIELD_LOCKED'),
        );
      });
      expect(cueOf(p, 'cue-2')['text'], 'later');
    },
  );

  test('locking a persistent audio track refuses mute and clip edits; unlock restores them', () {
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
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    final audio = trackOf(p, 'audio')['id'] as String;
    final audioClip =
        media(p).singleWhere((c) => c['trackId'] == audio)['id'] as String;
    p = move.change(p, SetTrackState(audio, locked: true));
    assertPure(p, () {
      expect(
        () =>
            move.change(p, SetAudioTrackState(audio, muted: true, solo: false)),
        code('FIELD_LOCKED'),
      );
      expect(
        () => move.change(p, MoveClip(audioClip, Q.of(1))),
        code('FIELD_LOCKED'),
      );
    });
    expect(cueOf(p)['text'], 'hello');
    expect(Q.fromJson(cueOf(p)['timelineRange']['start']), Q.of(0));
    p = move.change(p, SetTrackState(audio, locked: false));
    p = move.change(p, SetAudioTrackState(audio, muted: true, solo: false));
    expect(trackOf(p, 'audio')['muted'], isTrue);
    expect(cueOf(p)['text'], 'hello');
    expect(cueOf(p)['anchor']['kind'], 'clipLocal');
  });

  test('a missing track is TRACK_NOT_FOUND and a no-op lock does not rewrite the document', () {
    var p = avFixture();
    p = attachDefaults(p, [
      CaptionCue(
        'cue-1',
        TimeRange(Q.of(0), Q.of(1, 2)),
        'hello',
        manualFields: {'text', 'timing'},
      ),
    ]);
    final video = trackOf(p, 'video')['id'] as String;
    expect(
      () =>
          move.change(p, SetTrackState('missing-track-id-0001', locked: true)),
      code('TRACK_NOT_FOUND'),
    );
    final before = content(p);
    final same = move.change(p, SetTrackState(video, locked: false));
    expect(identical(same, p) || content(same) == before, isTrue);
    expect(content(same), before);
  });
}
