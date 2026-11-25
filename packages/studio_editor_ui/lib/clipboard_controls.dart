part of 'studio_editor_ui.dart';

extension _ClipboardControls on _FoundationAppState {
  Widget _buildCollisionModeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Collision mode for paste and same-track moves. Reject leaves existing clips and refuses overlap. Overwrite cuts intersecting destination intervals and does not move later content. Insert splits ripple tracks at the destination, shifts later content by the package span, fills gaps on non-target ripple tracks, and grows duration by that span; a move vacates its source as a gap and does not ripple-close it. Ripple delete of a single continuous range is a separate button and closes that hole. Ripple trim out/in of one clip (plus links) is a separate button and shortens, then closes the vacated tail; lengthening and closing a move source remain closed. New tracks and cross-project paste remain closed. Caption cue follow is not opened (mid-timeline insert with cues is refused). Locks, sync-locked locked tracks and incomplete handles refuse the whole group. Linked partners are included.',
        ),
        Text(
          'Collision mode: $_collisionMode',
          key: const Key('collision-mode-status'),
        ),
        Wrap(
          children: [
            for (final mode in const ['reject', 'overwrite', 'insert'])
              TextButton(
                key: Key('collision-mode-$mode'),
                onPressed: _clipboardBlocked
                    ? null
                    : () => _gestureSetState(() {
                        _collisionMode = mode;
                        _clipboardError = null;
                      }),
                child: Text(
                  mode == 'overwrite'
                      ? 'Overwrite'
                      : mode == 'insert'
                      ? 'Insert'
                      : 'Reject overlap',
                ),
              ),
          ],
        ),
      ],
    );
  }

  bool get _clipboardBlocked =>
      _busy ||
      _multiPreviewBusy ||
      _gesture != null ||
      _multiGesture != null ||
      _pointerActive;

  void _clipboardAct(void Function() action) {
    if (_clipboardBlocked) {
      _gestureSetState(() => _clipboardError = 'GESTURE_IN_PROGRESS');
      return;
    }
    try {
      action();
      _gestureSetState(() {
        _refresh();
        _clipboardError = null;
        _error = null;
      });
    } catch (e) {
      _gestureSetState(
        () => _clipboardError = e is StudioException
            ? e.code
            : 'LOCAL_COMMIT_FAILED',
      );
    }
  }

  Q _pasteTime() {
    final raw = _pasteAt.text.trim();
    if (raw.isEmpty) {
      return Q.fromJson(_project.toJson()['sequences'][0]['duration']);
    }
    return _snapDecimal(raw);
  }

  Widget _buildClipboardControls() {
    final payload = widget.workspace.clipboard;
    final groups = {
      for (final id in _multiSelection)
        for (final c in _clips)
          if (c['id'] == id && c['selectionGroupId'] != null)
            c['selectionGroupId'] as String,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Internal clipboard and selection groups. This is NOT the operating-system clipboard and is cleared when the open project changes. Same-project paste onto existing same-kind tracks only. Collision mode (shared control above) is reject, overwrite or insert. Ripple delete of a single continuous range and ripple trim out/in of one clip are separate buttons. Ripple lengthening, closing a move source, new tracks and cross-project paste are not in this slice. Admitted captions are absolute and stay put; clip-local caption follow is not opened. Marker-bearing projects still refuse editing.',
        ),
        Text(
          payload == null
              ? 'Internal clipboard empty'
              : 'Internal clipboard ${payload.hash} · ${payload.clipIds.length} clips · origin ${payload.origin}',
          key: const Key('clipboard-status'),
        ),
        TextField(
          key: const Key('clipboard-paste-at'),
          controller: _pasteAt,
          enabled: !_clipboardBlocked,
          decoration: const InputDecoration(
            labelText: 'Paste at (seconds; empty = current duration)',
          ),
        ),
        Wrap(
          children: [
            TextButton(
              key: const Key('clipboard-copy'),
              onPressed: _clipboardBlocked
                  ? null
                  : () => _clipboardAct(
                      () => widget.workspace.copySelection(_multiSelection),
                    ),
              child: const Text('Copy selection'),
            ),
            TextButton(
              key: const Key('clipboard-cut'),
              onPressed: _clipboardBlocked
                  ? null
                  : () => _clipboardAct(
                      () => widget.workspace.cutSelection(
                        _multiSelection,
                        expectedRevision: _project.revision,
                      ),
                    ),
              child: const Text('Cut selection'),
            ),
            TextButton(
              key: const Key('clipboard-paste'),
              onPressed: _clipboardBlocked
                  ? null
                  : () => _clipboardAct(
                      () => widget.workspace.pasteClipboard(
                        at: _pasteTime(),
                        mode: _collisionMode,
                        expectedRevision: _project.revision,
                      ),
                    ),
              child: const Text('Paste internal clipboard'),
            ),
            TextButton(
              key: const Key('clipboard-group'),
              onPressed: _clipboardBlocked
                  ? null
                  : () => _clipboardAct(
                      () => widget.workspace.groupSelection(
                        _multiSelection,
                        expectedRevision: _project.revision,
                      ),
                    ),
              child: const Text('Group selection'),
            ),
            TextButton(
              key: const Key('clipboard-ungroup'),
              onPressed: _clipboardBlocked
                  ? null
                  : () => _clipboardAct(() {
                      if (groups.isEmpty) {
                        throw const StudioException('GROUP_NOT_FOUND');
                      }
                      widget.workspace.ungroupSelection(
                        groups,
                        expectedRevision: _project.revision,
                      );
                    }),
              child: const Text('Ungroup selection'),
            ),
          ],
        ),
        if (_clipboardError != null)
          Text(
            'Clipboard: $_clipboardError',
            key: const Key('clipboard-error'),
          ),
      ],
    );
  }
}
