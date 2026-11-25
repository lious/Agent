import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

ProjectDocument fixture() => ProjectDocument.fromJson(
  jsonDecode(File('fixtures/project/local-video.json').readAsStringSync())
      as Map<String, dynamic>,
);
void main() {
  test('timeline graph exact half-open source map, split/non-ripple trim and immutable snapshot', () {
    final original = fixture();
    final id =
        original.toJson()['sequences'][0]['tracks'][0]['items'][0]['id']
            as String;
    var version = 100;
    ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
      p,
      op,
      newId: () => 'graph-${version++}',
      nextVersion: (_) => '${version++}',
    );
    final split = edit(original, SplitClip(id, Q.of(1), 'graph-right'));
    final graph = TimelineVideoGraph(split);
    expect(graph.sample(Q.of(999, 1000)).clipId, id);
    expect(graph.sample(Q.of(1)).clipId, 'graph-right');
    expect(graph.sample(Q.of(5, 4)).sourceTime, Q.of(5, 4));
    final trimmed = edit(
      split,
      TrimClip('graph-right', 'in', Q.of(1, 2), ripple: false),
    );
    final mapped = TimelineVideoGraph(trimmed);
    expect(mapped.sample(Q.of(5, 4)).isGap, isTrue);
    expect(mapped.sample(Q.of(3, 2)).sourceTime, Q.of(3, 2));
    expect(graph.sample(Q.of(5, 4)).isGap, isFalse);
    expect(graph.snapshotHash, split.hash);
    final encoded = graph.encoderSegment(
      'graph-right',
      originalPath: '/synthetic/original.mp4',
      streamIndex: 0,
      frameRate: FrameRate(30, 1),
    );
    expect(encoded['startFrame'], 30);
    expect(encoded['frameCount'], 60);
    expect(
      Q.fromJson(encoded['sourceStart']),
      graph.sample(Q.of(1)).sourceTime,
    );

    expect(() => graph.sample(Q.of(3)), throwsA(isA<StudioException>()));
    expect(() => graph.sample(Q.of(-1)), throwsA(isA<StudioException>()));
  });
  test('disabled clip renders a gap; unsupported background refuses rather than black substitution', () {
    final d = fixture().toJson();
    d['sequences'][0]['tracks'][0]['items'][0]['enabled'] = false;
    expect(
      TimelineVideoGraph(ProjectDocument.fromJson(d)).sample(Q.of(1)).isGap,
      isTrue,
    );
    d['sequences'][0]['canvas']['width'] = 180;
    d['sequences'][0]['canvas']['height'] = 320;
    d['assets'][0]['streams'][0]['width'] = 180;
    d['assets'][0]['streams'][0]['height'] = 320;
    final portrait = TimelineVideoGraph(ProjectDocument.fromJson(d));
    expect([portrait.previewWidth, portrait.previewHeight], [72, 128]);
    expect(portrait.sample(Q.of(1)).isGap, isTrue);
    final captioned = applyEdit(
      fixture(),
      SetCaptions(
        CaptionStore([
          CaptionCue('cue', TimeRange(Q.of(0), Q.of(1)), 'must not disappear'),
        ]),
      ),
      newId: () => 'caption-track',
      nextVersion: (_) => '100',
    );
    expect(
      () => TimelineVideoGraph(captioned),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'CAPTION_RENDER_POLICY_NOT_IMPLEMENTED',
        ),
      ),
    );
    d['sequences'][0]['backgroundRGBA'] = [1, 0, 0, 1];
    expect(
      () => TimelineVideoGraph(ProjectDocument.fromJson(d)),
      throwsA(isA<StudioException>()),
    );
  });
}
