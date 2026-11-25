part of 'studio_editor_ui.dart';

extension _MultiMoveControls on _FoundationAppState {
  void _cancelMultiMoveUi() {
    final g = _multiGesture;
    if (g == null) return;
    widget.workspace.cancelGesture(g);
    _multiGesture = null;
    _multiDelta = null;
    _snapPlan = null;
    _multiInputInvalid = false;
    _multiError = null;
    _multiImage?.dispose();
    _multiImage = null;
    _gestureSetState(() {});
  }

  Future<void> _previewMultiMove(int direction, {SnappedMovePlan? snap}) async {
    if (_multiPreviewBusy || _busy || _gesture != null || _pointerActive) {
      return;
    }
    _multiImage?.dispose();
    _multiImage = null;
    _multiInputInvalid = true;
    _snapPlan = snap;
    try {
      final op =
          snap?.operation ??
          MoveClips(
            _multiSelection,
            _delta() * Q.of(direction),
            mode: _collisionMode,
          );
      // A rejected update must not leave the preceding successful ghost visible.
      _multiImage?.dispose();
      _multiImage = null;
      if (_multiGesture == null) {
        _clearTimelineVideo();
        _multiGesture = snap == null
            ? widget.workspace.beginGesture(
                op,
                expectedRevision: _project.revision,
              )
            : widget.workspace.beginSnappedMove(snap);
      } else {
        if (snap == null) {
          widget.workspace.updateGesture(_multiGesture!, op);
        } else {
          widget.workspace.updateSnappedMove(_multiGesture!, snap);
        }
      }
      _multiInputInvalid = false;
      _multiDelta = op.delta;
      _multiError = null;
      _multiImage?.dispose();
      _multiImage = null;
      _multiPreviewBusy = true;
      _multiFocus.requestFocus();
      _gestureSetState(() {});
      final g = _multiGesture!, hash = g.preview.hash;
      final moved = expandedMoveClipIds(g.base, op).toSet(),
          d = g.preview.toJson();
      final candidates = [
        for (final t in d['sequences'][0]['tracks'])
          for (final c in t['items'])
            if (moved.contains(c['id'])) c,
      ];
      final fps = d['sequences'][0]['frameRate'];
      final time = FrameRate(fps['n'], fps['d']).quantize(
        Q.fromJson(candidates.first['timelineRange']['start']),
        Rounding.floor,
      );
      final frame = await widget.workspace.previewGestureAt(g, time);
      final completer = Completer<ui.Image>();
      var abandoned = false;
      ui.decodeImageFromPixels(
        frame.rgba,
        frame.width,
        frame.height,
        ui.PixelFormat.rgba8888,
        (image) {
          if (abandoned) {
            image.dispose();
          } else {
            completer.complete(image);
          }
        },
      );
      final image = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          abandoned = true;
          throw const StudioException('TIMELINE_IMAGE_DECODE_TIMEOUT');
        },
      );
      if (!mounted ||
          !identical(_multiGesture, g) ||
          g.preview.hash != hash ||
          g.error != null) {
        image.dispose();
      } else {
        _gestureSetState(() => _multiImage = image);
      }
    } catch (e) {
      if (mounted && (_multiGesture != null || !_multiPreviewBusy)) {
        _gestureSetState(
          () => _multiError = e is StudioException
              ? e.code
              : 'MULTI_MOVE_PREVIEW_FAILED',
        );
      }
    } finally {
      _gestureSetState(() => _multiPreviewBusy = false);
    }
  }

  void _commitMultiMoveUi() {
    final g = _multiGesture;
    if (g == null || _multiPreviewBusy || _multiInputInvalid) return;
    try {
      widget.workspace.commitGesture(g);
      _multiGesture = null;
      _multiDelta = null;
      _snapPlan = null;
      _multiInputInvalid = false;
      _multiImage?.dispose();
      _multiImage = null;
      _gestureSetState(() {
        _refresh();
        _multiError = null;
        _error = null;
      });
    } catch (e) {
      _gestureSetState(
        () =>
            _multiError = e is StudioException ? e.code : 'LOCAL_COMMIT_FAILED',
      );
    }
  }

  Widget _buildMultiMoveControls() {
    final g = _multiGesture;
    final blocked =
        _busy || _multiPreviewBusy || _gesture != null || _pointerActive;
    List<String> closure = [];
    if (g != null) {
      closure = expandedMoveClipIds(
        g.base,
        MoveClips(_multiSelection, _multiDelta!, mode: _collisionMode),
      );
    }
    return Focus(
      focusNode: _multiFocus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _multiGesture != null) {
          _cancelMultiMoveUi();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Multi-select move · uses the shared positive “Frame count” field below. Same tracks / reject overlap / preserve ALL linked members. Absolute captions stay at their authored times; unsupported clip/source anchors refuse. Uses the shared Collision mode below for reject or overwrite. Insert/ripple and cross-track are not in this slice.',
          ),
          Text(
            'Requested viewport IDs (${_multiSelection.length}): ${_multiSelection.toList()..sort()}',
            key: const Key('multi-selection-status'),
          ),
          for (final c in _clips)
            CheckboxListTile(
              key: Key('multi-select-${c['id']}'),
              value: _multiSelection.contains(c['id']),
              onChanged: blocked || g != null
                  ? null
                  : (v) => _gestureSetState(() {
                      if (v == true) {
                        _multiSelection.add(c['id'] as String);
                      } else {
                        _multiSelection.remove(c['id']);
                      }
                      _multiError = null;
                    }),
              title: Text('Select ${c['name']} · ${c['id']}'),
            ),
          OutlinedButton(
            key: const Key('clear-multi-selection'),
            onPressed: blocked || g != null
                ? null
                : () => _gestureSetState(() {
                    _multiSelection.clear();
                    _multiError = null;
                    _snapPlan = null;
                    _multiInputInvalid = false;
                  }),
            child: const Text('Clear explicit selection'),
          ),
          _buildSnapControls(blocked),
          Wrap(
            children: [
              OutlinedButton(
                key: const Key('preview-multi-left'),
                onPressed: blocked || _multiSelection.isEmpty
                    ? null
                    : () => _previewMultiMove(-1),
                child: const Text('Preview selection − frame count'),
              ),
              OutlinedButton(
                key: const Key('preview-multi-right'),
                onPressed: blocked || _multiSelection.isEmpty
                    ? null
                    : () => _previewMultiMove(1),
                child: const Text('Preview selection + frame count'),
              ),
              FilledButton(
                key: const Key('commit-multi-move'),
                onPressed:
                    blocked ||
                        g == null ||
                        g.error != null ||
                        _multiInputInvalid
                    ? null
                    : _commitMultiMoveUi,
                child: const Text('Commit this exact multi-move once'),
              ),
              OutlinedButton(
                key: const Key('cancel-multi-move'),
                onPressed: g == null ? null : _cancelMultiMoveUi,
                child: const Text('Cancel pending multi-move'),
              ),
            ],
          ),
          if (g != null)
            Text(
              'Uncommitted base ${g.base.revision} · delta $_multiDelta · expanded IDs $closure',
              key: const Key('multi-gesture-active'),
            ),
          if (_multiPreviewBusy)
            const Text(
              'Rendering candidate (one in flight)',
              key: Key('multi-preview-busy'),
            ),
          if (_multiError != null)
            Text('Multi-move: $_multiError', key: const Key('multi-error')),
          if (_multiImage != null)
            RawImage(
              key: const Key('multi-ghost-preview'),
              image: _multiImage,
              width: 256,
              height: 144,
            ),
          if (g != null && _multiError != null)
            const Text(
              'Candidate is not silently retried. Invalid edits cannot commit; unsupported pixel preview does not claim export support. Cancel/replan explicitly.',
            ),
        ],
      ),
    );
  }
}
