import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';

void main() {
  var counter = 100;
  ProjectDocument fixture() => ProjectDocument.fromJson(
    jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'transform-${counter++}',
    nextVersion: (_) => '${counter++}',
  );
  String id(ProjectDocument p) =>
      p.toJson()['sequences'][0]['tracks'][0]['items'][0]['id'] as String;
  test('registered transform preserves opacity curves, order, split ownership and slip/trim semantics', () {
    var p = fixture();
    final cid = id(p);
    p = edit(p, SetOpacityKeyframe(cid, Q.of(0), 0));
    p = edit(p, SetOpacityKeyframe(cid, Q.of(2), 1));
    p = edit(
      p,
      SetClipTransform(cid, {...identityTransform2d, 'translateX': 16}),
    );
    final g = TimelineVideoGraph(p);
    expect(g.sampleFrame(Q.of(1)).opacityQ16, 32768);
    expect(g.sampleFrame(Q.of(1)).transform2d!['translateX'], 16);
    p = edit(p, SetOpacityKeyframe(cid, Q.of(1), .2));
    expect(p.toJson()['effects'].length, 2);
    final original = p;
    p = edit(p, SplitClip(cid, Q.of(1), 'transformed-right'));
    expect(p.toJson()['effects'].length, 4);
    final owners = (p.toJson()['effects'] as List).map(
      (e) => '${e['type']}:${e['owner']['id']}',
    );
    expect(owners.toSet().length, 4);
    for (var f = 0; f < 90; f++) {
      final a = TimelineVideoGraph(original).sampleFrame(Q.of(f, 30)),
          b = TimelineVideoGraph(p).sampleFrame(Q.of(f, 30));
      expect(b.opacityQ16, a.opacityQ16);
      expect(b.transform2d, a.transform2d);
    }
    p = edit(p, TrimClip('transformed-right', 'in', Q.of(1, 2)));
    p = edit(p, SlipClip('transformed-right', Q.of(-1, 2)));
    expect(
      TimelineVideoGraph(p).sampleFrame(Q.of(3, 2)).transform2d!['translateX'],
      16,
    );
  });
  test('static transform identity bypass, value noop, readonly unsupported animation/order and lock protection', () {
    var p = fixture();
    final cid = id(p);
    p = edit(p, SetClipTransform(cid, identityTransform2d));
    expect(TimelineVideoGraph(p).sample(Q.of(0)).transform2d, isNull);
    expect(edit(p, SetClipTransform(cid, identityTransform2d)).hash, p.hash);
    final d = p.toJson();
    d['sequences'][0]['tracks'][0]['items'][0]['lockedFields'] = ['effects'];
    final locked = ProjectDocument.fromJson(d);
    expect(
      () => edit(
        locked,
        SetClipTransform(cid, {...identityTransform2d, 'scaleX': 2}),
      ),
      throwsA(isA<StudioException>()),
    );
    final unsupported = p.toJson();
    unsupported['effects'][0]['keyframes'] = [
      {
        'id': 'unsupported-transform-key',
        'param': 'scaleX',
        'localTime': Q.of(0).toJson(),
        'value': 1,
        'interpolation': 'linear',
        'easing': null,
      },
    ];
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(unsupported)),
      throwsA(isA<StudioException>()),
    );
    p = edit(p, SetClipOpacity(cid, .5));
    final swapped = p.toJson();
    swapped['sequences'][0]['tracks'][0]['items'][0]['effectIds'] =
        (swapped['sequences'][0]['tracks'][0]['items'][0]['effectIds'] as List)
            .reversed
            .toList();
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(swapped)),
      throwsA(isA<StudioException>()),
    );
  });
  test('finite static transform bounds, anchor, singular matrix and unknown field rejection', () {
    for (final v in <Map<String, double>>[
      {...identityTransform2d, 'scaleX': 0},
      {...identityTransform2d, 'scaleY': 101},
      {...identityTransform2d, 'anchorX': -1},
      {...identityTransform2d, 'translateX': double.nan},
      {...identityTransform2d, 'translateX': 1000001},
      {...identityTransform2d, 'extra': 1},
      {...identityTransform2d, 'scaleY': .00000001},
    ]) {
      expect(
        () => SetClipTransform('clip', v),
        throwsA(isA<StudioException>()),
      );
    }
  });
}
