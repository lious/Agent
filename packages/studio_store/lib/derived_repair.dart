part of 'studio_store.dart';

extension DerivedRepairAuthority on DocumentRepository {
  /// Synchronous publication ONLY, while namespace maintenance lease is held.
  /// Conservatively scan every retained snapshot, not just current blob_edges.
  T withExclusivePreviewRepair<T>({
    required WriterToken writer,
    required BigInt expectedRevision,
    required String expectedSnapshot,
    required String sourceHash,
    required Map<String, String> roles,
    required T Function() publish,
  }) => _transaction(() {
    final head = _db.select(
      'SELECT owner,fence,revision,snapshot_hash FROM project_heads WHERE ns=? AND project_id=?',
      [_ns, writer.projectId],
    );
    if (head.length != 1 ||
        head.single['owner'] != writer.owner ||
        head.single['fence'] != writer.epoch) {
      throw const StudioException('WRITER_FENCED');
    }
    if (head.single['revision'] != expectedRevision.toInt() ||
        head.single['snapshot_hash'] != expectedSnapshot) {
      throw const StudioException('REVISION_CONFLICT');
    }
    if (roles.length != 2 ||
        roles.values.toSet().difference({'proxy', 'ptsMap'}).isNotEmpty ||
        roles.values.toSet().length != 2) {
      throw const StudioException('PROXY_REPAIR_AUTHORITY_INVALID');
    }
    final snapshots = _db.select(
      'SELECT hash,json FROM snapshots WHERE ns=? LIMIT 10001',
      [_ns],
    );
    if (snapshots.length > 10000) {
      throw const StudioException('PROXY_REPAIR_HISTORY_LIMIT');
    }
    final seen = <String>{};
    for (final row in snapshots) {
      final value = jsonDecode(row['json'] as String);
      if (contentHash(value) != row['hash']) {
        throw const StudioException('STORE_INTEGRITY');
      }
      // snapshots also stores immutable command intents/entities, not only roots.
      // Still hash-check every object; reject malformed/future project candidates.
      if (value is! Map<String, dynamic> ||
          !(value.containsKey('schemaVersion') ||
              value.containsKey('rootSequenceId') ||
              (value.containsKey('projectId') && value.containsKey('blobs')))) {
        continue;
      }
      final doc = ProjectDocument.fromJson(value);
      if (doc.hash != row['hash'] || doc.namespace != namespace) {
        throw const StudioException('STORE_INTEGRITY');
      }
      final d = doc.toJson(),
          blobs = {for (final b in doc.toJson()['blobs']) b['hash']: b};
      for (final b in d['blobs']) {
        final role = roles[b['hash']];
        if (role == null) continue;
        if (doc.projectId != writer.projectId) {
          throw const StudioException('PROXY_REPAIR_SHARED_OBJECT');
        }
        if (b['role'] != role) {
          throw const StudioException('PROXY_REPAIR_PROTECTED_ROLE');
        }
        var owned = false;
        for (final a in d['assets']) {
          for (final ref in a['proxyRefs']) {
            if (ref['blobHash'] == b['hash'] ||
                ref['ptsMapBlobHash'] == b['hash']) {
              validatePreviewProxyMetadata(a, ref, blobs);
              if (a['originalBlobHash'] != sourceHash) {
                throw const StudioException('PROXY_REPAIR_SOURCE_CONFLICT');
              }
              owned = true;
            }
          }
        }
        if (!owned) throw const StudioException('PROXY_REPAIR_UNKNOWN_OWNER');
        seen.add(b['hash'] as String);
      }
    }
    if (seen.length != roles.length) {
      throw const StudioException('PROXY_REPAIR_UNKNOWN_OWNER');
    }
    for (final hash in roles.keys) {
      if (_db.select(
        'SELECT 1 FROM blob_edges WHERE ns=? AND blob_hash=? AND project_id<>? LIMIT 1',
        [_ns, hash, writer.projectId],
      ).isNotEmpty) {
        throw const StudioException('PROXY_REPAIR_SHARED_OBJECT');
      }
    }
    return publish();
  });
}
