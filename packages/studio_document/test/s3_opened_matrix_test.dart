import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as algebra;
import 'multi_move_test.dart' as move;
import 'persistent_audio_test.dart' show avFixture;

/// One frame from the s3 table, scaled so the 450-frame fixture fits the
/// 3-second local video (divide by 5). 15-frame examples stay on the 30 fps
/// grid: f(15) = 1/10 s = 3/30.
Q f(int frames) => Q.of(frames, 150);

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

Q sourceStartOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['start']);

Q sourceDurOf(ProjectDocument p, String id) =>
    Q.fromJson(clipOf(p, id)['sourceRange']['duration']);

Q seqDur(ProjectDocument p) =>
    Q.fromJson(p.toJson()['sequences'][0]['duration']);

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

String videoA(ProjectDocument p) => media(p)
    .where((c) => c['trackId'] == p.toJson()['sequences'][0]['tracks'][0]['id'])
    .reduce(
      (a, b) =>
          Q.fromJson(a['timelineRange']['start']) <=
              Q.fromJson(b['timelineRange']['start'])
          ? a
          : b,
    )['id'] as String;

String? audioId(ProjectDocument p) {
  final tracks = p.toJson()['sequences'][0]['tracks'] as List;
  for (final t in tracks) {
    if (t['kind'] != 'audio') continue;
    for (final c in t['items']) {
      if (c['source'] != null) return c['id'] as String;
    }
  }
  return null;
}

ProjectDocument plantS3Sources(ProjectDocument p, String a, String b, String c) {
  final d = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
  void plant(String id, Q start) {
    for (final t in d['sequences'][0]['tracks']) {
      for (final item in t['items']) {
        if (item['id'] == id) {
          item['sourceRange'] = {
            'start': start.toJson(),
            'duration': Q.of(1).toJson(),
          };
        }
      }
    }
  }

  plant(a, f(30));
  plant(b, f(60));
  plant(c, f(0));
  return ProjectDocument.fromJson(d);
}

/// Scaled s3 A/B/C: A[0,1) src[0.2,1.2), B[1,2) src[0.4,1.4), C[2,3) src[0,1).
ProjectDocument s3Abc() {
  var p = avFixture();
  final a = algebra.firstId(p);
  p = move.change(p, SplitClip(a, Q.of(1), 's3-b'));
  p = move.change(p, SplitClip('s3-b', Q.of(2), 's3-c'));
  return plantS3Sources(p, a, 's3-b', 's3-c');
}

/// 3s linked audio unlinked so video can be split while audio still spans at.
ProjectDocument s3AbcWithSpanningAudio() {
  var p = avFixture();
  final a = algebra.firstId(p);
  p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
  final group = p.toJson()['linkGroups'][0]['id'] as String;
  p = move.change(p, UnlinkAudioVideo(group));
  p = move.change(p, SplitClip(a, Q.of(1), 's3-b'));
  p = move.change(p, SplitClip('s3-b', Q.of(2), 's3-c'));
  return plantS3Sources(p, a, 's3-b', 's3-c');
}

ProjectDocument attachCue(
  ProjectDocument p, {
  required String id,
  required Q start,
  Q? duration,
  String text = 'hello',
  String? makeAbsoluteId,
}) {
  final existing = [
    for (final c in (p.toJson()['captions'] as List))
      CaptionCue.fromProjectJson(Map<String, dynamic>.from(c as Map)),
  ];
  var cue = CaptionCue(
    id,
    TimeRange(start, duration ?? f(30)),
    text,
    manualFields: {'text', 'timing'},
  );
  var store = CaptionStore([...existing, cue]);
  var out = move.change(p, SetCaptions(store));
  if (makeAbsoluteId != null) {
    final cues = [
      for (final c in (out.toJson()['captions'] as List))
        CaptionCue.fromProjectJson(Map<String, dynamic>.from(c as Map)),
    ].map((c) => c.id == makeAbsoluteId ? c.makeAbsolute() : c).toList();
    out = move.change(out, SetCaptions(CaptionStore(cues)));
  }
  return out;
}

void assertPure(ProjectDocument before, void Function() action) {
  final start = content(before);
  final raw = jsonEncode(before.toJson());
  action();
  expect(content(before), start);
  expect(jsonEncode(before.toJson()), raw);
}

