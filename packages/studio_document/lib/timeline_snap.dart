import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

/// Logical pixels, never physical device pixels or floating-point project time.
final class TimelineViewport {
  TimelineViewport({
    required this.origin,
    required this.pixelsPerSecond,
    this.logicalOrigin,
  }) {
    if (pixelsPerSecond <= Q.of(0)) {
      throw const StudioException('SNAP_SCALE_INVALID');
    }
  }
  final Q origin, pixelsPerSecond;
  final Q? logicalOrigin;
  Q timeAt(Q logicalPixel) =>
      origin + (logicalPixel - (logicalOrigin ?? Q.of(0))) / pixelsPerSecond;
  Q pixelAt(Q time) =>
      (logicalOrigin ?? Q.of(0)) + (time - origin) * pixelsPerSecond;
}

enum SnapKind { playhead, cut, marker }

final class SnapPoint {
  SnapPoint(
    this.kind,
    this.id,
    this.time, {
    this.ownerClipId,
    this.end = false,
  }) {
    requireId(id);
    if (ownerClipId != null) requireId(ownerClipId!);
    if (time < Q.of(0)) throw const StudioException('SNAP_POINT_INVALID');
    if (kind == SnapKind.cut && ownerClipId == null) {
      throw const StudioException('SNAP_OWNER_REQUIRED');
    }
  }
  final SnapKind kind;
  final String id;
  final Q time;
  final String? ownerClipId;
  final bool end;
}

final class MoveSnap {
  MoveSnap._(
    this.requestedDelta,
    this.snappedDelta,
    this.delta,
    this.source,
    this.target,
    this.distancePixels,
    this.residual,
  );
  final Q requestedDelta, snappedDelta, delta;
  final SnapPoint? source, target;
  final Q? distancePixels, residual;
}

Q _abs(Q value) => value < Q.of(0) ? Q.of(0) - value : value;
int _pointOrder(SnapPoint a, SnapPoint b) {
  var c = a.kind.index.compareTo(b.kind.index);
  if (c != 0) return c;
  c = a.id.compareTo(b.id);
  if (c != 0) return c;
  c = (a.end ? 1 : 0).compareTo(b.end ? 1 : 0);
  if (c != 0) return c;
  return a.time.compareTo(b.time);
}

/// Advisory pure resolver: closest first, then playhead/cut/marker, then ID.
/// Equal target/source IDs use start-before-end and source ID as stable final ties.
/// Quantize ONCE after snapping on the reference frame/sample lattice. A selected
/// target need not remain exact after quantization: residual is explicitly returned.
MoveSnap resolveMoveSnap({
  required Iterable<SnapPoint> sources,
  required Iterable<SnapPoint> targets,
  required Set<String> excludedClipIds,
  required Q requestedDelta,
  required TimelineViewport viewport,
  required Q referenceTime,
  required Q Function(Q) quantize,
}) {
  final ordered = <SnapPoint>[];
  var targetCount = 0;
  for (final p in targets) {
    if (++targetCount > 400001) {
      throw const StudioException('SNAP_POINT_LIMIT');
    }
    if (p.ownerClipId == null || !excludedClipIds.contains(p.ownerClipId)) {
      ordered.add(p);
    }
  }
  ordered.sort((a, b) {
    final c = a.time.compareTo(b.time);
    return c != 0 ? c : _pointOrder(a, b);
  });
  final unique = <SnapPoint>[];
  for (final p in ordered) {
    if (unique.isEmpty || unique.last.time != p.time) unique.add(p);
  }
  SnapPoint? bestSource, bestTarget;
  Q? bestDistance;
  var count = 0;
  for (final s in sources) {
    if (++count > 400000) throw const StudioException('SNAP_POINT_LIMIT');
    final wanted = s.time + requestedDelta;
    var lo = 0, hi = unique.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (unique[mid].time < wanted) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    for (final index in [lo - 1, lo]) {
      if (index < 0 || index >= unique.length) continue;
      final t = unique[index],
          distance = _abs(t.time - wanted) * viewport.pixelsPerSecond;
      if (distance > Q.of(8)) continue;
      final better =
          bestDistance == null ||
          distance < bestDistance ||
          (distance == bestDistance &&
              (_pointOrder(t, bestTarget!) < 0 ||
                  (_pointOrder(t, bestTarget) == 0 &&
                      _pointOrder(s, bestSource!) < 0)));
      if (better) {
        bestSource = s;
        bestTarget = t;
        bestDistance = distance;
      }
    }
  }
  if (count == 0) throw const StudioException('EMPTY_SELECTION');
  final snapped = bestTarget == null
      ? requestedDelta
      : bestTarget.time - bestSource!.time;
  final delta = quantize(referenceTime + snapped) - referenceTime;
  return MoveSnap._(
    requestedDelta,
    snapped,
    delta,
    bestSource,
    bestTarget,
    bestDistance,
    bestTarget == null ? null : bestSource!.time + delta - bestTarget.time,
  );
}

