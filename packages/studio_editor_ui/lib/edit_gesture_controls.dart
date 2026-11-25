part of 'studio_editor_ui.dart';

extension _GestureControls on _FoundationAppState {
  Map? get _opacityEffect => (_project.toJson()['effects'] as List)
      .where((e) => e['type'] == 'opacity' && e['owner']['id'] == _selected)
      .cast<Map>()
      .firstOrNull;

  void _cancelGestureUi() {
    final gesture = _gesture;
    if (gesture == null) return;
    widget.workspace.cancelGesture(gesture);
    _gesture = null;
    _gesturePointer = null;
    _gesturePointerReleased = false;
    _gestureDirty = false;
    _gestureImage?.dispose();
    _gestureImage = null;
    if (mounted) _gestureSetState(() {});
  }

  void _startOpacityGesture(double value) {
    try {
      _gestureStartValue =
          (_opacityEffect?['parameters']['value'] as num?)?.toDouble() ?? 1;
      _clearTimelineVideo();
      _gesture = widget.workspace.beginGesture(
        SetClipOpacity(_selected!, value),
        expectedRevision: _project.revision,
      );
      _gestureFocus.requestFocus();
      _gestureSetState(() {
        _gestureValue = value;
        _error = null;
      });
      _requestGestureImage();
    } on StudioException catch (e) {
      _gestureSetState(() => _error = e.code);
    }
  }

  void _changeOpacityGesture(double value) {
    final gesture = _gesture;
    if (gesture == null) return; // Escape/pointer cancel must not resume it.
    try {
      widget.workspace.updateGesture(
        gesture,
        SetClipOpacity(_selected!, value),
      );
      _gestureSetState(() {
        _gestureValue = value;
        _error = null;
      });
      _requestGestureImage();
    } on StudioException catch (e) {
      _gestureSetState(() => _error = e.code);
    }
  }

  void _endOpacityGesture(double value) {
    final gesture = _gesture;
    if (gesture == null) return;
    if (!_gesturePointerReleased) {
      // Slider onChangeEnd also fires when its drag recognizer loses the
      // arena. Only an observed matching physical UP may commit this control.
      _cancelGestureUi();
      return;
    }
    if (gesture.error == null && _gestureValue == _gestureStartValue) {
      _cancelGestureUi();
      return;
    }
    // Keep a failed/conflicted ghost for explicit cancel/replan, never retry CAS.
    try {
      widget.workspace.commitGesture(gesture);
      _gesture = null;
      _gesturePointer = null;
      _gesturePointerReleased = false;
      _gestureDirty = false;
      _gestureImage?.dispose();
      _gestureImage = null;
      _gestureSetState(() {
        _refresh();
        _error = null;
      });
    } catch (e) {
      _gestureSetState(
        () => _error = e is StudioException ? e.code : 'LOCAL_COMMIT_FAILED',
      );
    }
  }

  void _requestGestureImage() {
    _gestureDirty = true;
    if (!_gestureRendering) unawaited(_renderGestureImages());
  }

  Future<void> _renderGestureImages() async {
    _gestureRendering = true;
    try {
      // One native request plus one latest-value flag, never one decoder per
      // pointer event. Superseded results cannot become a displayed ghost.
      while (mounted && _gesture != null && _gestureDirty) {
        _gestureDirty = false;
        final gesture = _gesture!, hash = gesture.preview.hash;
        try {
          final clips =
              gesture.preview.toJson()['sequences'][0]['tracks'] as List;
          final clip = [for (final t in clips) ...t['items']]
              .singleWhere((c) => c['id'] == _selected);
          final frame = await widget.workspace.previewGestureAt(
            gesture,
            Q.fromJson(clip['timelineRange']['start']),
          );
          final decoded = Completer<ui.Image>();
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
                decoded.complete(image);
              }
            },
          );
          final image = await decoded.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              abandoned = true;
              throw const StudioException('TIMELINE_IMAGE_DECODE_TIMEOUT');
            },
          );
          if (!mounted ||
              !identical(_gesture, gesture) ||
              gesture.preview.hash != hash ||
              gesture.error != null) {
            image.dispose();
          } else {
            _gestureSetState(() {
              _gestureImage?.dispose();
              _gestureImage = image;
            });
          }
        } catch (e) {
          final code = e is StudioException ? e.code : 'GESTURE_PREVIEW_FAILED';
          if (mounted &&
              identical(_gesture, gesture) &&
              !['PREVIEW_SUPERSEDED', 'GESTURE_NOT_ACTIVE'].contains(code)) {
            _gestureSetState(() => _error = code);
          }
        }
      }
    } finally {
      _gestureRendering = false;
    }
  }

  Widget _buildGestureControls() {
    final video = _clips.any(
      (c) =>
          c['id'] == _selected &&
          (_project.toJson()['sequences'][0]['tracks'] as List).any(
            (t) => t['id'] == c['trackId'] && t['kind'] == 'video',
          ),
    );
    final effect = _opacityEffect;
    final enabled =
        !_busy &&
        video &&
        (effect == null || (effect['keyframes'] as List).isEmpty);
    final value = _gesture == null
        ? (effect?['parameters']['value'] as num?)?.toDouble() ?? 1
        : _gestureValue;
    return Focus(
      focusNode: _gestureFocus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            _gesture != null) {
          _cancelGestureUi();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          const Text(
            'Drag static opacity: ghost only until pointer release; Escape / pointer cancel writes nothing. Keyframed clips use the keyframe editor.',
          ),
          Listener(
            onPointerDown: (event) {
              if (_gesturePointer == null || _gesture == null) {
                _gesturePointer = event.pointer;
                _gesturePointerReleased = false;
              }
            },
            onPointerUp: (event) {
              if (_gesturePointer == event.pointer) {
                _gesturePointerReleased = true;
              }
            },
            onPointerCancel: (event) {
              if (_gesturePointer == event.pointer) _cancelGestureUi();
            },
            child: Slider(
              key: const Key('opacity-gesture-slider'),
              min: 0,
              max: 1,
              value: value,
              onChangeStart: enabled ? _startOpacityGesture : null,
              onChanged: enabled ? _changeOpacityGesture : null,
              onChangeEnd: enabled ? _endOpacityGesture : null,
            ),
          ),
          if (_gesture != null && _error != null)
            Text('Gesture: $_error', key: const Key('gesture-error')),
          if (_gesture != null)
            Text(
              'Uncommitted ghost · ${_gesture!.id} · base ${_gesture!.base.revision}',
              key: const Key('gesture-active'),
            ),
          OutlinedButton(
            key: const Key('cancel-edit-gesture'),
            onPressed: _gesture == null ? null : _cancelGestureUi,
            child: const Text('Cancel uncommitted gesture'),
          ),
          if (_gestureImage != null)
            RawImage(
              key: const Key('gesture-preview'),
              image: _gestureImage,
              width: 256,
              height: 144,
            ),
        ],
      ),
    );
  }
}
