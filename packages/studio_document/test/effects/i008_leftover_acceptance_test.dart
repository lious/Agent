import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

String content(ProjectDocument p) =>
    contentHash(p.toJson()..remove('revision'));

Map clipOf(ProjectDocument p, String id) {
  for (final t in p.toJson()['sequences'][0]['tracks']) {
    for (final c in t['items']) {
      if (c['id'] == id) return c as Map;
    }
  }
  throw StateError('missing clip');
}

double localX(ProjectDocument p, String id, Q local) =>
    clipTransform2d(p.toJson(), clipOf(p, id), local)?['translateX'] ?? 0;

ProjectDocument localVideo() => ProjectDocument.fromJson(
  jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
      as Map<String, dynamic>,
);

ProjectDocument adjacentPair({
  required String leftId,
  required String rightId,
  Q? leftSourceStart,
  Q? rightSourceStart,
}) {
  final d = localVideo().toJson();
  final s = d['sequences'][0], t = s['tracks'][0], left = t['items'][0];
  left['id'] = leftId;
  left['timelineRange'] = {
    'start': Q.of(0).toJson(),
    'duration': Q.of(1).toJson(),
  };
  left['sourceRange'] = {
    'start': (leftSourceStart ?? Q.of(1, 2)).toJson(),
    'duration': Q.of(1).toJson(),
  };
  final right = jsonDecode(jsonEncode(left)) as Map<String, dynamic>;
  right['id'] = rightId;
  right['timelineRange']['start'] = Q.of(1).toJson();
  right['sourceRange']['start'] = (rightSourceStart ?? Q.of(1)).toJson();
  t['items'] = [left, right];
  s['duration'] = Q.of(2).toJson();
  return ProjectDocument.fromJson(d);
}

