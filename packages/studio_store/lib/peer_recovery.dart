part of 'studio_store.dart';

/// Trusted-local administration only; NONE of these are peer RPC operations.
extension MetadataRecovery on DocumentRepository {
  Map<String, dynamic> _metadataManifest(SessionRef session, String planHash) {
    final row = _planRow(session, planHash);
    final records = _db.select(
      'SELECT * FROM peer_session_recovery WHERE ns=? AND session_id=? AND plan_hash=?',
      [_ns, session.id, planHash],
    );
    if (records.length != 1) {
      throw const StudioException('RECOVERY_NOT_REGISTERED');
    }
    final record = records.single;
    final manifest =
        jsonDecode(record['manifest'] as String) as Map<String, dynamic>;
    if (contentHash(manifest) != record['hash'] ||
        manifest['schemaVersion'] != 'metadata-session-1' ||
        manifest['ownerFingerprint'] != record['owner_fingerprint']) {
      throw const StudioException('RECOVERY_INTEGRITY');
    }
    final plan = HarnessPlan(
      jsonDecode(row['json'] as String) as Map<String, dynamic>,
    );
    final inputs = manifest['inputs'] as Map<String, dynamic>;
    if (plan.hash != planHash ||
        utf8.encode(jsonEncode(inputs)).length > 65536) {
      throw const StudioException('RECOVERY_INTEGRITY');
    }
    for (final raw in plan.toJson()['nodes'] as List) {
      final node = raw as Map;
      if (node['kind'] != 'tool' ||
          node['handlerPin']['id'] != 'core.digest-json' ||
          harnessHash(inputs[node['inputRef']['hash']]) !=
              node['inputRef']['hash']) {
        throw const StudioException('RECOVERY_INTEGRITY');
      }
    }
    return {
      ...manifest,
      'plan': plan.toJson(),
      'projectId': row['project_id'],
      'currentBoot': row['boot'],
      'lastMs': row['last_ms'],
    };
  }

  void rememberMetadataSession(
    SessionRef session,
    String planHash, {
    required String ownerFingerprint,
    required Map<String, Object?> inputs,
    required Map<String, Object?>? anchor,
  }) => _transaction(() {
    _peerHash(ownerFingerprint);
    final row = _planRow(session, planHash);
    final manifest = <String, dynamic>{
      'schemaVersion': 'metadata-session-1',
      'ownerFingerprint': ownerFingerprint,
      'inputs': inputs,
      'anchor': anchor,
      'boot': row['boot'],
    };
    final old = _db.select(
      'SELECT owner_fingerprint FROM peer_session_recovery WHERE ns=? AND session_id=? AND plan_hash=?',
      [_ns, session.id, planHash],
    );
    if (old.isNotEmpty) {
      if (old.single['owner_fingerprint'] != ownerFingerprint) {
        throw const StudioException('RECOVERY_OWNER_MISMATCH');
      }
      _metadataManifest(session, planHash);
      return;
    }
    _db.execute('INSERT INTO peer_session_recovery VALUES(?,?,?,?,?,?)', [
      _ns,
      session.id,
      planHash,
      ownerFingerprint,
      jsonEncode(manifest),
      contentHash(manifest),
    ]);
    _metadataManifest(session, planHash);
  });

  List<Map<String, dynamic>> metadataSessions(
    String projectId,
    String ownerFingerprint,
  ) {
    _peerHash(ownerFingerprint);
    return [
      for (final r in _db.select(
        'SELECT r.session_id,r.plan_hash FROM peer_session_recovery r JOIN harness_plans p ON p.ns=r.ns AND p.session_id=r.session_id AND p.plan_hash=r.plan_hash WHERE r.ns=? AND r.owner_fingerprint=? AND p.project_id=? ORDER BY r.rowid DESC LIMIT 100',
        [_ns, ownerFingerprint, projectId],
      ))
        {'sessionId': r['session_id'], 'planHash': r['plan_hash']},
    ];
  }

  Map<String, dynamic> metadataRecoveryRecord(
    SessionRef session,
    String planHash,
    String ownerFingerprint,
  ) {
    final record = _metadataManifest(session, planHash);
    if (record['ownerFingerprint'] != ownerFingerprint) {
      throw const StudioException('RECOVERY_OWNER_MISMATCH');
    }
    return record;
  }

