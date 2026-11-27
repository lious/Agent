import 'dart:convert';

import 'package:studio_contracts/studio_contracts.dart';

import 'studio_document.dart';

/// A detached child timeline opened at a nest clip's pinned version.
/// Opening does not mutate the project and does not auto-follow a newer
/// live child. This is not an in-child edit surface.
final class NestedTimeline {
  NestedTimeline({
    required this.clipId,
    required this.sequenceId,
    required this.version,
    required this.fromRetainedSource,
    required this.sequence,
  });

  final String clipId, sequenceId, version;
  final bool fromRetainedSource;

  /// Detached sequence map at [version]. Callers must not treat this as a
  /// writable document projection.
  final Map<String, dynamic> sequence;

  Q get duration => Q.fromJson(sequence['duration'] as Map<String, dynamic>);
}

/// Enter the child timeline referenced by nest clip [clipId], at the pinned
/// source version only. Historical pins require the retained definition
/// bytes in [snapshotBytes], keyed by `definitionBlobHash`.
NestedTimeline openNested(
  ProjectDocument project,
  String clipId, {
  Map<String, List<int>> snapshotBytes = const {},
}) {
  requireId(clipId);
  final d = project.toJson();
  Map? found;
  for (final sequence in d['sequences'] as List) {
    for (final track in sequence['tracks'] as List) {
      for (final item in track['items'] as List) {
        if (item['id'] == clipId) {
          found = item as Map;
        }
      }
    }
  }
  if (found == null || found['source'] == null) {
    throw StudioException('CLIP_NOT_FOUND', clipId);
  }
  final source = found['source'] as Map;
  if (source['kind'] != 'sequence') {
    throw StudioException('CLIP_NOT_FOUND', clipId);
  }
  final sequenceId = source['id'] as String;
  final version = source['version'] as String;
  requireId(sequenceId);

  final live = [
    for (final s in d['sequences'] as List)
      if (s['id'] == sequenceId) s as Map,
  ];
  if (live.length != 1) {
    throw StudioException('REF_NOT_FOUND', sequenceId);
  }
  if (live.single['version'] == version) {
    return NestedTimeline(
      clipId: clipId,
      sequenceId: sequenceId,
      version: version,
      fromRetainedSource: false,
      sequence: jsonDecode(jsonEncode(live.single)) as Map<String, dynamic>,
    );
  }

  final refs = [
    for (final r in d['retainedSources'] as List)
      if (r['kind'] == 'sequence' &&
          r['id'] == sequenceId &&
          r['version'] == version)
        r as Map,
  ];
  if (refs.length != 1) {
    throw const StudioException('SOURCE_VERSION_MISSING');
  }
  final hash = refs.single['definitionBlobHash'] as String;
  final data = snapshotBytes[hash];
  if (data == null) {
    throw const StudioException('RESOURCE_BYTES_MISSING');
  }
  if (data.length > 1024 * 1024) {
    throw const StudioException('RETAINED_CLOSURE_LIMIT');
  }
  if (rawBytesHash(data) != hash) {
    throw const StudioException('BLOB_HASH_MISMATCH');
  }
  final value = readStrictJson(data, maxBytes: 1024 * 1024);
  if (value is! Map<String, dynamic>) {
    throw const StudioException('RETAINED_SNAPSHOT_INVALID');
  }
  final snapshot = ProjectDocument.fromJson(value);
  if (snapshot.namespace != project.namespace ||
      snapshot.projectId != project.projectId) {
    throw const StudioException('RETAINED_ORIGIN_MISMATCH');
  }
  final historical = [
    for (final s in snapshot.toJson()['sequences'] as List)
      if (s['id'] == sequenceId && s['version'] == version) s as Map,
  ];
  if (historical.length != 1) {
    throw const StudioException('SOURCE_VERSION_MISSING');
  }
  return NestedTimeline(
    clipId: clipId,
    sequenceId: sequenceId,
    version: version,
    fromRetainedSource: true,
    sequence: jsonDecode(jsonEncode(historical.single)) as Map<String, dynamic>,
  );
}
