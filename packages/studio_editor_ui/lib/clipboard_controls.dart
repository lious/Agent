part of 'studio_editor_ui.dart';

extension _ClipboardControls on _FoundationAppState {
  Widget _buildCollisionModeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Collision mode for paste and same-track moves. Reject leaves existing clips and refuses overlap. Overwrite cuts intersecting destination intervals and does not move later content. Insert splits ripple tracks at the destination, shifts later content by the package span, fills gaps on non-target ripple tracks, and grows duration by that span; a move vacates its source as a gap and does not ripple-close it. Ripple delete of a single continuous range is a separate button and closes that hole. Ripple trim out/in of one clip (plus links) shortens and closes the vacated tail; Ripple trim out/in lengthen grows the clip and shifts later content on participating tracks. Leave-gap trim, clip-id or range ripple delete, and Ripple close range stay separate buttons. Insert-mode moves still leave a source gap; Ripple close range closes one explicit continuous interval, including that vacated hole, and is not a new move mode. New tracks and cross-project paste remain closed. clipLocal cues follow their host on MoveClips; new and imported cues that sit fully on a unique covering clip default to clipLocal, and cues in a gap or spanning a cut stay absolute. Explicit source-anchored cues reproject with their host when still covered; an uncovering interval refuses. Ripple delete, range close, ripple trim, and insert paste or insert-move crop, split, and shift absolute cues across that interval and rebind clipLocal remnants to a covering host; insert-move still leaves a source gap and does not auto-close it. MP4 text burn-in stays refused. Sequence markers can be added as absolute (stay put unless ripple is on) or anchored clipLocal (follow the host); labels are not burned into preview or export. Locks, sync-locked locked tracks and incomplete handles refuse the whole group. Linked partners and selection groups are included by default; Ignore links and groups this move (or Alt-drag) is a same-command exception that marks allowOutOfSync and does not rewrite offsets.',
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
          'Internal clipboard and selection groups. This is NOT the operating-system clipboard and is cleared when the open project changes. Same-project paste onto existing same-kind tracks only. Collision mode (shared control above) is reject, overwrite or insert. Ripple delete of a selected continuous range, ripple trim out/in (shorten or lengthen) of one clip, and Ripple close range of an explicit interval (including a vacated move source) are separate buttons. New tracks and cross-project paste are not in this slice. Insert-mode moves still leave a source gap until it is closed. Admitted captions are absolute and stay put; clip-local caption follow is not opened. Marker-bearing projects still refuse editing.',
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
