import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Matcher throwsCode(String code) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', code));

void main() {
  test('piecewise knots map local 3s to source offset 3s and invert exactly', () {
    final map = RetimeMap.piecewise(
      knots: [
        RetimeKnot(Q.of(0), Q.of(0)),
        RetimeKnot(Q.of(2), Q.of(1)),
        RetimeKnot(Q.of(4), Q.of(5)),
      ],
    );
    expect(map.duration, Q.of(4));
    expect(map.sourceDuration, Q.of(5));
    expect(map.sourceAt(Q.of(3)), Q.of(3));
    expect(map.invert(Q.of(3)), Q.of(3));
    expect(map.sourceAt(Q.of(2)), Q.of(1));
    expect(map.invert(Q.of(1)), Q.of(2));
    expect(map.invert(map.sourceAt(Q.of(3))), Q.of(3));
  });

  test('split at 3s inserts the same mapping point on both segments', () {
    final map = RetimeMap.piecewise(
      knots: [
        RetimeKnot(Q.of(0), Q.of(0)),
        RetimeKnot(Q.of(2), Q.of(1)),
        RetimeKnot(Q.of(4), Q.of(5)),
      ],
    );
    final mid = map.sourceAt(Q.of(3));
    expect(mid, Q.of(3));
    final (left, right) = map.split(Q.of(3));
    expect(left.duration, Q.of(3));
    expect(left.sourceDuration, mid);
    expect(left.sourceAt(Q.of(3)), mid);
    expect(left.knots.last.u, Q.of(3));
    expect(left.knots.last.v, mid);
    expect(right.duration, Q.of(1));
    expect(right.sourceDuration, Q.of(2));
    expect(right.sourceAt(Q.of(0)), Q.of(0));
    expect(right.sourceAt(Q.of(1)), Q.of(2));
  });

  test('30000/1001 with 48k has no cumulative drift through a linear TimeMap', () {
    final fps = FrameRate(30000, 1001);
    final duration = fps.frameTime(BigInt.from(300));
    expect(duration, Q.of(1001, 100));
    final map = RetimeMap.linear(rate: Q.of(1), duration: duration);
    var t = Q.of(0);
    for (var i = 0; i < 300; i++) {
      t = t + fps.frameTime(BigInt.one);
      expect(map.sourceAt(t), t);
    }
    expect(t, duration);
    expect(map.sourceAt(duration), duration);
    expect(map.invert(duration), duration);
    expect(sampleIndex(duration, 48000, Rounding.floor), BigInt.from(480480));
    expect(sampleIndex(duration, 48000, Rounding.ceil), BigInt.from(480480));
    expect(
      sampleIndex(map.sourceAt(duration), 48000, Rounding.tiesToEven),
      BigInt.from(480480),
    );
    var samples = BigInt.zero;
    for (var i = 0; i < 300; i++) {
      final a = map.sourceAt(fps.frameTime(BigInt.from(i)));
      final b = map.sourceAt(fps.frameTime(BigInt.from(i + 1)));
      samples +=
          sampleIndex(b, 48000, Rounding.tiesToEven) -
          sampleIndex(a, 48000, Rounding.tiesToEven);
    }
    expect(samples, BigInt.from(480480));
  });

  test('caption source anchors use inverse TimeMap, not a frame index', () {
    final fps = FrameRate(30000, 1001);
    final map = RetimeMap.piecewise(
      knots: [
        RetimeKnot(Q.of(0), Q.of(0)),
        RetimeKnot(Q.of(2), Q.of(1)),
        RetimeKnot(Q.of(4), Q.of(5)),
      ],
    );
    final u = Q.of(3);
    final v = map.sourceAt(u);
    expect(map.invert(v), u);
    final misused = fps.frameTime(fps.frameIndex(v, Rounding.floor));
    expect(misused == u, isFalse);
    expect(map.invert(v) == misused, isFalse);
  });

  test('optical-flow interpolation is refused and does not steal duration', () {
    final knots = [
      RetimeKnot(Q.of(0), Q.of(0)),
      RetimeKnot(Q.of(4), Q.of(5)),
    ];
    expect(
      () => RetimeMap.piecewise(knots: knots, interpolation: 'opticalFlow'),
      throwsCode(retimeInterpUnsupported),
    );
    expect(
      () => RetimeMap.piecewise(knots: knots, interpMode: 'frameBlend'),
      throwsCode(retimeInterpUnsupported),
    );
    final kept = RetimeMap.piecewise(knots: knots);
    expect(kept.duration, Q.of(4));
    expect(kept.sourceDuration, Q.of(5));
  });

  test('reverse, freeze, and non-monotone maps are refused, not faked as +rate', () {
    expect(
      () => RetimeMap.piecewise(
        knots: [RetimeKnot(Q.of(0), Q.of(0)), RetimeKnot(Q.of(4), Q.of(5))],
        direction: -1,
      ),
      throwsCode(retimeDirectionUnsupported),
    );
    expect(
      () => RetimeMap.piecewise(
        knots: [RetimeKnot(Q.of(0), Q.of(0)), RetimeKnot(Q.of(4), Q.of(0))],
      ),
      throwsCode(retimeNonMonotone),
    );
    expect(
      () => RetimeMap.piecewise(
        knots: [RetimeKnot(Q.of(1), Q.of(0)), RetimeKnot(Q.of(4), Q.of(5))],
      ),
      throwsCode(retimeEndpointMismatch),
    );
    expect(
      () => RetimeMap.linear(rate: Q.of(0), duration: Q.of(4)),
      throwsCode('INVALID_RANGE'),
    );
  });

  test('nested cycles and depth over 8 are refused', () {
    final cycle = NestResolver({
      'seq-a': [NestEdge(clipId: 'n1', childSequenceId: 'seq-b', version: '1')],
      'seq-b': [NestEdge(clipId: 'n2', childSequenceId: 'seq-a', version: '1')],
    });
    expect(() => cycle.validate(root: 'seq-a'), throwsCode(nestCycle));

    final chain = <String, List<NestEdge>>{};
    for (var i = 0; i < 9; i++) {
      chain['seq-$i'] = [
        NestEdge(
          clipId: 'n$i',
          childSequenceId: 'seq-${i + 1}',
          version: '1',
        ),
      ];
    }
    expect(() => NestResolver(chain).validate(root: 'seq-0'), throwsCode(nestDepth));

    final ok = NestResolver({
      'root': [NestEdge(clipId: 'n', childSequenceId: 'child', version: '1')],
    });
    ok.validate(root: 'root');
  });

  test('sourceAt composes through a nest stack with exact Q, not frame indexes', () {
    final outer = RetimeMap.linear(rate: Q.of(2), duration: Q.of(4));
    final inner = RetimeMap.piecewise(
      knots: [
        RetimeKnot(Q.of(0), Q.of(0)),
        RetimeKnot(Q.of(2), Q.of(1)),
        RetimeKnot(Q.of(8), Q.of(5)),
      ],
    );
    // outer 1x? wait rate 2: local 2 → source 4, but inner duration is 8...
    // Use outer rate 2 duration 4 → source 8, which is inner duration.
    final resolver = NestResolver({
      'root': [
        NestEdge(
          clipId: 'nest-1',
          childSequenceId: 'child',
          version: '1',
          timeMap: outer,
        ),
      ],
    });
    resolver.validate(root: 'root');
    final v = resolver.sourceAt(Q.of(2), [outer, inner]);
    // outer.sourceAt(2)=4; inner at u=4 in segment (2,1)-(8,5):
    // 1 + (4-2)*(5-1)/(8-2) = 1 + 2*4/6 = 1 + 8/6 = 1 + 4/3 = 7/3
    expect(v, Q.of(7, 3));
    expect(inner.sourceAt(outer.sourceAt(Q.of(2))), v);
  });
}