final class SnappedMovePlan {
  SnappedMovePlan._(
    this.baseHash,
    this.operation,
    this.decision,
    this.viewport,
    this.referenceTime,
    this.trackIds,
    this.expandedIds,
  );
  final String baseHash;
  final MoveClips operation;
  final MoveSnap decision;
  final TimelineViewport viewport;
  final Q referenceTime;
  final List<String> trackIds, expandedIds;
}

/// Current admitted media-clip closure only. Marker-bearing projects deliberately
/// retain existing read-only/refusal admission until marker editing is implemented.
SnappedMovePlan planMoveSnap(
  ProjectDocument base, {
  required Iterable<String> clipIds,
  required TimelineViewport viewport,
  required Q pointerPixel,
  required Q playhead,
  String mode = 'reject',
  bool includeLinks = true,
}) {
  final initial = MoveClips(
        clipIds,
        Q.of(0),
        mode: mode,
        includeLinks: includeLinks,
      ),
      expanded = expandedMoveClipIds(base, initial),
      moving = expanded.toSet(),
      d = base.toJson(),
      seq = d['sequences'][0];
  final sources = <SnapPoint>[],
      targets = <SnapPoint>[
        SnapPoint(SnapKind.playhead, 'editing-playhead', playhead),
      ],
      trackIds = <String>{};
  final videoStarts = <Q>[], audioStarts = <Q>[];
  for (final t in seq['tracks']) {
    for (final c in t['items']) {
      if (c['source'] == null) {
        continue; // derived Gap boundaries are not stationary media cuts
      }
      final id = c['id'] as String,
          start = Q.fromJson(c['timelineRange']['start']),
          end = start + Q.fromJson(c['timelineRange']['duration']);
      final points = [
        SnapPoint(SnapKind.cut, id, start, ownerClipId: id),
        SnapPoint(SnapKind.cut, id, end, ownerClipId: id, end: true),
      ];
      if (moving.contains(id)) {
        sources.addAll(points);
        trackIds.add(t['id'] as String);
        (t['kind'] == 'video' ? videoStarts : audioStarts).add(start);
      } else {
        targets.addAll(points);
      }
    }
  }
  final starts = videoStarts.isNotEmpty ? videoStarts : audioStarts;
  starts.sort();
  final reference = starts.first;
  final fps = FrameRate(seq['frameRate']['n'], seq['frameRate']['d']);
  Q quantize(Q time) => videoStarts.isNotEmpty
      ? fps.quantize(time, Rounding.tiesToEven)
      : Q(sampleIndex(time, 48000, Rounding.tiesToEven), BigInt.from(48000));
  final decision = resolveMoveSnap(
    sources: sources,
    targets: targets,
    excludedClipIds: moving,
    requestedDelta: viewport.timeAt(pointerPixel) - reference,
    viewport: viewport,
    referenceTime: reference,
    quantize: quantize,
  );
  return SnappedMovePlan._(
    base.hash,
    MoveClips(
      initial.clipIds,
      decision.delta,
      mode: mode,
      includeLinks: includeLinks,
    ),
    decision,
    viewport,
    reference,
    List.unmodifiable(trackIds.toList()..sort()),
    expanded,
  );
}
