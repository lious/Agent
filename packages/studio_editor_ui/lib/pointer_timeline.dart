part of 'studio_editor_ui.dart';

// Flutter pointer/scroll coordinates are logical pixels (not device pixels).
// Quantize only this measurement boundary; all subsequent time math is Q.
Q _pointerQ(double x) => Q.of((x * 1000000).round(), 1000000);
double _pointerDouble(Q q) => q.n.toDouble() / q.d.toDouble();

class _PointerTimeline extends StatefulWidget {
  const _PointerTimeline({
    required this.workspace,
    required this.document,
    required this.selection,
    required this.collisionMode,
    required this.blocked,
    required this.onSelection,
    required this.onActive,
    required this.onCommitted,
  });
  final StudioWorkspace workspace;
  final ProjectDocument document;
  final Set<String> selection;
  final String collisionMode;
  final bool blocked;
  final ValueChanged<Set<String>> onSelection;
  final ValueChanged<bool> onActive;
  final VoidCallback onCommitted;
  @override
  State<_PointerTimeline> createState() => _PointerTimelineState();
}

class _PointerTimelineState extends State<_PointerTimeline>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  ScrollPosition? _ancestorPosition;
  final _focus = FocusNode();
  final _windowFrame = TextEditingController(text: '0');
  final _viewportKey = GlobalKey();
  final _surfaceKey = GlobalKey();
  final _downPointers = <int>{};
  final _waits = <Object, VoidCallback>{};
  StudioWorkspace? _owner;
  int? _pointer;
  int _row = -1, _generation = 0;
  double _zoom = 100;
  Q _origin = Q.of(0), _downX = Q.of(0), _reference = Q.of(0);
  List<String> _ids = [];
  EditGesture? _gesture;
  TimelineViewport? _captureViewport;
  SnappedMovePlan? _plan;
  ui.Image? _image;
  String? _imageHash;
  bool _valid = false,
      _released = false,
      _ended = false,
      _rendering = false,
      _dirty = false,
      _pendingRelease = false;
  Offset? _upPosition;
  String _message =
      'Click / Shift-click clips; drag horizontally. Escape cancels.';
  List get _tracks => widget.document.toJson()['sequences'][0]['tracks'];
  TimelineViewport get _viewport =>
      TimelineViewport(origin: _origin, pixelsPerSecond: Q.of(_zoom.round()));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _ancestorPosition)) {
      _ancestorPosition?.removeListener(_ancestorScrolled);
      _ancestorPosition = position;
      position?.addListener(_ancestorScrolled);
    }
  }

  void _ancestorScrolled() {
    if (_gesture != null) {
      _cancel('Ancestor scroll preempted drag', defer: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PointerTimeline old) {
    super.didUpdateWidget(old);
    if (_gesture != null &&
        (!identical(old.workspace, widget.workspace) ||
            old.document.hash != widget.document.hash ||
            widget.blocked)) {
      _cancel('REVISION_CONFLICT', defer: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel('Focus lost');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ancestorPosition?.removeListener(_ancestorScrolled);
    if (_gesture != null) {
      final notify = widget.onActive;
      WidgetsBinding.instance.addPostFrameCallback((_) => notify(false));
    }
    if (_gesture != null) (_owner ?? widget.workspace).cancelGesture(_gesture!);
    _cancelWaits();
    _gesture = null;
    _generation++;
    _image?.dispose();
    _scroll.dispose();
    _focus.dispose();
    _windowFrame.dispose();
    super.dispose();
  }

  Future<T> _boundedWait<T>(Future<T> source, Duration limit) {
    final result = Completer<T>(), token = Object();
    late Timer timer;
    void finishError(Object error, [StackTrace? stack]) {
      timer.cancel();
      _waits.remove(token);
      if (!result.isCompleted) result.completeError(error, stack);
    }

    timer = Timer(
      limit,
      () => finishError(const StudioException('POINTER_PREVIEW_TIMEOUT')),
    );
    _waits[token] = () => finishError(const StudioException('CANCELED'));
    source.then((value) {
      timer.cancel();
      _waits.remove(token);
      if (result.isCompleted) {
        if (value is ui.Image) value.dispose();
      } else {
        result.complete(value);
      }
    }, onError: finishError);
    return result.future;
  }

  void _cancelWaits() {
    for (final cancel in _waits.values.toList()) {
      cancel();
    }
  }

  void _clearImage() {
    _image?.dispose();
    _image = null;
    _imageHash = null;
  }

  void _cancel(String message, {bool defer = false}) {
    final wasActive = _gesture != null;
    if (_gesture != null) (_owner ?? widget.workspace).cancelGesture(_gesture!);
    _cancelWaits();
    _gesture = null;
    _pointer = null;
    _generation++;
    _dirty = false;
    _pendingRelease = false;
    _valid = false;
    _plan = null;
    _clearImage();
    _message = message;
    if (wasActive) {
      if (defer) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onActive(false);
        });
      } else {
        widget.onActive(false);
      }
    }
    if (mounted && !defer) setState(() {});
  }

  Offset _contentPosition(Offset global) =>
      (_surfaceKey.currentContext!.findRenderObject() as RenderBox)
          .globalToLocal(global);
  bool _inside(Offset global) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;
    final p = box.globalToLocal(global), local = _contentPosition(global);
    return p.dx >= 0 &&
        p.dx < box.size.width &&
        p.dy >= 0 &&
        p.dy < box.size.height &&
        ((local.dy - 24) / 64).floor() == _row;
  }

  void _down(PointerDownEvent event) {
    _downPointers.add(event.pointer);
    if (_downPointers.length != 1) {
      _cancel('Multiple pointers: cancelled');
      return;
    }
    if (widget.blocked || _pendingRelease || event.buttons != 1) return;
    final p = _contentPosition(event.position);
    final row = ((p.dy - 24) / 64).floor();
    if (row < 0 || row >= _tracks.length) return;
    final time = _viewport.timeAt(_pointerQ(p.dx));
    final hit = (_tracks[row]['items'] as List)
        .where(
          (c) =>
              c['source'] != null &&
              time >= Q.fromJson(c['timelineRange']['start']) &&
              time <
                  Q.fromJson(c['timelineRange']['start']) +
                      Q.fromJson(c['timelineRange']['duration']),
        )
        .firstOrNull;
    if (hit == null) return;
    final selection = {...widget.selection};
    if (HardwareKeyboard.instance.isShiftPressed) {
      if (!selection.add(hit['id'] as String)) selection.remove(hit['id']);
    } else {
      Set<String> expanded = selection;
      try {
        if (selection.isNotEmpty) {
          expanded = expandedMoveClipIds(
            widget.document,
            MoveClips(selection, Q.of(0), mode: widget.collisionMode),
          ).toSet();
        }
      } on StudioException {
        /* Admission is enforced at begin, not by painting. */
      }
      if (!expanded.contains(hit['id'])) {
        selection.clear();
        selection.add(hit['id'] as String);
      }
    }
    widget.onSelection(selection);
    if (selection.isEmpty) return;
    _pointer = event.pointer;
    _row = row;
    _downX = _pointerQ(p.dx);
    _ids = selection.toList()..sort();
    _released = false;
    _ended = false;
    _upPosition = null;
  }

  void _start(DragStartDetails details) {
    if (_pointer == null || widget.blocked || _downPointers.length != 1) return;
    try {
      if (widget.workspace.current.hash != widget.document.hash) {
        throw const StudioException('REVISION_CONFLICT');
      }
      _captureViewport = _viewport;
      _reference = planMoveSnap(
        widget.document,
        clipIds: _ids,
        viewport: _captureViewport!,
        pointerPixel: _downX,
        playhead: Q.of(0),
        mode: widget.collisionMode,
      ).referenceTime;
      _gesture = widget.workspace.beginGesture(
        MoveClips(_ids, Q.of(0), mode: widget.collisionMode),
        expectedRevision: widget.document.revision,
      );
      _owner = widget.workspace;
      _valid = true;
      _focus.requestFocus();
      widget.onActive(true);
      _update(details.globalPosition);
    } catch (e) {
      _cancel(e is StudioException ? e.code : 'POINTER_BEGIN_FAILED');
    }
  }

  void _update(Offset global) {
    final g = _gesture;
    if (g == null || _pendingRelease) return;
    if (!_inside(global)) {
      _cancel('Pointer left captured track/viewport');
      return;
    }
    _generation++;
    _clearImage();
    _valid = false;
    _plan = null;
    try {
      final dx = _pointerQ(_contentPosition(global).dx) - _downX;
      if (dx == Q.of(0)) {
        widget.workspace.updateGesture(
          g,
          MoveClips(_ids, Q.of(0), mode: widget.collisionMode),
        );
      } else {
        _plan = planMoveSnap(
          g.base,
          clipIds: _ids,
          viewport: _captureViewport!,
          pointerPixel: _captureViewport!.pixelAt(_reference) + dx,
          playhead: Q.of(0),
          mode: widget.collisionMode,
        );
        widget.workspace.updateSnappedMove(g, _plan!);
      }
      _valid = true;
      _message = _plan?.decision.target == null
          ? 'Move: delta ${_plan?.operation.delta ?? Q.of(0)}'
          : 'Snap ${_plan!.decision.target!.kind.name}: ${_plan!.decision.target!.time}; delta ${_plan!.operation.delta}';
      _dirty = true;
      if (!_rendering) unawaited(_render());
    } catch (e) {
      _dirty = false;
      _message = e is StudioException ? e.code : 'POINTER_CANDIDATE_FAILED';
    }
    if (mounted) setState(() {});
  }

  void _up(PointerUpEvent event) {
    _downPointers.remove(event.pointer);
    if (event.pointer != _pointer) return;
    _released = true;
    _upPosition = event.position;
    _finish();
  }

  void _finish() {
    if (!_released || !_ended || _gesture == null) return;
    if (_upPosition == null || !_inside(_upPosition!)) {
      _cancel('Pointer release outside');
      return;
    }
    _update(_upPosition!); // Final physical coordinate, not an earlier preview.
    if (_gesture == null) return;
    if (!_valid) {
      _cancel(_message);
      return;
    }
    if ((_plan?.operation.delta ?? Q.of(0)) == Q.of(0)) {
      _cancel('No change');
      return;
    }
    _pendingRelease = true;
    _commitIfReady();
  }

  void _commitIfReady() {
    final g = _gesture;
    if (!_pendingRelease ||
        g == null ||
        !_valid ||
        _imageHash != g.preview.hash) {
      return;
    }
    try {
      widget.workspace.commitGesture(g);
      _gesture = null;
      _pointer = null;
      _pendingRelease = false;
      _generation++;
      _dirty = false;
      _clearImage();
      _plan = null;
      _message = 'Pointer move committed (one command)';
      widget.onActive(false);
      widget.onCommitted();
      if (mounted) setState(() {});
    } catch (e) {
      _cancel(e is StudioException ? e.code : 'LOCAL_COMMIT_FAILED');
    }
  }

  Future<void> _render() async {
    _rendering = true;
    try {
      while (mounted && _gesture != null && _dirty && _valid) {
        _dirty = false;
        final g = _gesture!, generation = _generation, hash = g.preview.hash;
        try {
          final d = g.preview.toJson(), starts = <Q>[];
          final moved = expandedMoveClipIds(
            g.base,
            MoveClips(_ids, Q.of(0), mode: widget.collisionMode),
          ).toSet();
          for (final t in d['sequences'][0]['tracks']) {
            for (final c in t['items']) {
              if (moved.contains(c['id'])) {
                starts.add(Q.fromJson(c['timelineRange']['start']));
              }
            }
          }
          starts.sort();
          final fps = d['sequences'][0]['frameRate'];
          final frame = await _boundedWait(
            widget.workspace.previewGestureAt(
              g,
              FrameRate(
                fps['n'],
                fps['d'],
              ).quantize(starts.first, Rounding.floor),
            ),
            const Duration(seconds: 4),
          );
          final decoded = Completer<ui.Image>();
          ui.decodeImageFromPixels(
            frame.rgba,
            frame.width,
            frame.height,
            ui.PixelFormat.rgba8888,
            decoded.complete,
          );
          // Canceled waits release timers and dispose late decoded images.
          final image = await _boundedWait(
            decoded.future,
            const Duration(seconds: 2),
          );
          if (!mounted ||
              !identical(_gesture, g) ||
              generation != _generation ||
              !_valid ||
              g.error != null) {
            image.dispose();
          } else {
            _clearImage();
            _image = image;
            _imageHash = hash;
            setState(() {});
            _commitIfReady();
          }
        } catch (e) {
          if (mounted && identical(_gesture, g) && generation == _generation) {
            _cancel(e is StudioException ? e.code : 'POINTER_PREVIEW_FAILED');
          }
        }
      }
    } finally {
      _rendering = false;
    }
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _focus,
    onFocusChange: (hasFocus) {
      if (!hasFocus && _gesture != null) _cancel('Focus lost');
    },
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _cancel('Escape: cancelled');
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pointer timeline — same-track, linked atomic move'),
        Slider(
          key: const Key('pointer-zoom'),
          min: 25,
          max: 400,
          divisions: 75,
          value: _zoom,
          label: '${_zoom.round()} logical px/s',
          onChanged: (value) {
            _cancel('Zoom changed: cancelled');
            setState(() => _zoom = value);
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('pointer-window-frame'),
                controller: _windowFrame,
                decoration: const InputDecoration(
                  labelText: 'Window start (project frame)',
                ),
              ),
            ),
            TextButton(
              key: const Key('pointer-window-apply'),
              onPressed: () {
                _cancel('Window changed: cancelled');
                final frame = int.tryParse(_windowFrame.text),
                    fps = widget.document.toJson()['sequences'][0]['frameRate'];
                if (frame == null || frame < 0) {
                  setState(() => _message = 'VIEWPORT_FRAME_INVALID');
                  return;
                }
                try {
                  final origin = Q.of(frame) / Q.of(fps['n'], fps['d']);
                  origin +
                      Q.of(
                        20000,
                        25,
                      ); // Validate whole bounded window before accepting pan.
                  setState(() => _origin = origin);
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                } on StudioException catch (e) {
                  setState(() => _message = e.code);
                }
              },
              child: const Text('Pan to frame'),
            ),
          ],
        ),
        const Text(
          'Horizontal scrollbar pans a bounded 20,000px window; zoom or pan to reach distant clips. Playhead = 0s.',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth,
                contentWidth = (width * 3).clamp(width, 20000.0);
            return NotificationListener<ScrollNotification>(
              onNotification: (notice) {
                if (_gesture != null) {
                  _cancel('Scroll preempted drag', defer: true);
                }
                return false;
              },
              child: Listener(
                onPointerSignal: (_) => _cancel('Scroll preempted drag'),
                onPointerPanZoomStart: (_) =>
                    _cancel('Pan/zoom preempted drag'),
                child: SizedBox(
                  key: _viewportKey,
                  width: width,
                  height: 24 + 64.0 * _tracks.length + 16,
                  child: Scrollbar(
                    key: const Key('pointer-scrollbar'),
                    controller: _scroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      child: Listener(
                        onPointerDown: _down,
                        onPointerUp: _up,
                        onPointerCancel: (e) {
                          _downPointers.remove(e.pointer);
                          _cancel('Pointer cancelled');
                        },
                        child: GestureDetector(
                          key: const Key('pointer-surface'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: _start,
                          onHorizontalDragUpdate: (d) =>
                              _update(d.globalPosition),
                          onHorizontalDragEnd: (_) {
                            _ended = true;
                            _finish();
                          },
                          onHorizontalDragCancel: () =>
                              _cancel('Drag arena cancelled'),
                          child: SizedBox(
                            key: _surfaceKey,
                            width: contentWidth,
                            height: 24 + 64.0 * _tracks.length,
                            child: CustomPaint(
                              painter: _PointerPainter(
                                _tracks,
                                _viewport,
                                widget.selection,
                                _valid ? _gesture?.preview : null,
                                _plan,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Text(
          _pendingRelease
              ? 'Released — validating latest native ghost'
              : _message,
          key: const Key('pointer-feedback'),
        ),
        if (_gesture != null)
          const SizedBox(key: Key('pointer-gesture-active')),
        if (_image != null)
          RawImage(
            key: const Key('pointer-native-ghost'),
            image: _image,
            width: 256,
            height: 144,
          ),
      ],
    ),
  );
}

class _PointerPainter extends CustomPainter {
  _PointerPainter(
    this.tracks,
    this.viewport,
    this.selection,
    this.ghost,
    this.plan,
  );
  final List tracks;
  final TimelineViewport viewport;
  final Set<String> selection;
  final ProjectDocument? ghost;
  final SnappedMovePlan? plan;
  void _text(Canvas canvas, String text, Offset at, double width) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xffffffff), fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width);
    p.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff172231),
    );
    for (double x = 0; x < size.width; x += 100) {
      _text(canvas, '${viewport.timeAt(_pointerQ(x))}s', Offset(x + 2, 2), 98);
      canvas.drawLine(
        Offset(x, 22),
        Offset(x, size.height),
        Paint()..color = const Color(0xff344454),
      );
    }
    void drawTracks(List rows, bool isGhost) {
      for (var row = 0; row < rows.length; row++) {
        if (!isGhost) {
          _text(
            canvas,
            '${rows[row]['id']}',
            Offset(2, 25 + row * 64),
            size.width,
          );
        }
        for (final c in rows[row]['items']) {
          if (c['source'] == null ||
              (isGhost &&
                  !(plan?.expandedIds.contains(c['id']) ??
                      selection.contains(c['id'])))) {
            continue;
          }
          final start = Q.fromJson(c['timelineRange']['start']),
              end = start + Q.fromJson(c['timelineRange']['duration']);
          final viewEnd = viewport.timeAt(_pointerQ(size.width));
          if (end <= viewport.origin || start >= viewEnd) continue;
          final left = viewport.pixelAt(
                start < viewport.origin ? viewport.origin : start,
              ),
              right = viewport.pixelAt(end > viewEnd ? viewEnd : end);
          if (right <= Q.of(0) || left >= _pointerQ(size.width)) continue;
          final l = left < Q.of(0) ? 0.0 : _pointerDouble(left);
          final r = right > _pointerQ(size.width)
              ? size.width
              : _pointerDouble(right);
          final rect = Rect.fromLTRB(l, 40 + row * 64.0, r, 83 + row * 64.0);
          canvas.drawRect(
            rect,
            Paint()
              ..color = isGhost
                  ? const Color(0xff00ffff)
                  : selection.contains(c['id'])
                  ? const Color(0xff497cc1)
                  : const Color(0xff37536f)
              ..style = isGhost ? PaintingStyle.stroke : PaintingStyle.fill
              ..strokeWidth = 2,
          );
          if (!isGhost && r - l > 12) {
            _text(canvas, '${c['id']}', Offset(l + 3, rect.top + 8), r - l - 6);
          }
        }
      }
    }

    drawTracks(tracks, false);
    if (ghost != null) {
      drawTracks(ghost!.toJson()['sequences'][0]['tracks'], true);
    }
    if (plan?.decision.target != null) {
      final targetTime = plan!.decision.target!.time;
      if (targetTime < viewport.origin ||
          targetTime > viewport.timeAt(_pointerQ(size.width))) {
        return;
      }
      final q = viewport.pixelAt(targetTime);
      if (q >= Q.of(0) && q <= _pointerQ(size.width)) {
        final x = _pointerDouble(q);
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = const Color(0xffffc107)
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => true;
}