  void authorizeMetadataRecovery(
    SessionRef session,
    String planHash, {
    required String ownerFingerprint,
    required String expectedBoot,
    required String newBoot,
    required String operationId,
    required Map<String, Object?>? newAnchor,
    int? unobservedElapsedUpperBoundMs,
  }) => _transaction(() {
    final record = metadataRecoveryRecord(session, planHash, ownerFingerprint);
    final requestHash = contentHash({
      'expectedBoot': expectedBoot,
      'newBoot': newBoot,
      'anchor': newAnchor,
      'elapsed': unobservedElapsedUpperBoundMs,
    });
    if (record['lastRecoveryOperation'] == operationId) {
      if (record['lastRecoveryHash'] != requestHash) {
        throw const StudioException('IDEMPOTENCY_CONFLICT');
      }
      if (record['currentBoot'] != newBoot) {
        throw const StudioException('COORDINATOR_FENCED');
      }
      return;
    }
    if (record['currentBoot'] != expectedBoot) {
      throw const StudioException('COORDINATOR_FENCED');
    }
    final plan = HarnessPlan(record['plan'] as Map<String, dynamic>);
    if (read(record['projectId'] as String)!.revision !=
        u63(plan.toJson()['baseRevision'])) {
      throw const StudioException('REVISION_CONFLICT');
    }
    takeoverHarnessPlan(
      session,
      planHash,
      expectedBoot: expectedBoot,
      newBoot: newBoot,
      operationId: operationId,
      unobservedElapsedUpperBoundMs: unobservedElapsedUpperBoundMs,
    );
    // A takeover is NOT renewal of any old device/material permission.
    _db.execute(
      'UPDATE peer_grants SET revoked=1,epoch=epoch+1 WHERE ns=? AND session_id=? AND plan_hash=? AND revoked=0',
      [_ns, session.id, planHash],
    );
    _db.execute(
      r"UPDATE peer_offers SET used=1 WHERE ns=? AND json_extract(json,'$.sessionId')=? AND json_extract(json,'$.planHash')=?",
      [_ns, session.id, planHash],
    );
    for (final k in ['plan', 'projectId', 'currentBoot', 'lastMs']) {
      record.remove(k);
    }
    record.addAll({
      'boot': newBoot,
      'anchor': newAnchor,
      'lastRecoveryOperation': operationId,
      'lastRecoveryHash': requestHash,
    });
    _db.execute(
      'UPDATE peer_session_recovery SET manifest=?,hash=? WHERE ns=? AND session_id=? AND plan_hash=?',
      [jsonEncode(record), contentHash(record), _ns, session.id, planHash],
    );
  });

  bool peerAdoptionAlreadyApplied(
    WriterToken writer,
    String id,
    String inputHash,
  ) {
    final rows = _db.select(
      'SELECT input_hash FROM peer_adoptions WHERE ns=? AND project_id=? AND id=?',
      [_ns, writer.projectId, id],
    );
    if (rows.isEmpty) return false;
    if (rows.single['input_hash'] != inputHash) {
      throw const StudioException('IDEMPOTENCY_CONFLICT');
    }
    return true;
  }

  bool commitPeerAdoption({
    required WriterToken writer,
    required String id,
    required String inputHash,
    required BigInt expectedRevision,
    required EditOperation operation,
  }) => _transaction(() {
    requireId(id);
    if (peerAdoptionAlreadyApplied(writer, id, inputHash)) return false;
    edit(
      writer: writer,
      commandId: id,
      receiptKey: id,
      expectedRevision: expectedRevision,
      operation: operation,
    );
    _db.execute('INSERT INTO peer_adoptions VALUES(?,?,?,?)', [
      _ns,
      writer.projectId,
      id,
      inputHash,
    ]);
    return true;
  });

  /// Hold the SQLite writer transaction while a controlled synchronous CAS GC
  /// inspects all historical pins. No live revision/history/checkpoint is pruned.
  T withRetainedBlobPins<T>(T Function(Set<String>) action) => _transaction(
    () => action({
      for (final row in _db.select(
        'SELECT DISTINCT blob_hash FROM blob_edges WHERE ns=?',
        [_ns],
      ))
        row['blob_hash'] as String,
    }),
  );

  Map<String, int> collectPeerInbox({required int nowMs}) {
    _transaction(() => _peerClock(nowMs));
    return _transaction(() {
      final stale = _db.select(
        r"SELECT s.* FROM peer_blob_stages s LEFT JOIN peer_grants g ON g.ns=s.ns AND g.fingerprint=s.fingerprint AND g.session_id=s.session_id AND g.plan_hash=s.plan_hash WHERE s.ns=? AND (g.ns IS NULL OR g.revoked=1 OR g.epoch!=s.epoch OR json_extract(g.json,'$.expiresMs')<=?)",
        [_ns, nowMs],
      );
      var bytes = 0;
      for (final r in stale) {
        final key = [
          _ns,
          r['fingerprint'],
          r['session_id'],
          r['plan_hash'],
          r['epoch'],
          r['hash'],
        ];
        bytes += r['size'] as int;
        _db.execute(
          'DELETE FROM peer_blob_chunks WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=? AND hash=?',
          key,
        );
        _db.execute(
          'DELETE FROM peer_blob_stages WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=? AND hash=?',
          key,
        );
      }
      final objects = _db.select(
        'SELECT hash FROM peer_blob_objects o WHERE o.ns=? AND NOT EXISTS(SELECT 1 FROM peer_blob_stages s WHERE s.ns=o.ns AND s.hash=o.hash)',
        [_ns],
      );
      for (final r in objects) {
        _db.execute('DELETE FROM peer_blob_objects WHERE ns=? AND hash=?', [
          _ns,
          r['hash'],
        ]);
      }
      return {
        'stages': stale.length,
        'objects': objects.length,
        'releasedLogicalBytes': bytes,
      };
    });
  }
}
