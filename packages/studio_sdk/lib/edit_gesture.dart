part of 'studio_sdk.dart';

/// One explicit interaction, bound to an immutable base, writer and target.
/// Ghosts are never repository snapshots and cannot be exported/saved as edits.
final class EditGesture {
  EditGesture._(this.id, this.base, this._writer, this._target);
  final String id;
  final ProjectDocument base;
  final WriterToken _writer;
  final String _target;
  EditOperation? _operation;
  ProjectDocument? _preview;
  String? _error;
  int _generation = 0;
  bool _finished = false;
  bool get finished => _finished;
  String? get error => _error;
  ProjectDocument get preview => _preview ?? base;
}

// Closed, deliberately limited interaction matrix. Never time-window merge
// commands, different clips, trim modes/edges, or distinct keyframe coordinates.
String _gestureTarget(EditOperation op) => contentHash(switch (op) {
  MoveClip() => ['move', op.clipId],
  MoveClips() => ['moveSelection', op.clipIds],
  TrimClip() => ['trim', op.clipId, op.edge, op.ripple],
  SlipClip() => ['slip', op.clipId],
  SetClipOpacity() => ['opacity', op.clipId],
  SetOpacityKeyframe() => [
    'opacityKeyframe',
    op.clipId,
    op.time.toJson(),
    op.interpolation,
  ],
  SetClipTransform() => ['transform', op.clipId],
  SetTransformKeyframe() => [
    'transformKeyframe',
    op.clipId,
    op.param,
    op.time.toJson(),
    op.interpolation,
  ],
  SetClipCrop() => ['crop', op.clipId],
  SetClipColorBasic() => ['colorBasic', op.clipId],
  _ => throw const StudioException('GESTURE_OPERATION_UNSUPPORTED'),
});

extension WorkspaceGestures on StudioWorkspace {
  EditGesture beginSnappedMove(SnappedMovePlan plan) {
    _requireMetadata();
    if (current.hash != plan.baseHash) {
      throw const StudioException('REVISION_CONFLICT');
    }
    return beginGesture(plan.operation, expectedRevision: current.revision);
  }

  ProjectDocument updateSnappedMove(EditGesture gesture, SnappedMovePlan plan) {
    _checkGesture(gesture);
    if (gesture.base.hash != plan.baseHash) {
      // Invalid foreign/stale plan must not leave an older valid ghost releasable.
      gesture._generation++;
      gesture._error = 'REVISION_CONFLICT';
      cancelSourcePreview();
      throw const StudioException('REVISION_CONFLICT');
    }
    return updateGesture(gesture, plan.operation);
  }

  EditGesture beginGesture(
    EditOperation initial, {
    required BigInt expectedRevision,
  }) {
    _requireMetadata();
    if (_closed || _writer == null) {
      throw const StudioException('PROJECT_NOT_OPEN');
    }
    if (_editGesture != null) {
      throw const StudioException('GESTURE_IN_PROGRESS');
    }
    final base = current;
    if (base.revision != expectedRevision) {
      throw const StudioException('REVISION_CONFLICT');
    }
    _repository.commandHistory(
      base.projectId,
    ); // Unknown history refuses, not truncated.
    final gesture = EditGesture._(
      _uuid.v7(),
      base,
      _writer!,
      _gestureTarget(initial),
    );
    stopTimelinePlayback();
    cancelSourcePreview();
    _editGesture = gesture;
    try {
      updateGesture(gesture, initial);
      return gesture;
    } catch (_) {
      cancelGesture(gesture);
      rethrow;
    }
  }

  void _checkGesture(EditGesture gesture) {
    if (_closed || gesture._finished || !identical(_editGesture, gesture)) {
      throw const StudioException('GESTURE_NOT_ACTIVE');
    }
    if (!identical(_writer, gesture._writer) ||
        projectId != gesture.base.projectId ||
        _repository.writerEpoch(projectId) != gesture._writer.epoch) {
      throw const StudioException('WRITER_FENCED');
    }
    if (current.hash != gesture.base.hash) {
      throw const StudioException('REVISION_CONFLICT');
    }
  }

