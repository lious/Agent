import 'package:studio_contracts/studio_contracts.dart';

import 'time.dart';

const retimeInterpUnsupported = 'RETIME_INTERP_UNSUPPORTED';
const retimeDirectionUnsupported = 'RETIME_DIRECTION_UNSUPPORTED';
const retimeNonMonotone = 'RETIME_NON_MONOTONE';
const retimeEndpointMismatch = 'RETIME_ENDPOINT_MISMATCH';

/// A strictly increasing TimeMap knot. [u] is clip-local time; [v] is the
/// source offset relative to `sourceRange.start`.
final class RetimeKnot {
  RetimeKnot(this.u, this.v);
  final Q u, v;

  Map<String, Object> toJson() => {'u': u.toJson(), 'v': v.toJson()};
}

/// P1 speed map: linear rate or piecewise-linear TimeMap. This is not a
/// playback qualifier (V-003) and does not default to optical-flow
/// interpolation. Freeze, reverse, and smooth curves stay phase-2 and
/// cannot be masqueraded as a positive rate.
final class RetimeMap {
  RetimeMap._({
    required this.kind,
    required this.rate,
    required List<RetimeKnot> knots,
    required this.interpolation,
  }) : knots = List.unmodifiable(knots);

  factory RetimeMap.linear({required Q rate, required Q duration}) {
    if (rate <= Q.of(0) || duration <= Q.of(0)) {
      throw const StudioException('INVALID_RANGE', 'retime');
    }
    final sourceDuration = rate * duration;
    return RetimeMap._(
      kind: 'linear',
      rate: rate,
      knots: [RetimeKnot(Q.of(0), Q.of(0)), RetimeKnot(duration, sourceDuration)],
      interpolation: 'linear',
    );
  }

  factory RetimeMap.piecewise({
    required List<RetimeKnot> knots,
    String interpolation = 'linear',
    int direction = 1,
    String? interpMode,
  }) {
    if (direction != 1) {
      throw const StudioException(retimeDirectionUnsupported, 'direction');
    }
    if (interpMode != null && interpMode != 'linear') {
      throw StudioException(retimeInterpUnsupported, interpMode);
    }
    if (interpolation != 'linear') {
      throw StudioException(retimeInterpUnsupported, interpolation);
    }
    if (knots.length < 2) {
      throw const StudioException(retimeEndpointMismatch, 'knots');
    }
    if (knots.first.u != Q.of(0) || knots.first.v != Q.of(0)) {
      throw const StudioException(retimeEndpointMismatch, 'start');
    }
    for (var i = 1; i < knots.length; i++) {
      if (knots[i].u <= knots[i - 1].u || knots[i].v <= knots[i - 1].v) {
        throw const StudioException(retimeNonMonotone);
      }
    }
    final duration = knots.last.u;
    final sourceDuration = knots.last.v;
    if (duration <= Q.of(0) || sourceDuration <= Q.of(0)) {
      throw const StudioException('INVALID_RANGE', 'retime');
    }
    return RetimeMap._(
      kind: 'piecewise',
      rate: sourceDuration / duration,
      knots: knots,
      interpolation: 'linear',
    );
  }

  final String kind, interpolation;
  final Q rate;
  final List<RetimeKnot> knots;

  Q get duration => knots.last.u;
  Q get sourceDuration => knots.last.v;

  /// Source offset [v] for clip-local time [u]. Uses exact Q arithmetic,
  /// never a frame index.
  Q sourceAt(Q u) {
    if (u < Q.of(0) || u > duration) {
      throw const StudioException('INVALID_RANGE', 'sourceAt');
    }
    if (kind == 'linear') return rate * u;
    for (var i = 1; i < knots.length; i++) {
      final a = knots[i - 1], b = knots[i];
      if (u <= b.u) {
        if (u == a.u) return a.v;
        if (u == b.u) return b.v;
        return a.v + (u - a.u) * (b.v - a.v) / (b.u - a.u);
      }
    }
    return knots.last.v;
  }

  /// Inverse map [v] → clip-local [u] by segment bisection on v.
  /// Caption source anchors must use this, not [FrameRate.frameIndex].
  Q invert(Q v) {
    if (v < Q.of(0) || v > sourceDuration) {
      throw const StudioException('INVALID_RANGE', 'invert');
    }
    if (kind == 'linear') return v / rate;
    for (var i = 1; i < knots.length; i++) {
      final a = knots[i - 1], b = knots[i];
      if (v <= b.v) {
        if (v == a.v) return a.u;
        if (v == b.v) return b.u;
        return a.u + (v - a.v) * (b.u - a.u) / (b.v - a.v);
      }
    }
    return knots.last.u;
  }

  /// Split at clip-local [at], inserting the same mapping point on both
  /// sides. The right map restarts at (0,0) with source offsets relative
  /// to the new sourceRange.start.
  (RetimeMap, RetimeMap) split(Q at) {
    if (at <= Q.of(0) || at >= duration) {
      throw const StudioException('INVALID_RANGE', 'split');
    }
    final mid = sourceAt(at);
    final leftKnots = <RetimeKnot>[];
    for (final k in knots) {
      if (k.u < at) leftKnots.add(k);
      if (k.u == at) break;
    }
    leftKnots.add(RetimeKnot(at, mid));
    final rightKnots = <RetimeKnot>[RetimeKnot(Q.of(0), Q.of(0))];
    for (final k in knots) {
      if (k.u > at) {
        rightKnots.add(RetimeKnot(k.u - at, k.v - mid));
      }
    }
    if (rightKnots.last.u != duration - at) {
      rightKnots.add(RetimeKnot(duration - at, sourceDuration - mid));
    }
    return (
      RetimeMap.piecewise(knots: leftKnots),
      RetimeMap.piecewise(knots: rightKnots),
    );
  }

  Map<String, Object?> toJson() => kind == 'linear'
      ? {'kind': 'linear', 'rate': rate.toJson()}
      : {
          'kind': 'piecewise',
          'interpolation': interpolation,
          'knots': [for (final k in knots) k.toJson()],
        };
}
