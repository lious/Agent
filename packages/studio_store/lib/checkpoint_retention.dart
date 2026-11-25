part of 'studio_store.dart';

/// Only checkpoint INDEX rows are eligible. No command, revision, snapshot,
/// entity definition, blob pin or physical resource is removed by this policy.
extension CheckpointRetention on DocumentRepository {
  void _retentionGuard(WriterToken writer, BigInt revision) {
    validateWriter(writer);
    if (read(writer.projectId)!.revision != revision) {
      throw const StudioException('REVISION_CONFLICT');
    }
  }

  void configureCheckpointRetention(
    WriterToken writer,
    BigInt revision,
    int? keepLatest, {
    required bool confirmed,
    required void Function() validateStorageAuthority,
  }) {
    if (!confirmed) {
      throw const StudioException('RETENTION_CONFIRMATION_REQUIRED');
    }
    if (keepLatest != null && (keepLatest < 1 || keepLatest > 10000)) {
      throw const StudioException('RETENTION_POLICY_INVALID');
    }
    _transaction(() {
      validateStorageAuthority();
      _retentionGuard(writer, revision);
      _db.execute(
        'INSERT INTO checkpoint_retention VALUES(?,?,?) ON CONFLICT(ns,project_id) DO UPDATE SET keep_latest=excluded.keep_latest',
        [_ns, writer.projectId, keepLatest],
      );
      _retentionGuard(writer, revision);
      validateStorageAuthority();
    });
  }

  String nameCurrentCheckpoint(
    WriterToken writer,
    BigInt revision,
    String name,
  ) => _transaction(() {
    _retentionGuard(writer, revision);
    if (name.trim() != name ||
        name.isEmpty ||
        name.length > 128 ||
        name.runes.any((r) => r < 32 || r == 127)) {
      throw const StudioException('CHECKPOINT_NAME_INVALID');
    }
    if (_db.select(
      'SELECT 1 FROM checkpoint_labels WHERE ns=? AND project_id=? AND name=?',
      [_ns, writer.projectId, name],
    ).isNotEmpty) {
      throw const StudioException('CHECKPOINT_NAME_EXISTS');
    }
    if ((_db.select(
              'SELECT count(*) AS n FROM checkpoint_labels WHERE ns=? AND project_id=?',
              [_ns, writer.projectId],
            ).single['n']
            as int) >=
        10000) {
      throw const StudioException('RETENTION_HISTORY_LIMIT');
    }
    final id = captureCheckpoint(writer);
    _db.execute('INSERT INTO checkpoint_labels VALUES(?,?,?,?)', [
      _ns,
      writer.projectId,
      name,
      id,
    ]);
    return id;
  });

  Map<String, dynamic> reviewCheckpointPruning(
    WriterToken writer,
    BigInt revision,
  ) => _transaction(() => _checkpointReview(writer, revision));

  Map<String, dynamic> _checkpointReview(WriterToken writer, BigInt revision) {
    _retentionGuard(writer, revision);
    final policy = _db.select(
      'SELECT keep_latest FROM checkpoint_retention WHERE ns=? AND project_id=?',
      [_ns, writer.projectId],
    );
    final int? keep = policy.isEmpty
        ? null
        : policy.single['keep_latest'] as int?;
    final rows = _db.select(
      'SELECT id,revision,snapshot_hash FROM checkpoints WHERE ns=? AND project_id=? ORDER BY revision DESC,id LIMIT 10001',
      [_ns, writer.projectId],
    );
    if (rows.length > 10000) {
      throw const StudioException('RETENTION_HISTORY_LIMIT');
    }
    final saved = _db
        .select(
          'SELECT DISTINCT checkpoint_id FROM save_operations WHERE ns=? AND checkpoint_id IN (SELECT id FROM checkpoints WHERE ns=? AND project_id=?) ORDER BY checkpoint_id',
          [_ns, _ns, writer.projectId],
        )
        .map((r) => r['checkpoint_id'])
        .toSet();
    final labels = _db
        .select(
          'SELECT name,checkpoint_id FROM checkpoint_labels WHERE ns=? AND project_id=? ORDER BY name LIMIT 10001',
          [_ns, writer.projectId],
        )
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final pointers = _db
        .select(
          'SELECT checkpoint_id FROM checkpoint_pointers WHERE ns=? AND project_id=?',
          [_ns, writer.projectId],
        )
        .map((r) => r['checkpoint_id'])
        .toSet();
    if (labels.length > 10000) {
      throw const StudioException('RETENTION_HISTORY_LIMIT');
    }
    final checkpointIds = rows.map((r) => r['id']).toSet();
    if (labels.any((l) => !checkpointIds.contains(l['checkpoint_id'])) ||
        pointers.any((id) => !checkpointIds.contains(id))) {
      throw const StudioException('STORE_INTEGRITY');
    }
    final sessionPinned = _db.select(
      'SELECT 1 FROM harness_plans WHERE ns=? AND project_id=? LIMIT 1',
      [_ns, writer.projectId],
    ).isNotEmpty;
    final head = read(writer.projectId)!;
    final entries = <Map<String, dynamic>>[];
    var validatedBytes = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i], id = row['id'];
      final size = _db.select(
        'SELECT length(CAST(json AS BLOB)) AS size FROM snapshots WHERE ns=? AND hash=?',
        [_ns, row['snapshot_hash']],
      );
      if (size.length != 1) throw const StudioException('STORE_INTEGRITY');
      validatedBytes += size.single['size'] as int;
      if (validatedBytes > 64 * 1024 * 1024) {
        throw const StudioException('RETENTION_HISTORY_LIMIT');
      }
      final value =
          _db.select('SELECT json FROM snapshots WHERE ns=? AND hash=?', [
                _ns,
                row['snapshot_hash'],
              ]).single['json']
              as String;
      final doc = ProjectDocument.fromJson(
        readStrictJson(utf8.encode(value)) as Map<String, dynamic>,
      );
      if (doc.hash != row['snapshot_hash'] ||
          doc.namespace != namespace ||
          doc.projectId != writer.projectId ||
          doc.revision.toString() != row['revision'].toString()) {
        throw const StudioException('STORE_INTEGRITY');
      }