void main() {
  test('s3 move: A+30 reject collides with B; negative start refuses; hash unchanged', () {
    final p = s3Abc();
    final a = videoA(p);
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, 's3-b'), f(150));
    expect(startOf(p, 's3-c'), f(300));
    expect(seqDur(p), f(450));
    expect(sourceStartOf(p, a), f(30));
    assertPure(p, () {
      expect(
        () => move.change(p, MoveClips([a], f(30))),
        code('COLLISION'),
      );
      expect(
        () => move.change(p, MoveClips([a], Q.of(0) - f(30))),
        code('NEGATIVE_TIMELINE_START'),
      );
    });
    // Moving A+B+C together is legal and leaves sources untouched.
    final shifted = move.change(p, MoveClips([a, 's3-b', 's3-c'], f(30)));
    expect(startOf(shifted, a), f(30));
    expect(startOf(shifted, 's3-b'), f(180));
    expect(sourceStartOf(shifted, a), f(30));
    expect(sourceStartOf(shifted, 's3-b'), f(60));
    expect(p.toJson()['assets'], shifted.toJson()['assets']);
    expect(content(p), isNot(content(shifted)));
    expect(content(p), content(ProjectDocument.fromJson(p.toJson())));
  });

  test('s3 split: A at 60 remaps sources; 0/150 and off-grid refuse', () {
    final p = s3Abc();
    final a = videoA(p);
    final split = move.change(p, SplitClip(a, f(60), 's3-a-right'));
    expect(startOf(split, a), Q.of(0));
    expect(durOf(split, a), f(60));
    expect(sourceStartOf(split, a), f(30));
    expect(sourceDurOf(split, a), f(60));
    expect(startOf(split, 's3-a-right'), f(60));
    expect(durOf(split, 's3-a-right'), f(90));
    expect(sourceStartOf(split, 's3-a-right'), f(90));
    expect(sourceDurOf(split, 's3-a-right'), f(90));
    expect(startOf(split, 's3-b'), f(150));
    expect(seqDur(split), f(450));
    expect(p.toJson()['assets'], split.toJson()['assets']);
    assertPure(p, () {
      expect(() => move.change(p, SplitClip(a, Q.of(0), 'x')), throwsA(isA<StudioException>()));
      expect(() => move.change(p, SplitClip(a, f(150), 'x')), throwsA(isA<StudioException>()));
      expect(() => move.change(p, SplitClip(a, Q.of(1, 100), 'x')), throwsA(isA<StudioException>()));
    });
    // Caption-bearing projects still refuse SplitClip as a whole group.
    final withCue = attachCue(p, id: 'cue-1', start: f(15));
    expect(content(withCue), isNot(content(p)));
    assertPure(withCue, () {
      expect(
        () => move.change(withCue, SplitClip(a, f(60), 's3-a-right')),
        code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
      );
    });
    expect(withCue.toJson()['captions'][0]['text'], 'hello');
  });

  test('s3 insert: paste 60 frames at 150 shifts B and C; spanning audio splits; locked sync refuses', () {
    final p = s3Abc();
    final a = videoA(p);
    final payload = buildClipboard(
      move.change(p, TrimClip(a, 'out', Q.of(0) - f(90))),
      [a],
    );
    final out = move.change(
      p,
      PasteClips(payload, at: f(150), mode: 'insert'),
    );
    expect(startOf(out, a), Q.of(0));
    expect(durOf(out, a), Q.of(1));
    expect(startOf(out, 's3-b'), f(210));
    expect(sourceStartOf(out, 's3-b'), f(60));
    expect(startOf(out, 's3-c'), f(360));
    expect(seqDur(out), f(510));
    final copies = media(out).where((c) => !{a, 's3-b', 's3-c'}.contains(c['id']));
    expect(copies, hasLength(1));
    expect(Q.fromJson(copies.single['timelineRange']['start']), f(150));
    expect(Q.fromJson(copies.single['timelineRange']['duration']), f(60));
    expect(p.toJson()['assets'], out.toJson()['assets']);

    final spanned = s3AbcWithSpanningAudio();
    final audio = audioId(spanned)!;
    expect(durOf(spanned, audio), Q.of(3));
    final inserted = move.change(
      spanned,
      PasteClips(payload, at: f(150), mode: 'insert'),
    );
    final audios = media(inserted).where((c) {
      final tracks = inserted.toJson()['sequences'][0]['tracks'] as List;
      final track = tracks.singleWhere((t) => t['id'] == c['trackId']);
      return track['kind'] == 'audio';
    }).toList();
    expect(audios, hasLength(2));
    final left = audios.singleWhere((c) => Q.fromJson(c['timelineRange']['start']) == Q.of(0));
    final right = audios.singleWhere((c) => c['id'] != left['id']);
    expect(Q.fromJson(left['timelineRange']['duration']), f(150));
    expect(Q.fromJson(right['timelineRange']['start']), f(210));
    expect(Q.fromJson(right['timelineRange']['duration']), f(300));
    expect(seqDur(inserted), f(510));

    final d = jsonDecode(jsonEncode(spanned.toJson())) as Map<String, dynamic>;
    for (final t in d['sequences'][0]['tracks']) {
      if (t['kind'] == 'audio') t['locked'] = true;
    }
    final locked = ProjectDocument.fromJson(d);
    assertPure(locked, () {
      expect(
        () => move.change(locked, PasteClips(payload, at: f(150), mode: 'insert')),
        code('SYNC_LOCKED'),
      );
    });
  });

  test('s3 overwrite: [120,210) keeps A head, remaps B tail, leaves C and duration', () {
    final p = s3Abc();
    final a = videoA(p);
    final payload = buildClipboard(
      move.change(p, TrimClip(a, 'out', Q.of(0) - f(60))),
      [a],
    );
    final out = move.change(
      p,
      PasteClips(payload, at: f(120), mode: 'overwrite'),
    );
    expect(startOf(out, a), Q.of(0));
    expect(durOf(out, a), f(120));
    expect(sourceStartOf(out, a), f(30));
    expect(sourceDurOf(out, a), f(120));
    final copies = media(out).where((c) => !{a, 's3-b', 's3-c'}.contains(c['id']));
    expect(copies, hasLength(1));
    expect(Q.fromJson(copies.single['timelineRange']['start']), f(120));
    expect(Q.fromJson(copies.single['timelineRange']['duration']), f(90));
    expect(startOf(out, 's3-b'), f(210));
    expect(durOf(out, 's3-b'), f(90));
    expect(sourceStartOf(out, 's3-b'), f(120));
    expect(sourceDurOf(out, 's3-b'), f(90));
    expect(startOf(out, 's3-c'), f(300));
    expect(sourceStartOf(out, 's3-c'), f(0));
    expect(seqDur(out), f(450));
    expect(p.toJson()['assets'], out.toJson()['assets']);
  });

  test('s3 lift leaves a gap; ripple R=[120,180) remaps B and shortens; locked sync refuses', () {
    final p = s3Abc();
    final a = videoA(p);
    final lifted = move.change(p, LiftClips(['s3-c']));
    expect(seqDur(lifted), f(450));
    expect(startOf(lifted, a), Q.of(0));
    expect(startOf(lifted, 's3-b'), f(150));
    expect(() => clipOf(lifted, 's3-c'), throwsA(isA<StateError>()));

    final closed = move.change(
      p,
      RippleDeleteClips(const [], range: TimeRange(f(120), f(60))),
    );
    expect(startOf(closed, a), Q.of(0));
    expect(durOf(closed, a), f(120));
    expect(sourceStartOf(closed, a), f(30));
    expect(sourceDurOf(closed, a), f(120));
    final remnantB = media(closed).singleWhere(
      (c) =>
          Q.fromJson(c['timelineRange']['start']) == f(120) &&
          Q.fromJson(c['timelineRange']['duration']) == f(120),
    );
    expect(sourceStartOf(closed, remnantB['id'] as String), f(90));
    expect(sourceDurOf(closed, remnantB['id'] as String), f(120));
    expect(startOf(closed, 's3-c'), f(240));
    expect(durOf(closed, 's3-c'), f(150));
    expect(sourceStartOf(closed, 's3-c'), f(0));
    expect(seqDur(closed), f(390));
    expect(p.toJson()['assets'], closed.toJson()['assets']);

    final spanned = s3AbcWithSpanningAudio();
    final d = jsonDecode(jsonEncode(spanned.toJson())) as Map<String, dynamic>;
    for (final t in d['sequences'][0]['tracks']) {
      if (t['kind'] == 'audio') t['locked'] = true;
    }
    final locked = ProjectDocument.fromJson(d);
    assertPure(locked, () {
      expect(
        () => move.change(
          locked,
          RippleDeleteClips(const [], range: TimeRange(f(120), f(60))),
        ),
        code('SYNC_LOCKED'),
      );
    });
  });

  test('s3 ordinary trim: out -15 leaves a gap; in +15 remaps source; lengthen and source exhaustion refuse', () {
    final p = s3Abc();
    final a = videoA(p);
    final shortened = move.change(p, TrimClip(a, 'out', Q.of(0) - f(15)));
    expect(startOf(shortened, a), Q.of(0));
    expect(durOf(shortened, a), f(135));
    expect(sourceStartOf(shortened, a), f(30));
    expect(sourceDurOf(shortened, a), f(135));
    expect(startOf(shortened, 's3-b'), f(150));
    expect(seqDur(shortened), f(450));
    final gaps = [
      for (final t in shortened.toJson()['sequences'][0]['tracks'])
        for (final c in t['items'])
          if (c['source'] == null) c as Map,
    ];
    expect(
      gaps.any(
        (g) =>
            Q.fromJson(g['timelineRange']['start']) == f(135) &&
            Q.fromJson(g['timelineRange']['duration']) == f(15),
      ),
      isTrue,
    );

    final trimmedIn = move.change(p, TrimClip(a, 'in', f(15)));
    expect(startOf(trimmedIn, a), f(15));
    expect(durOf(trimmedIn, a), f(135));
    expect(sourceStartOf(trimmedIn, a), f(45));
    expect(sourceDurOf(trimmedIn, a), f(135));
    expect(startOf(trimmedIn, 's3-b'), f(150));
    expect(seqDur(trimmedIn), f(450));

    assertPure(p, () {
      expect(
        () => move.change(p, TrimClip(a, 'out', f(15))),
        code('COLLISION'),
      );
      expect(
        () => move.change(p, TrimClip('s3-c', 'out', f(330))),
        code('SOURCE_OUT_OF_RANGE'),
      );
    });

    final withCue = attachCue(p, id: 'cue-1', start: f(15));
    assertPure(withCue, () {
      expect(
        () => move.change(withCue, TrimClip(a, 'out', Q.of(0) - f(15))),
        code('CAPTION_SYNC_EDIT_NOT_IMPLEMENTED'),
      );
    });
    expect(withCue.toJson()['captions'][0]['text'], 'hello');
  });

  test('s3 ripple trim: A out -15 and A in +15 close or keep start 0 and shorten later content', () {
    final p = s3Abc();
    final a = videoA(p);
    final outTrim = move.change(p, RippleTrimClip(a, 'out', Q.of(0) - f(15)));
    expect(startOf(outTrim, a), Q.of(0));
    expect(durOf(outTrim, a), f(135));
    expect(startOf(outTrim, 's3-b'), f(135));
    expect(durOf(outTrim, 's3-b'), f(150));
    expect(startOf(outTrim, 's3-c'), f(285));
    expect(seqDur(outTrim), f(435));

    final inTrim = move.change(p, RippleTrimClip(a, 'in', f(15)));
    expect(startOf(inTrim, a), Q.of(0));
    expect(durOf(inTrim, a), f(135));
    expect(sourceStartOf(inTrim, a), f(45));
    expect(sourceDurOf(inTrim, a), f(135));
    expect(startOf(inTrim, 's3-b'), f(135));
    expect(startOf(inTrim, 's3-c'), f(285));
    expect(seqDur(inTrim), f(435));
    expect(p.toJson()['assets'], inTrim.toJson()['assets']);
  });

  test('s3 link: includeLinks keeps a frame-grid offset; ignore-links marks allowOutOfSync; unlink keeps both', () {
    // Packed A/B/C cannot take the table's +1s on A alone (A would collide
    // with B). The s3 link example is a single AV pair. The table's 0.02s
    // offset is off the 30 fps video grid and refuses on relink
    // (OFF_FRAME_GRID); this batch uses one frame (1/30 s) instead.
    var p = avFixture();
    final a = algebra.firstId(p);
    p = move.change(p, ExtractAudioClip(a, 'audio-stream'));
    final audio = audioId(p)!;
    p = move.change(p, MoveClips([audio], Q.of(1, 30), includeLinks: false));
    expect(startOf(p, a), Q.of(0));
    expect(startOf(p, audio), Q.of(1, 30));
    expect(
      (p.toJson()['linkGroups'] as List).single['syncPolicy'],
      'allowOutOfSync',
    );
    final groupId = p.toJson()['linkGroups'][0]['id'] as String;
    p = move.change(p, UnlinkAudioVideo(groupId));
    p = move.change(p, LinkAudioVideo(a, audio));
    final together = move.change(p, MoveClips([a], Q.of(1)));
    expect(startOf(together, a), Q.of(1));
    expect(startOf(together, audio), Q.of(1) + Q.of(1, 30));
    final ignored = move.change(
      together,
      MoveClips([a], Q.of(1), includeLinks: false),
    );
    expect(startOf(ignored, a), Q.of(2));
    expect(startOf(ignored, audio), Q.of(1) + Q.of(1, 30));
    expect(
      (ignored.toJson()['linkGroups'] as List).single['syncPolicy'],
      'allowOutOfSync',
    );
    final unlinked = move.change(
      ignored,
      UnlinkAudioVideo(ignored.toJson()['linkGroups'][0]['id'] as String),
    );
    expect(startOf(unlinked, a), Q.of(2));
    expect(startOf(unlinked, audio), Q.of(1) + Q.of(1, 30));
    expect(unlinked.toJson()['linkGroups'], isEmpty);
    expect(p.toJson()['assets'], unlinked.toJson()['assets']);
  });

  test('s3 copy A+C paste after C keeps the 150-frame gap; new IDs; assets unchanged', () {
    final p = s3Abc();
    final a = videoA(p);
    final out = move.change(
      p,
      PasteClips(buildClipboard(p, [a, 's3-c']), at: f(450)),
    );
    final copies = media(out)
        .where((c) => !{a, 's3-b', 's3-c'}.contains(c['id']))
        .toList()
      ..sort(
        (x, y) => Q.fromJson(
          x['timelineRange']['start'],
        ).compareTo(Q.fromJson(y['timelineRange']['start'])),
      );
    expect(copies, hasLength(2));
    expect(Q.fromJson(copies[0]['timelineRange']['start']), f(450));
    expect(Q.fromJson(copies[1]['timelineRange']['start']), f(750));
    expect(
      Q.fromJson(copies[1]['timelineRange']['start']) -
          Q.fromJson(copies[0]['timelineRange']['start']),
      f(300),
    );
    expect(startOf(out, a), Q.of(0));
    expect(startOf(out, 's3-c'), f(300));
    expect(jsonEncode(out.toJson()['assets']), jsonEncode(p.toJson()['assets']));
  });

  test('captions and markers follow opened commands; lift of a clipLocal-marker host refuses; no silent drop', () {
    var p = s3Abc();
    final a = videoA(p);
    p = attachCue(p, id: 'cue-local', start: f(15), text: 'follow');
    p = attachCue(
      p,
      id: 'cue-abs',
      start: f(330),
      text: 'stay',
      makeAbsoluteId: 'cue-abs',
    );
    p = move.change(
      p,
      SetMarkers(
        MarkerStore([
          TimelineMarker(
            'mark-local',
            sequenceId: 'sequence-main',
            label: 'on-a',
            time: f(30),
            anchorKind: 'clipLocal',
            anchorClipId: a,
          ),
          TimelineMarker(
            'mark-abs',
            sequenceId: 'sequence-main',
            label: 'stay',
            time: f(330),
          ),
        ]),
      ),
    );
    expect(
      (p.toJson()['captions'] as List).singleWhere((c) => c['id'] == 'cue-local')['anchor']['kind'],
      'clipLocal',
    );
    expect(
      (p.toJson()['captions'] as List).singleWhere((c) => c['id'] == 'cue-abs')['anchor']['kind'],
      'absolute',
    );

    final closed = move.change(
      p,
      RippleDeleteClips(const [], range: TimeRange(f(120), f(60))),
    );
    final local = (closed.toJson()['captions'] as List)
        .singleWhere((c) => c['id'] == 'cue-local');
    final abs = (closed.toJson()['captions'] as List)
        .singleWhere((c) => c['id'] == 'cue-abs');
    expect(local['text'], 'follow');
    expect(Q.fromJson(local['timelineRange']['start']), f(15));
    expect(abs['text'], 'stay');
    expect(Q.fromJson(abs['timelineRange']['start']), f(270));
    final marks = {
      for (final m in closed.toJson()['markers']) m['id']: m,
    };
    expect(marks['mark-local']['label'], 'on-a');
    expect(Q.fromJson(marks['mark-local']['time']), f(30));
    expect(marks['mark-abs']['label'], 'stay');
    expect(Q.fromJson(marks['mark-abs']['time']), f(330));

    assertPure(p, () {
      expect(
        () => move.change(p, LiftClips([a])),
        code('REF_NOT_FOUND'),
      );
    });
    expect((p.toJson()['markers'] as List), hasLength(2));
    expect((p.toJson()['captions'] as List), hasLength(2));
  });

  test('insert-move still leaves a source gap; auto-close is not a MoveClips mode', () {
    final p = s3Abc();
    final a = videoA(p);
    final inserted = move.change(
      p,
      MoveClips([a], f(450), mode: 'insert', includeLinks: false),
    );
    expect(startOf(inserted, a), f(450));
    expect(startOf(inserted, 's3-b'), f(150));
    expect(startOf(inserted, 's3-c'), f(300));
    expect(seqDur(inserted), greaterThan(f(450)));
    expect(
      () => MoveClips([a], f(30), mode: 'close'),
      throwsA(isA<StudioException>()),
    );
  });
}
