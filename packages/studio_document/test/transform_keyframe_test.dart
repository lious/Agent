import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'persistent_audio_test.dart' show avFixture;

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

void main() {
  var serial = 0;
  final versions = <String, int>{};
  late ProjectDocument p;
  late String id;
  ProjectDocument edit(ProjectDocument d, EditOperation op) => applyEdit(
    d,
    op,
    newId: () => 'xf-key-${serial++}',
    nextVersion: (eid) =>
        '${versions.update(eid, (v) => v + 1, ifAbsent: () => 40)}',
  );
  Map clip(ProjectDocument d, String clipId) {
    for (final t in d.toJson()['sequences'][0]['tracks']) {
      for (final c in t['items']) {
        if (c['id'] == clipId) return c as Map;
      }
    }
    throw StateError('missing clip');
  }

  Map? transformEffect(ProjectDocument d, [String? clipId]) {
    final c = clip(d, clipId ?? id);
    final ids = c['effectIds'] as List;
    final matches = (d.toJson()['effects'] as List)
        .where((e) => ids.contains(e['id']) && e['type'] == 'transform2d')
        .toList();
    return matches.isEmpty ? null : matches.single as Map;
  }

  ProjectDocument curve(ProjectDocument d) => edit(
    edit(d, SetTransformKeyframe(id, Q.of(0), 'translateX', 0)),
    SetTransformKeyframe(id, Q.of(2), 'translateX', 16),
  );

  setUp(() {
    serial = 0;
    versions.clear();
    p = ProjectDocument.fromJson(
      jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    id = p.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'] as String;
  });

  test('rational linear/hold, outgoing half-open semantics, endpoint holds, replacement identity/noop and explicit removal', () {
    final a = curve(p);
    expect(
      TimelineVideoGraph(a).sampleFrame(Q.of(1)).transform2d!['translateX'],
      8,
    );
    expect(
      clipTransform2d(a.toJson(), clip(a, id), Q.of(3))!['translateX'],
      16,
    );
    final g = TimelineVideoGraph(a);
    expect(g.sampleFrame(Q.of(101, 100)).transform2d!['translateX'], 8);
    final segment = g.encoderSegment(
      id,
      originalPath: '/fixture',
      streamIndex: 0,
      frameRate: FrameRate(30, 1),
    );
    expect(segment.containsKey('transformFrames'), isTrue);
    expect((segment['transformFrames'] as List)[30]['translateX'], 8);
    final h = edit(
      a,
      SetTransformKeyframe(id, Q.of(0), 'translateX', 0, interpolation: 'hold'),
    );
    expect(
      TimelineVideoGraph(h).sampleFrame(Q.of(1999, 1000)).transform2d,
      isNull,
    );
    expect(
      TimelineVideoGraph(h).sampleFrame(Q.of(2)).transform2d!['translateX'],
      16,
    );
    expect(
      edit(
        h,
        SetTransformKeyframe(
          id,
          Q.of(0),
          'translateX',
          0,
          interpolation: 'hold',
        ),
      ).hash,
      h.hash,
    );
    expect(
      () => edit(
        a,
        SetClipTransform(id, {...identityTransform2d, 'translateX': 4}),
      ),
      code('ANIMATED_TRANSFORM_REQUIRES_EXPLICIT_KEYFRAME_EDIT'),
    );
    var r = edit(a, RemoveTransformKeyframe(id, Q.of(2), 'translateX'));
    r = edit(r, RemoveTransformKeyframe(id, Q.of(0), 'translateX'));
    expect(transformEffect(r)!['keyframes'], isEmpty);
    expect(
      () => edit(r, RemoveTransformKeyframe(id, Q.of(0), 'translateX')),
      code('KEYFRAME_NOT_FOUND'),
    );
    expect(() => g.sample(Q.of(3)), code('TIMELINE_TIME_OUT_OF_RANGE'));
  });

  test('split/crop/rebase, trims preserve function, slip keeps clip-local curve, move does not shift local keys', () {
    final a = curve(p), split = edit(a, SplitClip(id, Q.of(1), 'right'));
    for (var f = 0; f < 90; f++) {
      final before = TimelineVideoGraph(a).sample(Q.of(f, 30)).transform2d;
      final after = TimelineVideoGraph(split).sample(Q.of(f, 30)).transform2d;
      if (before == null) {
        expect(after, isNull);
        continue;
      }
      expect(after, isNotNull);
      for (final k in identityTransform2d.keys) {
        expect(after![k], closeTo(before[k]!, 1e-9), reason: 'f=$f $k');
      }
    }
    final effects = (split.toJson()['effects'] as List)
        .where((e) => e['type'] == 'transform2d')
        .toList();
    expect(effects.length, 2);
    final ids = [
      for (final e in effects)
        for (final k in e['keyframes']) k['id'],
    ];
    expect(ids.toSet().length, ids.length);
    for (final e in effects) {
      for (final k in e['keyframes']) {
        expect(k['param'], 'translateX');
      }
    }
    final trim = edit(split, TrimClip('right', 'in', Q.of(1, 2)));
    expect(
      TimelineVideoGraph(trim)
          .sampleFrame(Q.of(3, 2))
          .transform2d!['translateX'],
      12,
    );
    final slipped = edit(trim, SlipClip('right', Q.of(-1, 2)));
    expect(
      TimelineVideoGraph(slipped)
          .sampleFrame(Q.of(3, 2))
          .transform2d!['translateX'],
      12,
    );
    final shortened = edit(a, TrimClip(id, 'out', Q.of(-1))),
        moved = edit(shortened, MoveClip(id, Q.of(1)));
    expect(
      TimelineVideoGraph(moved).sample(Q.of(3, 2)).transform2d!['translateX'],
      4,
    );
    expect(transformEffect(a)!['keyframes'].length, 2);
  });

  test('off-grid, unknown interpolation, unregistered param, audio clip and locked implicit curve edits refuse without half-write', () {
    final a = curve(p), hash = a.hash;
    expect(
      () => edit(a, SetTransformKeyframe(id, Q.of(1, 1000), 'translateX', 8)),
      code('KEYFRAME_NOT_ON_FRAME'),
    );
    expect(
      () => edit(a, SetTransformKeyframe(id, Q.of(4), 'translateX', 8)),
      code('KEYFRAME_OUT_OF_RANGE'),
    );
    expect(
      () => edit(
        a,
        SetTransformKeyframe(
          id,
          Q.of(1),
          'translateX',
          8,
          interpolation: 'bezier',
        ),
      ),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(
      () => edit(a, SetTransformKeyframe(id, Q.of(1), 'skewX', 1)),
      code('TRANSFORM_ANIMATION_NOT_IMPLEMENTED'),
    );
    expect(
      () => edit(a, SetTransformKeyframe(id, Q.of(1), 'translateX', 1000001)),
      code('TRANSFORM_CPU_PROFILE_RANGE'),
    );
    expect(a.hash, hash);

    var av = avFixture();
    av = edit(av, ExtractAudioClip(id, 'audio-stream'));
    String audioId() {
      for (final t in av.toJson()['sequences'][0]['tracks']) {
        if (t['kind'] != 'audio') continue;
        for (final c in t['items']) {
          if (c['source'] != null) return c['id'] as String;
        }
      }
      throw StateError('no audio');
    }

    final beforeAudio = av.hash;
    expect(
      () => edit(av, SetTransformKeyframe(audioId(), Q.of(0), 'translateX', 8)),
      code('UNSUPPORTED_EDIT_TECHNIQUE'),
    );
    expect(av.hash, beforeAudio);

    final d = a.toJson();
    d['sequences'][0]['tracks'][0]['items'][0]['lockedFields'] = [
      'effects.translateX',
    ];
    final locked = ProjectDocument.fromJson(d);
    expect(
      () => edit(locked, TrimClip(id, 'in', Q.of(1))),
      code('FIELD_LOCKED'),
    );
    expect(locked.hash, isNot(hash));
    expect(a.hash, hash);
  });

  test('editing disabled animation preserves enable state; extending a cropped in-point holds the boundary value', () {
    final a = curve(p), d = a.toJson();
    d['effects'].singleWhere((e) => e['type'] == 'transform2d')['enabled'] =
        false;
    final disabled = ProjectDocument.fromJson(d),
        changed = edit(
          disabled,
          SetTransformKeyframe(id, Q.of(1), 'translateX', 4),
        );
    expect(transformEffect(changed)!['enabled'], false);
    expect(
      TimelineVideoGraph(changed).sampleFrame(Q.of(1)).transform2d,
      isNull,
    );
    var short = edit(a, TrimClip(id, 'in', Q.of(1)));
    short = edit(short, TrimClip(id, 'in', Q.of(-1)));
    expect(
      TimelineVideoGraph(short).sampleFrame(Q.of(0)).transform2d!['translateX'],
      8,
    );
    expect(
      TimelineVideoGraph(short)
          .sampleFrame(Q.of(1, 2))
          .transform2d!['translateX'],
      8,
    );
  });

  test('registered params compose with opacity in canonical order; first key creates identity base; 256-point limit', () {
    var a = edit(p, SetOpacityKeyframe(id, Q.of(0), 0));
    a = edit(a, SetOpacityKeyframe(id, Q.of(2), 1));
    a = curve(a);
    final types = [
      for (final eid in clip(a, id)['effectIds'])
        (a.toJson()['effects'] as List).singleWhere(
          (e) => e['id'] == eid,
        )['type'],
    ];
    expect(types, ['transform2d', 'opacity']);
    final sample = TimelineVideoGraph(a).sampleFrame(Q.of(1));
    expect(sample.opacityQ16, 32768);
    expect(sample.transform2d!['translateX'], 8);
    final first = edit(
      p,
      SetTransformKeyframe(id, Q.of(0), 'scaleX', 2, interpolation: 'hold'),
    );
    expect(transformEffect(first)!['parameters'], {
      ...identityTransform2d,
      'scaleX': 2,
    });
    expect(transformEffect(first)!['pluginVersion'], '1.0.0');
    var filled = first;
    // 3s @ 30fps has 91 legal frame times (0..duration). Fill 256 across
    // registered params rather than inventing off-grid times.
    for (var i = 1; i <= 90; i++) {
      filled = edit(
        filled,
        SetTransformKeyframe(
          id,
          Q.of(i, 30),
          'scaleX',
          2,
          interpolation: 'hold',
        ),
      );
    }
    for (var i = 0; i <= 90; i++) {
      filled = edit(
        filled,
        SetTransformKeyframe(
          id,
          Q.of(i, 30),
          'scaleY',
          2,
          interpolation: 'hold',
        ),
      );
    }
    for (var i = 0; i < 74; i++) {
      filled = edit(
        filled,
        SetTransformKeyframe(
          id,
          Q.of(i, 30),
          'translateX',
          0,
          interpolation: 'hold',
        ),
      );
    }
    expect((transformEffect(filled)!['keyframes'] as List).length, 256);
    expect(
      () => edit(
        filled,
        SetTransformKeyframe(
          id,
          Q.of(74, 30),
          'translateX',
          0,
          interpolation: 'hold',
        ),
      ),
      code('TRANSFORM_KEYFRAME_LIMIT'),
    );
    expect((transformEffect(filled)!['keyframes'] as List).length, 256);
  });

  test('anchor/scale/rotation keys evaluate independently of unkeyed params; static identity is a bypass only when the evaluated map is identity', () {
    var a = edit(p, SetTransformKeyframe(id, Q.of(0), 'scaleX', 1));
    a = edit(a, SetTransformKeyframe(id, Q.of(2), 'scaleX', 2));
    a = edit(a, SetTransformKeyframe(id, Q.of(0), 'rotationDeg', 0));
    a = edit(a, SetTransformKeyframe(id, Q.of(2), 'rotationDeg', 90));
    final mid = TimelineVideoGraph(a).sampleFrame(Q.of(1)).transform2d!;
    expect(mid['scaleX'], 1.5);
    expect(mid['rotationDeg'], 45);
    expect(mid['translateX'], 0);
    expect(mid['anchorX'], 0.5);
    // Evaluated identity at t=0 is a true bypass.
    expect(TimelineVideoGraph(a).sampleFrame(Q.of(0)).transform2d, isNull);
  });
}
