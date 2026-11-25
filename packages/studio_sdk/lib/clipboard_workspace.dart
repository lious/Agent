part of 'studio_sdk.dart';

extension WorkspaceClipboard on StudioWorkspace {
  /// Session-only internal clipboard. Never the OS clipboard; cleared on
  /// close and when the open project identity changes.
  ClipboardPayload? get clipboard => _clipboard;

  ClipboardPayload copySelection(Iterable<String> clipIds) {
    _requireMetadata();
    if (_writer == null) {
      throw const StudioException('PROJECT_NOT_OPEN');
    }
    final payload = buildClipboard(current, clipIds);
    _clipboard = payload;
    return payload;
  }

  ProjectDocument cutSelection(
    Iterable<String> clipIds, {
    required BigInt expectedRevision,
  }) {
    _requireMetadata();
    final payload = buildClipboard(current, clipIds);
    final result = edit(LiftClips(clipIds), expectedRevision: expectedRevision);
    _clipboard = payload;
    return result;
  }

  ProjectDocument pasteClipboard({
    required Q at,
    Map<String, String>? targetTrackMap,
    required BigInt expectedRevision,
  }) {
    _requireMetadata();
    final payload = _clipboard;
    if (payload == null) {
      throw const StudioException('CLIPBOARD_EMPTY');
    }
    return edit(
      PasteClips(payload, at: at, targetTrackMap: targetTrackMap),
      expectedRevision: expectedRevision,
    );
  }

  ProjectDocument groupSelection(
    Iterable<String> clipIds, {
    required BigInt expectedRevision,
  }) {
    return edit(GroupClips(clipIds), expectedRevision: expectedRevision);
  }

  ProjectDocument ungroupSelection(
    Iterable<String> groupIds, {
    required BigInt expectedRevision,
  }) {
    return edit(UngroupClips(groupIds), expectedRevision: expectedRevision);
  }
}