  ProjectDocument updateGesture(EditGesture gesture, EditOperation operation) {
    _checkGesture(gesture);
    // Even a rejected update invalidates in-flight images and forbids releasing
    // an older valid value by accident. A new valid update is required.
    gesture._generation++;
    cancelSourcePreview();
    try {
      if (_gestureTarget(operation) != gesture._target) {
        throw const StudioException('GESTURE_TARGET_MISMATCH');
      }
      if (operation is SetClipOpacity ||
          operation is SetOpacityKeyframe ||
          operation is SetClipTransform ||
          operation is SetTransformKeyframe ||
          operation is SetClipCrop ||
          operation is SetClipColorBasic) {
        _requireMedia();
        final capability = switch (operation) {
          SetClipOpacity() => 'linearOpacityV1',
          SetOpacityKeyframe() => 'linearOpacityKeyframesV1',
          SetClipTransform() => 'staticTransform2dV1',
          SetTransformKeyframe() => 'linearTransform2dKeyframesV1',
          _ => 'staticRasterV1',
        };
        if (_media!.capabilities[capability] != true) {
          throw const StudioException('GESTURE_ADAPTER_UNAVAILABLE');
        }
      }
      // Ephemeral versions/IDs only. The authoritative normal edit transaction
      // will allocate historical max+1; ghost versions never enter the ledger.
      final versions = <String, BigInt>{};
      void collect(dynamic v) {
        if (v is Map) {
          if (v['id'] is String && v['version'] is String) {
            final n = BigInt.tryParse(v['version'] as String);
            if (n != null && n > (versions[v['id']] ?? BigInt.zero)) {
              versions[v['id'] as String] = n;
            }
          }
          for (final child in v.values) {
            collect(child);
          }
        } else if (v is List) {
          for (final child in v) {
            collect(child);
          }
        }
      }

      collect(gesture.base.toJson());
      final allocated = <String, String>{};
      var serial = 0;
      final preview = applyEdit(
        gesture.base,
        operation,
        nextVersion: (id) => allocated.putIfAbsent(id, () {
          final n = (versions[id] ?? BigInt.zero) + BigInt.one;
          if (n > maxI64) throw const StudioException('VERSION_OVERFLOW');
          return n.toString();
        }),
        newId: () => 'ghost-${gesture.id}-${serial++}',
      );
      _requireTransformAdapter(preview);
      gesture._operation = operation;
      gesture._preview = preview;
      gesture._error = null;
      return preview;
    } on StudioException catch (e) {
      gesture._error = e.code;
      rethrow;
    }
  }

  ProjectDocument commitGesture(EditGesture gesture) {
    _checkGesture(gesture);
    if (gesture._error != null || gesture._operation == null) {
      throw const StudioException('GESTURE_INVALID');
    }
    _repository.commandHistory(projectId);
    // Known geometric identity: an interaction returning to zero issues no
    // command, rather than allocating fresh Gap/entity versions for no motion.
    final zero = Q.of(0);
    final unchanged = switch (gesture._operation!) {
      MoveClip(:final delta) ||
      MoveClips(:final delta) ||
      TrimClip(:final delta) => delta == zero,
      SlipClip(:final sourceDelta) => sourceDelta == zero,
      _ => false,
    };
    if (unchanged) {
      cancelGesture(gesture);
      return current;
    }
    // One normal command/receipt, not N edits patched together afterwards.
    final receipt = _repository.edit(
      writer: gesture._writer,
      commandId: gesture.id,
      receiptKey: gesture.id,
      expectedRevision: gesture.base.revision,
      operation: gesture._operation!,
    );
    cancelGesture(gesture);
    if (receipt.disposition == 'applied') _durableCommit();
    return current;
  }

  void cancelGesture(EditGesture gesture) {
    if (gesture._finished) return;
    if (!identical(_editGesture, gesture)) {
      throw const StudioException('GESTURE_NOT_ACTIVE');
    }
    gesture._finished = true;
    gesture._generation++;
    gesture._preview = null;
    gesture._operation = null;
    _editGesture = null;
    cancelSourcePreview();
  }

  void _cancelActiveGesture() {
    final active = _editGesture;
    if (active != null) cancelGesture(active);
  }

  Future<SourcePreviewFrame> previewGestureAt(
    EditGesture gesture,
    Q time,
  ) async {
    _checkGesture(gesture);
    if (gesture._error != null) throw const StudioException('GESTURE_INVALID');
    final generation = gesture._generation;
    final frame = await _previewTimelineDocument(gesture.preview, time);
    _checkGesture(gesture);
    if (generation != gesture._generation) {
      throw const StudioException('PREVIEW_SUPERSEDED');
    }
    return frame;
  }
}
