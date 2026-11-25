import 'dart:math';

import 'package:studio_document/studio_document.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:test/test.dart';

import 'edit_algebra_test.dart' as f;
import 'multi_move_test.dart' as m;

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
SnapPoint cut(String id, Q time) =>
    SnapPoint(SnapKind.cut, id, time, ownerClipId: id);
MoveSnap solve(
  Q delta,
  List<SnapPoint> targets, {
  Q? scale,
  Set<String> exclude = const {},
  Q Function(Q)? quantize,
}) => resolveMoveSnap(
  sources: [cut('moving', Q.of(0))],
  targets: targets,
  excludedClipIds: exclude,
  requestedDelta: delta,
  viewport: TimelineViewport(
    origin: Q.of(0),
    pixelsPerSecond: scale ?? Q.of(100),
  ),
  referenceTime: Q.of(0),
  quantize: quantize ?? (q) => q,
);
void main() {
  test('exact logical viewport roundtrip/pan/zoom, invalid scales and overflow refuse', () {
    final v = TimelineViewport(
      origin: Q.of(7, 3),
      pixelsPerSecond: Q.of(125, 2),
      logicalOrigin: Q.of(20),
    );
    for (final q in [
      Q.of(-5, 7),
      Q.of(0),
      Q.of(1001, 30000),
      Q.of(12345, 67),
    ]) {
      expect(v.timeAt(v.pixelAt(q)), q);
    }
    expect(
      () => TimelineViewport(origin: Q.of(0), pixelsPerSecond: Q.of(0)),
      code('SNAP_SCALE_INVALID'),
    );
    expect(
      () => TimelineViewport(origin: Q.of(0), pixelsPerSecond: Q.of(-1)),
      code('SNAP_SCALE_INVALID'),
    );
    expect(() => v.pixelAt(Q(maxI64, BigInt.one)), code('TIME_OVERFLOW'));
  });
  test('eight logical pixels inclusive, just outside and zoomed threshold are exact', () {
    final t = [SnapPoint(SnapKind.playhead, 'head', Q.of(1))];
    expect(solve(Q.of(92, 100), t).delta, Q.of(1));
    expect(solve(Q.of(919999, 1000000), t).target, isNull);
    expect(solve(Q.of(92, 100), t, scale: Q.of(200)).target, isNull);
    expect(solve(Q.of(96, 100), t, scale: Q.of(200)).delta, Q.of(1));
  });
  test('nearest precedes type; tied distance playhead/cut/marker then ID, independent of traversal', () {
    final head = SnapPoint(SnapKind.playhead, 'z-head', Q.of(104, 100)),
        a = cut('a-cut', Q.of(96, 100)),
        b = cut('b-cut', Q.of(104, 100)),
        marker = SnapPoint(SnapKind.marker, 'marker', Q.of(101, 100));
    expect(solve(Q.of(1), [head, a, b, marker]).target!.id, 'marker');
    expect(solve(Q.of(1), [a, b, head]).target!.id, 'z-head');
    final random = Random(27);
    for (var i = 0; i < 100; i++) {
      final ts = [a, b]..shuffle(random);
      expect(solve(Q.of(1), ts).target!.id, 'a-cut');
    }
  });
  test('selected owners including linked audio are never targets', () {
    final own = cut('linked-audio', Q.of(96, 100)),
        stationary = cut('stationary', Q.of(1));
    expect(
      solve(
        Q.of(96, 100),
        [own, stationary],
        exclude: {'moving', 'linked-audio'},
      ).target!.id,
      'stationary',
    );
    expect(
      solve(Q.of(96, 100), [own], exclude: {'linked-audio'}).target,
      isNull,
    );
  });
  test(
    'snap BEFORE quantize, selected target and nonzero residual stay honest',
    () {
      final r = solve(
        Q.of(974, 1000),
        [SnapPoint(SnapKind.playhead, 'head', Q.of(39, 40))],
        scale: Q.of(1000),
        quantize: (q) => FrameRate(30, 1).quantize(q, Rounding.tiesToEven),
      );
      expect(r.snappedDelta, Q.of(39, 40));
      expect(r.delta, Q.of(29, 30));
      expect(r.residual, Q.of(-1, 120));
      expect(r.distancePixels, Q.of(1));
    },
  );
  test('project closure excludes own edges; stationary cuts do not bypass atomic collision', () {
    final p = f.three(),
        ids = f
            .items(p)
            .where((c) => c['source'] != null)
            .map((c) => c['id'] as String)
            .toList(),
        v = TimelineViewport(origin: Q.of(0), pixelsPerSecond: Q.of(100));
    final all = planMoveSnap(
      p,
      clipIds: ids,
      viewport: v,
      pointerPixel: Q.of(96),
      playhead: Q.of(100),
    );
    expect(all.decision.target, isNull);
    expect(all.operation.delta, Q.of(29, 30));
    expect(all.expandedIds, ids.toList()..sort());
    final one = planMoveSnap(
      p,
      clipIds: [ids[1]],
      viewport: v,
      pointerPixel: Q.of(196),
      playhead: Q.of(100),
    );
    expect(one.decision.target!.kind, SnapKind.cut);
    expect(() => m.change(p, one.operation), code('COLLISION'));
    final translated = planMoveSnap(
      p,
      clipIds: ids,
      viewport: TimelineViewport(origin: Q.of(10), pixelsPerSecond: Q.of(100)),
      pointerPixel: Q.of(-904),
      playhead: Q.of(100),
    );
    expect(translated.operation.delta, all.operation.delta);
  });
  test('valid marker project remains refused by existing admission, not stripped for snap', () {
    final d = f.three().toJson(), s = d['sequences'][0];
    s['markerIds'] = ['marker'];
    d['markers'] = [
      {
        'id': 'marker',
        'sequenceId': s['id'],
        'label': 'retained',
        'colorRGBA': [1, 0, 0, 1],
        'anchor': {'kind': 'absolute', 'clipId': null},
        'time': Q.of(1).toJson(),
        'duration': Q.of(0).toJson(),
        'ripple': false,
      },
    ];
    final p = ProjectDocument.fromJson(d),
        id = f.items(p).first['id'] as String;
    expect(
      () => planMoveSnap(
        p,
        clipIds: [id],
        viewport: TimelineViewport(origin: Q.of(0), pixelsPerSecond: Q.of(100)),
        pointerPixel: Q.of(96),
        playhead: Q.of(1),
      ),
      code('FEATURE_NOT_IMPLEMENTED'),
    );
    expect(p.toJson()['markers'], d['markers']);
  });
  test('even excluded target stream is bounded; empty sources and missing selection refuse', () {
    final excluded = cut('excluded', Q.of(0));
    expect(
      () => resolveMoveSnap(
        sources: [cut('moving', Q.of(0))],
        targets: Iterable.generate(400002, (_) => excluded),
        excludedClipIds: {'excluded'},
        requestedDelta: Q.of(0),
        viewport: TimelineViewport(origin: Q.of(0), pixelsPerSecond: Q.of(1)),
        referenceTime: Q.of(0),
        quantize: (q) => q,
      ),
      code('SNAP_POINT_LIMIT'),
    );
    expect(
      () => resolveMoveSnap(
        sources: [],
        targets: [],
        excludedClipIds: {},
        requestedDelta: Q.of(0),
        viewport: TimelineViewport(origin: Q.of(0), pixelsPerSecond: Q.of(1)),
        referenceTime: Q.of(0),
        quantize: (q) => q,
      ),
      code('EMPTY_SELECTION'),
    );
  });
  test(
    '200 seeded cases match independent brute-force nearest/type/ID oracle',
    () {
      final rng = Random(261127);
      Q abs(Q q) => q < Q.of(0) ? Q.of(0) - q : q;
      for (var run = 0; run < 200; run++) {
        final raw = Q.of(900 + rng.nextInt(201), 1000),
            targets = [
              for (var i = 0; i < 30; i++)
                SnapPoint(
                  SnapKind.values[rng.nextInt(3)],
                  'point-$i',
                  Q.of(900 + rng.nextInt(201), 1000),
                  ownerClipId: 'owner-$i',
                ),
            ];
        final eligible =
            targets
                .where((t) => abs(t.time - raw) * Q.of(100) <= Q.of(8))
                .toList()
              ..sort((a, b) {
                var c = abs(a.time - raw).compareTo(abs(b.time - raw));
                if (c != 0) return c;
                c = a.kind.index.compareTo(b.kind.index);
                return c != 0 ? c : a.id.compareTo(b.id);
              });
        final actual = solve(raw, targets);
        expect(actual.target?.id, eligible.isEmpty ? null : eligible.first.id);
        expect(actual.delta, eligible.isEmpty ? raw : eligible.first.time);
      }
    },
  );
}
