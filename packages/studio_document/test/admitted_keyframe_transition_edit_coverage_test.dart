import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

ProjectDocument videoFixture() => ProjectDocument.fromJson(
  jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
      as Map<String, dynamic>,
);

ProjectDocument lumaFixture() {
  final d = videoFixture().toJson();
  final s = d['sequences'][0], t = s['tracks'][0], left = t['items'][0];
  left['id'] = 'luma-left';
  left['timelineRange'] = {
    'start': Q.of(0).toJson(),
    'duration': Q.of(1).toJson(),
  };
  left['sourceRange'] = {
    'start': Q.of(1, 2).toJson(),
    'duration': Q.of(1).toJson(),
  };
  final right = jsonDecode(jsonEncode(left)) as Map<String, dynamic>;
  right['id'] = 'luma-right';
  right['timelineRange']['start'] = Q.of(1).toJson();
  right['sourceRange']['start'] = Q.of(1).toJson();
  t['items'] = [left, right];
  s['duration'] = Q.of(2).toJson();
  return ProjectDocument.fromJson(d);
}

void main() {
  var serial = 0;
  final versions = <String, int>{};
  ProjectDocument apply(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'adm-kf-edit-${serial++}',
    nextVersion: (id) =>
        '${versions.update(id, (v) => v + 1, ifAbsent: () => 20)}',
  );

  String videoId(ProjectDocument p) =>
      p.toJson()['sequences'][0]['tracks'][0]['items'].firstWhere(
            (x) => x['source'] != null,
          )['id']
          as String;

  List<Map> videoMedia(ProjectDocument p) => [
    for (final c in p.toJson()['sequences'][0]['tracks'][0]['items'])
      if (c['source'] != null) c as Map,
  ];

  Map clipById(ProjectDocument p, String id) =>
      videoMedia(p).singleWhere((c) => c['id'] == id);

  Map transformEffect(ProjectDocument p, String clipId) {
    final ids = clipById(p, clipId)['effectIds'] as List;
    return (p.toJson()['effects'] as List).singleWhere(
      (e) => ids.contains(e['id']) && e['type'] == 'transform2d',
    ) as Map;
  }

  setUp(() {
    serial = 0;
    versions.clear();
  });

  test('official overwrite paste crops a destination transform2d curve at interpolated boundaries', () {
    var p = videoFixture();
    final destId = videoId(p);
    p = apply(p, SetTransformKeyframe(destId, Q.of(0), 'translateX', 0));
    p = apply(p, SetTransformKeyframe(destId, Q.of(2), 'translateX', 16));
    final payload = buildClipboard(p, [destId]);
    p = apply(p, PasteClips(payload, at: Q.of(1), mode: 'overwrite'));
    final clips = videoMedia(p);
    expect(clips, hasLength(2));
    final left = clips.singleWhere((c) => c['id'] == destId);
    final incoming = clips.singleWhere((c) => c['id'] != destId);
    expect(Q.fromJson(left['timelineRange']['start']), Q.of(0));
    expect(Q.fromJson(left['timelineRange']['duration']), Q.of(1));
    expect(Q.fromJson(incoming['timelineRange']['start']), Q.of(1));
    expect(Q.fromJson(incoming['timelineRange']['duration']), Q.of(3));
    final leftFx = transformEffect(p, left['id'] as String);
    final incomingFx = transformEffect(p, incoming['id'] as String);
    expect(leftFx['id'], isNot(incomingFx['id']));
    expect(leftFx['type'], 'transform2d');
    expect(incomingFx['type'], 'transform2d');
    expect(leftFx['owner']['id'], left['id']);
    expect(incomingFx['owner']['id'], incoming['id']);
    final leftKeys = leftFx['keyframes'] as List;
    final incomingKeys = incomingFx['keyframes'] as List;
    expect(leftKeys, isNotEmpty);
    expect(incomingKeys, isNotEmpty);
    for (final k in [...leftKeys, ...incomingKeys]) {
      expect(k['param'], 'translateX');
    }
    expect(Q.fromJson(leftKeys.first['localTime']), Q.of(0));
    expect((leftKeys.first['value'] as num).toDouble(), closeTo(0, 1e-9));
    expect(Q.fromJson(leftKeys.last['localTime']), Q.of(1));
    expect((leftKeys.last['value'] as num).toDouble(), closeTo(8, 1e-9));
    expect(Q.fromJson(incomingKeys.first['localTime']), Q.of(0));
    expect((incomingKeys.first['value'] as num).toDouble(), closeTo(0, 1e-9));
    // Incoming copy is the full uncropped clip, so clip-local keys stay at 0
    // and 2 (16 at t=2 holds through the tail). Destination remnant is cropped
    // with an interpolated boundary at local 1.
    expect(Q.fromJson(incomingKeys.last['localTime']), Q.of(2));
    expect((incomingKeys.last['value'] as num).toDouble(), closeTo(16, 1e-9));
    expect(
      TimelineVideoGraph(p).sampleFrame(Q.of(1, 2)).transform2d!['translateX'],
      closeTo(4, 1e-9),
    );
  });

  test('luma split and trim refuse with TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL; slip refuses without half-write', () {
    final p = apply(
      lumaFixture(),
      SetLumaWipe(
        'luma-left',
        'luma-right',
        Q.of(1, 5),
        Q.of(1, 5),
        softness: 0.1,
      ),
    );
    final hash = p.hash;
    final before = jsonEncode(p.toJson());
    for (final op in [
      SplitClip('luma-left', Q.of(1, 2), 'cut'),
      TrimClip('luma-left', 'out', Q.of(-1, 30)),
    ]) {
      expect(
        () => apply(p, op),
        code('TRANSITION_RANGE_EDIT_REQUIRES_REMOVAL'),
      );
      expect(p.hash, hash);
      expect(jsonEncode(p.toJson()), before);
    }
    // Slip is allowed for a core Transition when handles revalidate, but a
    // sequence-owned lumaWipe is not silently dropped or rewritten. Both a
    // handle-short slip and a still-covered slip refuse the whole command.
    for (final delta in [Q.of(-1), Q.of(1, 5)]) {
      expect(
        () => apply(p, SlipClip('luma-right', delta)),
        code('UNSUPPORTED_EDIT_TECHNIQUE'),
      );
      expect(p.hash, hash);
      expect(jsonEncode(p.toJson()), before);
    }
    expect(lumaWipeEffects(p.toJson()), hasLength(1));
  });

  test('overwrite paste into a luma window is refused and does not fall back to dissolve; removal then overwrite is accepted', () {
    final p = apply(
      lumaFixture(),
      SetLumaWipe(
        'luma-left',
        'luma-right',
        Q.of(1, 5),
        Q.of(1, 5),
        softness: 0.1,
      ),
    );
    final hash = p.hash;
    final mid = buildClipboard(lumaFixture(), ['luma-left']);
    expect(
      () => apply(p, PasteClips(mid, at: Q.of(1, 2), mode: 'overwrite')),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'TRANSITION_NOT_ADJACENT',
        ),
      ),
    );
    expect(p.hash, hash);
    expect(p.toJson()['transitions'], isEmpty);
    expect(lumaWipeEffects(p.toJson()), hasLength(1));
    final rightPayload = buildClipboard(lumaFixture(), ['luma-right']);
    expect(
      () => apply(p, PasteClips(rightPayload, at: Q.of(0), mode: 'overwrite')),
      throwsA(
        isA<StudioException>().having((e) => e.code, 'code', 'REF_NOT_FOUND'),
      ),
    );
    expect(p.hash, hash);
    expect(p.toJson()['transitions'], isEmpty);

    final id = lumaWipeEffects(p.toJson()).single['id'] as String;
    final removed = apply(p, RemoveLumaWipe(id));
    expect(lumaWipeEffects(removed.toJson()), isEmpty);
    final out = apply(
      removed,
      PasteClips(mid, at: Q.of(1, 2), mode: 'overwrite'),
    );
    expect(lumaWipeEffects(out.toJson()), isEmpty);
    expect(out.toJson()['transitions'], isEmpty);
    expect(videoMedia(out), isNotEmpty);
  });
}
