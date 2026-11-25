import 'package:test/test.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'dissolve_test.dart' show dissolveFixture;

void main() {
  var serial = 3000;
  ProjectDocument edit(ProjectDocument p, EditOperation op) => applyEdit(
    p,
    op,
    newId: () => 'raster-${serial++}',
    nextVersion: (_) => '${serial++}',
  );
  test(
    'strict crop/colour bounds, finite values and captured parameter ownership',
    () {
      for (final value in [-.01, 1.01, double.nan, double.infinity]) {
        expect(
          () => SetClipCrop('dissolve-left', {...identityCrop, 'left': value}),
          throwsA(isA<StudioException>()),
        );
      }
      expect(
        () => SetClipCrop('dissolve-left', {...identityCrop, 'left': 1}),
        throwsA(isA<StudioException>()),
      );
      for (final e in {
        'exposureStops': 8.01,
        'contrast': 2.01,
        'saturation': -.01,
      }.entries) {
        expect(
          () => SetClipColorBasic('dissolve-left', {
            ...identityColorBasic,
            e.key: e.value,
          }),
          throwsA(isA<StudioException>()),
        );
      }
      expect(() => captureRasterEffects({}), throwsA(isA<StudioException>()));
      expect(
        () => captureRasterEffects({
          'lut': {'x': 1},
        }),
        throwsA(isA<StudioException>()),
      );
      final p = {...identityCrop, 'left': .25};
      final op = SetClipCrop('dissolve-left', p);
      p['left'] = .75;
      expect(op.parameters['left'], .25);
    },
  );
  test('static nodes sort crop transform colour opacity; same-time graph, noop, locks and unknown animation refuse', () {
    var p = edit(dissolveFixture(), const SetClipOpacity('dissolve-left', .5));
    p = edit(
      p,
      SetClipColorBasic('dissolve-left', {
        ...identityColorBasic,
        'exposureStops': 1,
      }),
    );
    p = edit(
      p,
      SetClipTransform('dissolve-left', {
        ...identityTransform2d,
        'translateX': 8,
      }),
    );
    p = edit(p, SetClipCrop('dissolve-left', {...identityCrop, 'left': .25}));
    final d = p.toJson(), clip = d['sequences'][0]['tracks'][0]['items'][0];
    expect(
      admittedClipEffects(d, clip).map((e) => e['type']),
      visualEffectOrder,
    );
    expect(TimelineVideoGraph(p).sample(Q.of(1, 2)).sourceTime, Q.of(1));
    expect(
      TimelineVideoGraph(p).sample(Q.of(1, 2)).rasterEffects!['crop']!['left'],
      .25,
    );
    expect(
      edit(
        p,
        SetClipCrop('dissolve-left', {...identityCrop, 'left': .25}),
      ).hash,
      p.hash,
    );
    final locked = p.toJson();
    locked['sequences'][0]['tracks'][0]['items'][0]['lockedFields'] = [
      'effects',
    ];
    expect(
      () => edit(
        ProjectDocument.fromJson(locked),
        SetClipCrop('dissolve-left', identityCrop),
      ),
      throwsA(isA<StudioException>()),
    );
    final unknown = p.toJson();
    final e = (unknown['effects'] as List).singleWhere(
      (e) => e['type'] == 'crop',
    );
    e['keyframes'] = [
      {
        'id': 'bad-animation',
        'param': 'left',
        'localTime': Q.of(0).toJson(),
        'value': .25,
        'interpolation': 'linear',
        'easing': null,
      },
    ];
    final preservedAnimation = ProjectDocument.fromJson(unknown);
    expect(
      () => requireLocalEditingWritable(preservedAnimation),
      throwsA(
        isA<StudioException>().having(
          (e) => e.code,
          'code',
          'RASTER_ANIMATION_NOT_IMPLEMENTED',
        ),
      ),
    );
    expect(
      preservedAnimation.toJson()['effects'].singleWhere(
        (e) => e['type'] == 'crop',
      )['keyframes'],
      e['keyframes'],
    );
    final order = p.toJson();
    (order['sequences'][0]['tracks'][0]['items'][0]['effectIds'] as List)
        .setAll(0, (clip['effectIds'] as List).reversed);
    expect(
      () => requireLocalEditingWritable(ProjectDocument.fromJson(order)),
      throwsA(isA<StudioException>()),
    );
  });
  test('split clone ownership and slip preserve source-space crop/colour; two-leg encoder recipes carry both', () {
    var p = edit(
      dissolveFixture(),
      SetClipCrop('dissolve-left', {...identityCrop, 'left': .25}),
    );
    p = edit(
      p,
      SetClipColorBasic('dissolve-left', {
        ...identityColorBasic,
        'contrast': 0,
      }),
    );
    final split = edit(
      p,
      SplitClip('dissolve-left', Q.of(1, 2), 'raster-split'),
    );
    final d = split.toJson(), c = d['sequences'][0]['tracks'][0]['items'][1];
    expect(
      admittedClipEffects(
        d,
        c,
      ).every((e) => e['owner']['id'] == 'raster-split'),
      isTrue,
    );
    expect(
      TimelineVideoGraph(split).sample(Q.of(3, 4)).rasterEffects,
      TimelineVideoGraph(p).sample(Q.of(3, 4)).rasterEffects,
    );
    p = edit(p, SlipClip('dissolve-left', Q.of(1, 5)));
    p = edit(p, SetClipCrop('dissolve-right', {...identityCrop, 'right': .75}));
    p = edit(
      p,
      SetDissolve('dissolve-left', 'dissolve-right', Q.of(1, 5), Q.of(1, 5)),
    );
    final g = TimelineVideoGraph(p), v = g.sample(Q.of(1));
    expect(v.sourceTime, Q.of(17, 10));
    expect(v.secondary!.sourceTime, Q.of(1));
    final parts = g.compileDissolves({
      'dissolve-left': {'path': '/a', 'streamIndex': 0},
      'dissolve-right': {'path': '/b', 'streamIndex': 0},
    });
    expect(
      parts
          .where((p) => p['secondary'] != null)
          .every(
            (p) =>
                p['rasterEffects'] != null &&
                p['secondary']['rasterEffects'] != null,
          ),
      isTrue,
    );
  });
}