      final reasons = <String>[
        if (keep == null) 'preserveAll',
        if (keep != null && i < keep) 'keepLatest',
        if (row['snapshot_hash'] == head.hash) 'currentHead',
        if (pointers.contains(id)) 'latestRecoveryPointer',
        if (saved.contains(id)) 'saveOperationOrReceipt',
        if (labels.any((l) => l['checkpoint_id'] == id)) 'namedVersion',
        if (sessionPinned) 'sessionProjectPin',
      ];
      entries.add({
        'id': id,
        'revision': row['revision'].toString(),
        'snapshot': row['snapshot_hash'],
        'protectedBy': reasons,
      });
    }
    final body = <String, dynamic>{
      'version': 1,
      'namespace': namespace.toJson(),
      'projectId': writer.projectId,
      'revision': revision.toString(),
      'snapshot': head.hash,
      'writer': writer.owner,
      'fence': writer.epoch.toString(),
      'policy': {'keepLatest': keep, 'default': 'preserveAll'},
      'labels': labels,
      'entries': entries,
      'candidates': entries
          .where((e) => (e['protectedBy'] as List).isEmpty)
          .map((e) => e['id'])
          .toList(),
      'scope': 'checkpoint index rows only; ALL snapshots/undo/revisions/blob pins/CAS remain; no disk-byte reclamation promised',
    };
    return {...body, 'reviewHash': contentHash(body)};
  }

  List<Map<String, dynamic>> checkpointPruneAuditHistory(String projectId) {
    requireId(projectId);
    return _db
        .select(
          'SELECT review_hash,json FROM checkpoint_prune_audits WHERE ns=? AND project_id=? ORDER BY rowid DESC LIMIT 20',
          [_ns, projectId],
        )
        .map((row) {
          final audit = readStrictJson(
            utf8.encode(row['json'] as String),
          ) as Map<String, dynamic>;
          final review = Map<String, dynamic>.from(audit['review'] as Map)
            ..remove('reviewHash');
          if (audit['projectId'] != projectId ||
              audit['reviewHash'] != row['review_hash'] ||
              audit['writer'] != review['writer'] ||
              audit['fence'] != review['fence'] ||
              audit['revision'] != review['revision'] ||
              audit['retainedAllSnapshotsPinsAndFiles'] != true ||
              contentHash(audit['removedCheckpointIds']) !=
                  contentHash(review['candidates']) ||
              contentHash(review) != row['review_hash']) {
            throw const StudioException('STORE_INTEGRITY');
          }
          return audit;
        })
        .toList();
  }

  Map<String, dynamic> applyCheckpointPruning(
    WriterToken writer,
    BigInt revision, {
    required String reviewHash,
    required bool confirmed,
    required void Function() validateStorageAuthority,
  }) => _transaction(() {
    if (!confirmed) {
      throw const StudioException('RETENTION_CONFIRMATION_REQUIRED');
    }
    validateStorageAuthority();
    _retentionGuard(writer, revision);
    final prior = _db.select(
      'SELECT json FROM checkpoint_prune_audits WHERE ns=? AND id=? AND project_id=?',
      [_ns, reviewHash, writer.projectId],
    );
    if (prior.isNotEmpty) {
      final audit = jsonDecode(prior.single['json']) as Map<String, dynamic>;
      if (audit['writer'] != writer.owner ||
          audit['fence'] != writer.epoch.toString()) {
        throw const StudioException('RETENTION_REVIEW_STALE');
      }
      return audit;
    }
    final review = _checkpointReview(writer, revision);
    if (review['reviewHash'] != reviewHash) {
      throw const StudioException('RETENTION_REVIEW_STALE');
    }
    for (final id in review['candidates']) {
      _db.execute(
        'DELETE FROM checkpoints WHERE ns=? AND project_id=? AND id=?',
        [_ns, writer.projectId, id],
      );
      if (_db.updatedRows != 1) {
        throw const StudioException('RETENTION_REVIEW_STALE');
      }
    }
    final audit = <String, dynamic>{
      'version': 1,
      'reviewHash': reviewHash,
      'projectId': writer.projectId,
      'revision': revision.toString(),
      'writer': writer.owner,
      'fence': writer.epoch.toString(),
      'removedCheckpointIds': review['candidates'],
      'review': review,
      'retainedAllSnapshotsPinsAndFiles': true,
    };
    _db.execute('INSERT INTO checkpoint_prune_audits VALUES(?,?,?,?,?)', [
      _ns,
      reviewHash,
      writer.projectId,
      reviewHash,
      jsonEncode(audit),
    ]);
    _retentionGuard(writer, revision);
    validateStorageAuthority();
    return audit;
  });
}