void main() {
  var serial = 0;
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'i008-${serial++}',
    nextVersion: (_) => '${serial++}',
  );

  TransformKeyframeProposal proposal(ProjectDocument before) =>
      TransformKeyframeProposal(
        before: before,
        newId: () => 'i008-${serial++}',
        nextVersion: (_) => '${serial++}',
      );

  setUp(() => serial = 0);

  test('missing dissolve and luma handles are refused without freeze fallback or a document change', () {
    final dissolveBase = adjacentPair(
      leftId: 'dissolve-left',
      rightId: 'dissolve-right',
    );
    for (final side in ['head', 'tail']) {
      final d = dissolveBase.toJson();
      final c = d['sequences'][0]['tracks'][0]['items'][side == 'head' ? 1 : 0];
      c['sourceRange']['start'] = Q.of(side == 'head' ? 0 : 2).toJson();
      final before = ProjectDocument.fromJson(d);
      final hash = content(before);
      expect(
        () => edit(
          before,
          SetDissolve(
            'dissolve-left',
            'dissolve-right',
            Q.of(1, 5),
            Q.of(1, 5),
          ),
        ),
        throwsCode('TRANSITION_HANDLE_MISSING'),
      );
      expect(content(before), hash);
    }

    final lumaBase = adjacentPair(leftId: 'luma-left', rightId: 'luma-right');
    for (final side in ['head', 'tail']) {
      final d = lumaBase.toJson();
      final c = d['sequences'][0]['tracks'][0]['items'][side == 'head' ? 1 : 0];
      c['sourceRange']['start'] = Q.of(side == 'head' ? 0 : 2).toJson();
      final before = ProjectDocument.fromJson(d);
      final hash = content(before);
      expect(
        () => edit(
          before,
          SetLumaWipe(
            'luma-left',
            'luma-right',
            Q.of(1, 5),
            Q.of(1, 5),
            softness: 0.1,
          ),
        ),
        throwsCode('HANDLE_UNAVAILABLE'),
      );
      expect(content(before), hash);
    }

    // A clip that already has a transform2d curve still cannot steal missing
    // dissolve handles, and freeze is not a silent fallback.
    var curved = edit(
      dissolveBase,
      SetTransformKeyframe('dissolve-left', Q.of(0), 'translateX', 0),
    );
    curved = edit(
      curved,
      SetTransformKeyframe('dissolve-left', Q.of(1), 'translateX', 16),
    );
    final short = ProjectDocument.fromJson((() {
      final d = curved.toJson();
      d['sequences'][0]['tracks'][0]['items'][1]['sourceRange']['start'] =
          Q.of(0).toJson();
      return d;
    })());
    final curvedHash = content(short);
    expect(
      () => edit(
        short,
        SetDissolve('dissolve-left', 'dissolve-right', Q.of(1, 5), Q.of(1, 5)),
      ),
      throwsCode('TRANSITION_HANDLE_MISSING'),
    );
    expect(content(short), curvedHash);
  });

  test('transform2d linear keys stay continuous at knots, split, and trim boundaries', () {
    final base = localVideo();
    final id = base.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
        as String;
    var p = edit(base, SetTransformKeyframe(id, Q.of(0), 'translateX', 0));
    p = edit(p, SetTransformKeyframe(id, Q.of(1), 'translateX', 16));
    p = edit(p, SetTransformKeyframe(id, Q.of(3), 'translateX', 8));

    expect(localX(p, id, Q.of(0)), 0);
    expect(localX(p, id, Q.of(1, 2)), 8);
    expect(localX(p, id, Q.of(1)), 16);
    expect(localX(p, id, Q.of(2)), 12);
    expect(localX(p, id, Q.of(3)), 8);

    final split = edit(p, SplitClip(id, Q.of(1), 'right'));
    expect(localX(split, id, Q.of(1)), 16);
    expect(localX(split, 'right', Q.of(0)), 16);
    expect(
      TimelineVideoGraph(split)
          .sampleFrame(Q.of(1))
          .transform2d?['translateX'],
      16,
    );
    expect(
      TimelineVideoGraph(split)
          .sampleFrame(Q.of(2))
          .transform2d?['translateX'],
      12,
    );
    expect(localX(split, 'right', Q.of(2)), 8);

    // Trim the right remnant in by 0.5s: boundary holds the interpolated value 14.
    final trim = edit(split, TrimClip('right', 'in', Q.of(1, 2)));
    expect(
      TimelineVideoGraph(trim)
          .sampleFrame(Q.of(3, 2))
          .transform2d!['translateX'],
      14,
    );
    // The left remnant's out still matches the pre-split knot.
    expect(
      TimelineVideoGraph(trim).sampleFrame(Q.of(2) - Q.of(1, 30)).transform2d,
      isNotNull,
    );
  });

  test('a thirty-sample keyframe drag is one proposal; restoreSnapshot restores the start hash', () {
    expect(officialInversePatchKind, 'restoreSnapshot');
    final base = localVideo();
    final id = base.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
        as String;
    var start = edit(base, SetTransformKeyframe(id, Q.of(0), 'translateX', 0));
    start = edit(start, SetTransformKeyframe(id, Q.of(2), 'translateX', 16));
    final startHash = content(start);

    final drag = proposal(start);
    expect(drag.inversePatch['kind'], officialInversePatchKind);
    expect(drag.inversePatch['snapshotHash'], startHash);
    for (var i = 1; i <= 30; i++) {
      drag.stageDrag(
        SetTransformKeyframe(id, Q.of(2), 'translateX', 16 + i.toDouble()),
        from: Q.of(2),
      );
    }
    final after = drag.commit();
    expect(drag.historyNodes, 1);
    expect(content(start), startHash);
    expect(
      TimelineVideoGraph(after).sampleFrame(Q.of(2)).transform2d!['translateX'],
      46,
    );
    // t=0 stays the identity translateX already present on the start curve.
    expect(
      TimelineVideoGraph(after).sampleFrame(Q.of(1)).transform2d!['translateX'],
      23,
    );

    final restored = drag.restoreSnapshot();
    expect(content(restored), startHash);
    expect(
      TimelineVideoGraph(restored)
          .sampleFrame(Q.of(2))
          .transform2d!['translateX'],
      16,
    );
    expect(restored.revision, after.revision + BigInt.one);
    expect(() => drag.stageDrag(SetTransformKeyframe(id, Q.of(2), 'translateX', 0)),
        throwsCode(proposalClosed));
  });

  test('cancel writes nothing; a failing later key does not half-write the proposal', () {
    final base = localVideo();
    final id = base.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
        as String;
    final startHash = content(base);
    final cancelled = proposal(base);
    cancelled.stageDrag(
      SetTransformKeyframe(id, Q.of(0), 'translateX', 8),
      from: Q.of(0),
    );
    cancelled.cancel();
    expect(cancelled.historyNodes, 0);
    expect(content(base), startHash);
    expect(() => cancelled.restoreSnapshot(), throwsCode(proposalNotCommitted));

    final failing = proposal(base);
    failing.stage(SetTransformKeyframe(id, Q.of(0), 'translateX', 0));
    failing.stage(
      SetTransformKeyframe(
        id,
        Q.of(1),
        'translateX',
        8,
        interpolation: 'bezier',
      ),
    );
    expect(() => failing.commit(), throwsCode('UNSUPPORTED_EDIT_TECHNIQUE'));
    expect(content(base), startHash);
    expect(failing.historyNodes, 0);
  });
}
