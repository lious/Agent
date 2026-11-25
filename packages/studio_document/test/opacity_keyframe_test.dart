import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'persistent_audio_test.dart' show avFixture;

void main() {
  var serial = 0;
  final versions = <String, int>{};
  late ProjectDocument p;
  late String id;
  ProjectDocument edit(ProjectDocument d, EditOperation op) => applyEdit(
    d,
    op,
    newId: () => 'key-${serial++}',
    nextVersion: (id) =>
        '${versions.update(id, (v) => v + 1, ifAbsent: () => 40)}',
  );
  Map clip(ProjectDocument d, String id) =>
      (d.toJson()['sequences'][0]['tracks'][0]['items'] as List).singleWhere(
        (c) => c['id'] == id,
      ) as Map;
  ProjectDocument curve(ProjectDocument d) => edit(
    edit(d, SetOpacityKeyframe(id, Q.of(0), 0)),
    SetOpacityKeyframe(id, Q.of(2), 1),
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
    final a = curve(p), d = a.toJson(), c = clip(a, id);
    expect(clipOpacityQ16(d, c, Q.of(1)), 32768);
    expect(clipOpacityQ16(d, c, Q.of(3)), 65536);
    final graph = TimelineVideoGraph(a);
    expect(graph.sampleFrame(Q.of(101, 100)).opacityQ16, 32768);
    final segment = graph.encoderSegment(
      id,
      originalPath: '/fixture',
      streamIndex: 0,
      frameRate: FrameRate(30, 1),
    );
    expect(segment['opacityFramesQ16'][30], 32768);
    final h = edit(
      a,
      SetOpacityKeyframe(id, Q.of(0), 0, interpolation: 'hold'),
    );
    expect(clipOpacityQ16(h.toJson(), clip(h, id), Q.of(1999, 1000)), 0);
    expect(clipOpacityQ16(h.toJson(), clip(h, id), Q.of(2)), 65536);
    expect(
      edit(h, SetOpacityKeyframe(id, Q.of(0), 0, interpolation: 'hold')).hash,
      h.hash,
    );
    expect(
      () => edit(a, SetClipOpacity(id, .5)),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'ANIMATED_OPACITY_REQUIRES_EXPLICIT_KEYFRAME_EDIT',
        ),
      ),
    );
    var r = edit(a, RemoveOpacityKeyframe(id, Q.of(2)));
    r = edit(r, RemoveOpacityKeyframe(id, Q.of(0)));
    expect(r.toJson()['effects'][0]['keyframes'], isEmpty);
    expect(
      () => edit(r, RemoveOpacityKeyframe(id, Q.of(0))),
      throwsA(isA<StudioException>()),
    );
    expect(() => graph.sample(Q.of(3)), throwsA(isA<StudioException>()));
  });
  test('split/crop/rebase, trims preserve function, slip keeps clip-local curve, move does not shift local keys', () {
    final a = curve(p), split = edit(a, SplitClip(id, Q.of(1), 'right'));
    for (var f = 0; f < 90; f++) {
      expect(
        TimelineVideoGraph(split).sample(Q.of(f, 30)).opacityQ16,
        TimelineVideoGraph(a).sample(Q.of(f, 30)).opacityQ16,
      );
    }
    final effects = split.toJson()['effects'] as List;
    expect(effects.length, 2);
    final ids = [
      for (final e in effects)
        for (final k in e['keyframes']) k['id'],
    ];
    expect(ids.toSet().length, ids.length);
    final trim = edit(split, TrimClip('right', 'in', Q.of(1, 2)));
    expect(clipOpacityQ16(trim.toJson(), clip(trim, 'right')), 49152);
    final slipped = edit(trim, SlipClip('right', Q.of(-1, 2)));
    expect(clipOpacityQ16(slipped.toJson(), clip(slipped, 'right')), 49152);
    final shortened = edit(a, TrimClip(id, 'out', Q.of(-1))),
        moved = edit(shortened, MoveClip(id, Q.of(1)));
    expect(TimelineVideoGraph(moved).sample(Q.of(3, 2)).opacityQ16, 16384);
    expect(a.toJson()['effects'][0]['keyframes'].length, 2);
  });
  test('linked split clones only video curve and linked trim preserves exact boundary value', () {
    p = avFixture();
    p = curve(p);
    p = edit(p, ExtractAudioClip(id, 'audio-stream'));
    p = edit(p, SplitClip(id, Q.of(1), 'linked-right'));
    expect(p.toJson()['effects'].length, 2);
    p = edit(p, TrimClip('linked-right', 'in', Q.of(1, 2)));
    expect(clipOpacityQ16(p.toJson(), clip(p, 'linked-right')), 49152);
  });
  test('off-grid, invalid range/type and locked implicit curve edits refuse whole operation', () {
    final a = curve(p), hash = a.hash;
    for (final op in [
      SetOpacityKeyframe(id, Q.of(1, 1000), .5),
      SetOpacityKeyframe(id, Q.of(4), .5),
      SetOpacityKeyframe(id, Q.of(1), 1.1),
      SetOpacityKeyframe(id, Q.of(1), .5, interpolation: 'bezier'),
    ]) {
      expect(() => edit(a, op), throwsA(isA<StudioException>()));
      expect(a.hash, hash);
    }
    final d = a.toJson();
    d['sequences'][0]['tracks'][0]['items'][0]['lockedFields'] = [
      'effects.value',
    ];
    final locked = ProjectDocument.fromJson(d);
    expect(
      () => edit(locked, TrimClip(id, 'in', Q.of(1))),
      throwsA(
        isA<StudioException>().having((e) => e.code, 'code', 'FIELD_LOCKED'),
      ),
    );
  });
  test('editing disabled animation preserves enable state; crop extension holds edges and unsupported values remain refused', () {
    final a = curve(p), d = a.toJson();
    d['effects'][0]['enabled'] = false;
    final disabled = ProjectDocument.fromJson(d),
        changed = edit(disabled, SetOpacityKeyframe(id, Q.of(1), .3));
    expect(changed.toJson()['effects'][0]['enabled'], false);
    expect(clipOpacityQ16(changed.toJson(), clip(changed, id), Q.of(1)), 65536);
    var short = edit(a, TrimClip(id, 'in', Q.of(1)));
    short = edit(short, TrimClip(id, 'in', Q.of(-1)));
    expect(clipOpacityQ16(short.toJson(), clip(short, id), Q.of(0)), 32768);
    expect(clipOpacityQ16(short.toJson(), clip(short, id), Q.of(1, 2)), 32768);
    final bad = a.toJson();
    bad['effects'][0]['keyframes'][0]['value'] = [0, 1];
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(bad)),
      throwsA(isA<StudioException>()),
    );
  });
}
