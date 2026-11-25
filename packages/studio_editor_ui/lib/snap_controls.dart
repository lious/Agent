part of 'studio_editor_ui.dart';

Q _snapDecimal(String raw) {
  if (!RegExp(r'^-?(0|[1-9][0-9]{0,8})(\.[0-9]{1,6})?$').hasMatch(raw)) {
    throw const StudioException('SNAP_NUMBER_INVALID');
  }
  final parts = raw.split('.'),
      den = BigInt.from(10).pow(parts.length == 1 ? 0 : parts[1].length);
  final whole = BigInt.parse(parts[0]),
      fraction = parts.length == 1 ? BigInt.zero : BigInt.parse(parts[1]);
  return Q(whole * den + (raw.startsWith('-') ? -fraction : fraction), den);
}

extension _SnapControls on _FoundationAppState {
  Future<void> _previewSnapMove() async {
    if (_busy || _multiPreviewBusy || _gesture != null) return;
    try {
      final d = (_multiGesture?.base ?? _project).toJson(),
          rate = d['sequences'][0]['frameRate'],
          fps = FrameRate(rate['n'], rate['d']);
      final origin = int.tryParse(_snapOrigin.text),
          playhead = int.tryParse(_snapPlayhead.text);
      if (origin == null || playhead == null || playhead < 0) {
        throw const StudioException('SNAP_FRAME_INVALID');
      }
      final plan = planMoveSnap(
        _multiGesture?.base ?? _project,
        clipIds: _multiSelection,
        viewport: TimelineViewport(
          origin: fps.frameTime(BigInt.from(origin)),
          pixelsPerSecond: _snapDecimal(_snapZoom.text),
        ),
        pointerPixel: _snapDecimal(_snapPointer.text),
        playhead: fps.frameTime(BigInt.from(playhead)),
      );
      await _previewMultiMove(0, snap: plan);
    } catch (e) {
      _multiImage?.dispose();
      _multiImage = null;
      _snapPlan = null;
      _multiInputInvalid = true;
      _gestureSetState(
        () => _multiError = e is StudioException ? e.code : 'SNAP_PLAN_FAILED',
      );
    }
  }

  Widget _buildSnapControls(bool blocked) => ExpansionTile(
    key: const Key('snap-settings'),
    initiallyExpanded: _snapExpanded,
    onExpansionChanged: (value) => _snapExpanded = value,
    title: const Text('Exact viewport snapping · 8 logical px'),
    children: [
      const Text(
        'Viewport-only editing cursor, NOT an audio service clock. Media cuts + playhead; marker-bearing projects still refuse editing. Snap first, then frame (or audio-only sample) quantization; residual is shown. No hidden collision fallback.',
      ),
      _path(
        'snap-zoom',
        'Logical pixels per second (exact decimal)',
        _snapZoom,
      ),
      _path(
        'snap-origin',
        'Viewport origin · project frame index',
        _snapOrigin,
      ),
      _path(
        'snap-pointer',
        'Pointer x · logical pixels, relative to viewport',
        _snapPointer,
      ),
      _path(
        'snap-playhead',
        'Editing playhead · project frame index',
        _snapPlayhead,
      ),
      OutlinedButton(
        key: const Key('preview-snap-move'),
        onPressed: blocked || _multiSelection.isEmpty ? null : _previewSnapMove,
        child: const Text('Preview exact snapped selection'),
      ),
      if (_snapPlan case final p?) ...[
        Text(
          'Target ${p.decision.target?.kind.name ?? "none"} · ${p.decision.target?.id ?? "none"} @ ${p.decision.target?.time}; raw Δ ${p.decision.requestedDelta}; snap Δ ${p.decision.snappedDelta}; final Δ ${p.decision.delta}; distance ${p.decision.distancePixels} logical px; residual ${p.decision.residual}; participating tracks ${p.trackIds}',
          key: const Key('snap-decision'),
        ),
        SizedBox(
          height: 64,
          width: 600,
          child: CustomPaint(
            key: const Key('snap-ruler'),
            painter: _SnapRuler(p),
          ),
        ),
      ],
    ],
  );
}

final class _SnapRuler extends CustomPainter {
  _SnapRuler(this.plan);
  final SnappedMovePlan plan;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..color = const Color(0xff777777);
    canvas.drawLine(Offset(0, 32), Offset(size.width, 32), paint);
    void line(Q time, Color color, double y) {
      // Clip in exact time BEFORE multiplying by zoom: far-away targets in an
      // invalid candidate must not overflow decorative UI painting.
      Q pixel;
      try {
        if (time < plan.viewport.timeAt(Q.of(0)) ||
            time > plan.viewport.timeAt(Q.of(size.width.floor()))) {
          return;
        }
        pixel = plan.viewport.pixelAt(time);
      } on StudioException {
        return; // drawing only; exact candidate and business admission unchanged
      }
      // Conversion is drawing-only AFTER exact clipping. Never feeds domain time.
      final x = pixel.n.toDouble() / pixel.d.toDouble();
      paint.color = color;
      canvas.drawLine(Offset(x, y), Offset(x, 62), paint);
    }

    line(
      plan.referenceTime + plan.decision.requestedDelta,
      const Color(0xffcc5555),
      4,
    );
    if (plan.decision.target case final target?) {
      line(target.time, const Color(0xffccaa00), 12);
    }
    line(plan.referenceTime + plan.decision.delta, const Color(0xff4477cc), 20);
  }

  @override
  bool shouldRepaint(_SnapRuler old) => !identical(old.plan, plan);
}
