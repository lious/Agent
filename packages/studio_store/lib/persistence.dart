part of 'studio_store.dart';

/// Derived from immutable checkpoints and FULL-transaction save receipts. No
/// duplicate writable dirty/durable/userSavedRevision counters exist.
final class PersistenceView {
  PersistenceView(
    this.headRevision,
    this.checkpointRevision,
    this.userSavedRevision,
    this.targetSavedRevision,
  );
  final BigInt headRevision;
  final BigInt? checkpointRevision, userSavedRevision, targetSavedRevision;
  bool get packageBehind => targetSavedRevision != headRevision;
}

extension PersistenceRepository on DocumentRepository {
  void validateWriter(WriterToken writer) {
    if (writer.namespace != namespace) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
    final rows = _db.select(
      'SELECT owner,fence FROM project_heads WHERE ns=? AND project_id=?',
      [_ns, writer.projectId],
    );
    if (rows.length != 1) throw const StudioException('PROJECT_NOT_FOUND');
    if (rows.single['owner'] != writer.owner ||
        rows.single['fence'] != writer.epoch) {
      throw const StudioException('WRITER_FENCED');
    }
  }

  String captureCheckpoint(WriterToken writer, {ProjectDocument? snapshot}) =>
      _transaction(() {
        validateWriter(writer);
        final current = read(writer.projectId)!;
        final p = snapshot ?? current;
        if (p.namespace != namespace ||
            p.projectId != writer.projectId ||
            p.revision > current.revision) {
          throw const StudioException('CHECKPOINT_SCOPE_MISMATCH');
        }
        final existing = _db.select(
          'SELECT json FROM snapshots WHERE ns=? AND hash=?',
          [_ns, p.hash],
        );
        if (existing.length != 1 ||
            existing.single['json'] != p.canonicalJson) {
          throw const StudioException('STORE_INTEGRITY');
        }
        final id = contentHash({
          'namespace': namespace.toJson(),
          'projectId': p.projectId,
          'snapshot': p.hash,
        });
        _db.execute('INSERT OR IGNORE INTO checkpoints VALUES(?,?,?,?,?)', [
          _ns,
          id,
          p.projectId,
          p.revision.toInt(),
          p.hash,
        ]);
        final previous = _db.select(
          'SELECT c.revision FROM checkpoint_pointers p JOIN checkpoints c ON c.ns=p.ns AND c.id=p.checkpoint_id WHERE p.ns=? AND p.project_id=?',
          [_ns, p.projectId],
        );
        if (previous.isEmpty ||
            (previous.single['revision'] as int) <= p.revision.toInt()) {
          _db.execute(
            'INSERT INTO checkpoint_pointers VALUES(?,?,?) ON CONFLICT(ns,project_id) DO UPDATE SET checkpoint_id=excluded.checkpoint_id',
            [_ns, p.projectId, id],
          );
        }
        return id;
      });
  String beginSave(
    WriterToken writer,
    ProjectDocument snapshot, {
    String? targetPath,
    String? stagePath,
    String? oldHash,
    required bool explicit,
  }) {
    final checkpoint = captureCheckpoint(writer, snapshot: snapshot),
        id = const Uuid().v7();
    _transaction(() {
      validateWriter(writer);
      _db.execute(
        'INSERT INTO save_operations(ns,id,checkpoint_id,target_path,stage_path,old_hash,explicit,state) VALUES(?,?,?,?,?,?,?,\'preparing\')',
        [_ns, id, checkpoint, targetPath, stagePath, oldHash, explicit ? 1 : 0],
      );
    });
    return id;
  }

  Map<String, dynamic> saveOperation(String id) {
    final rows = _db.select(
      'SELECT o.*,c.project_id,c.revision,c.snapshot_hash FROM save_operations o JOIN checkpoints c ON c.ns=o.ns AND c.id=o.checkpoint_id WHERE o.ns=? AND o.id=?',
      [_ns, id],
    );
    if (rows.length != 1) {
      throw const StudioException('SAVE_OPERATION_NOT_FOUND');
    }
    return Map<String, dynamic>.from(rows.single);
  }

  List<Map<String, dynamic>> pendingSaveOperations(String projectId) => _db
      .select(
        "SELECT o.id FROM save_operations o JOIN checkpoints c ON c.ns=o.ns AND c.id=o.checkpoint_id WHERE o.ns=? AND c.project_id=? AND o.state IN ('preparing','publishing','uncertain')",
        [_ns, projectId],
      )
      .map((r) => saveOperation(r['id'] as String))
      .toList();
  void markSavePublishing(
    WriterToken writer,
    String id,
    String hash, {
    String? oldHash,
  }) => _transaction(() {
    validateWriter(writer);
    final op = saveOperation(id);
    if (op['project_id'] != writer.projectId || op['state'] != 'preparing') {
      throw const StudioException('SAVE_STATE_CONFLICT');
    }
    _db.execute(
      "UPDATE save_operations SET new_hash=?,old_hash=?,state='publishing' WHERE ns=? AND id=?",
      [hash, oldHash, _ns, id],
    );
  });
  void finishSave(
    WriterToken writer,
    String id,
    String artifactHash,
  ) => _transaction(() {
    validateWriter(writer);
    final op = saveOperation(id);
    if (op['project_id'] != writer.projectId) {
      throw const StudioException('CHECKPOINT_SCOPE_MISMATCH');
    }
    if (op['state'] == 'committed') {
      final receipts = _db.select(
        'SELECT artifact_hash FROM save_receipts WHERE ns=? AND operation_id=?',
        [_ns, id],
      );
      if (receipts.length != 1 ||
          receipts.single['artifact_hash'] != artifactHash) {
        throw const StudioException('SAVE_HASH_MISMATCH');
      }
      return;
    }
    if (!['preparing', 'publishing', 'uncertain'].contains(op['state'])) {
      throw const StudioException('SAVE_STATE_CONFLICT');
    }
    if (op['target_path'] != null && op['new_hash'] != artifactHash) {
      throw const StudioException('SAVE_HASH_MISMATCH');
    }
    if (op['target_path'] == null && op['snapshot_hash'] != artifactHash) {
      throw const StudioException('SAVE_HASH_MISMATCH');
    }
    _db.execute(
      'INSERT INTO save_receipts(ns,operation_id,checkpoint_id,artifact_hash) VALUES(?,?,?,?)',
      [_ns, id, op['checkpoint_id'], artifactHash],
    );
    _db.execute(
      "UPDATE save_operations SET state='committed',error=NULL WHERE ns=? AND id=?",
      [_ns, id],
    );
  });
  void failSave(
    String id,
    String code, {
    bool uncertain = false,
    bool cancelled = false,
  }) => _transaction(() {
    final op = saveOperation(id);
    if (op['state'] == 'committed') return;
    _db.execute(
      'UPDATE save_operations SET state=?,error=? WHERE ns=? AND id=?',
      [
        uncertain
            ? 'uncertain'
            : cancelled
            ? 'cancelled'
            : 'failed',
        code,
        _ns,
        id,
      ],
    );
  });
  BigInt saveManaged(WriterToken writer) {
    final p = read(writer.projectId)!;
    final id = beginSave(writer, p, explicit: true);
    finishSave(writer, id, p.hash);
    return p.revision;
  }

  PersistenceView persistenceView(String projectId, {String? targetPath}) {
    final p = read(projectId);
    if (p == null) throw const StudioException('PROJECT_NOT_FOUND');
    final checkpoint = _db.select(
      'SELECT c.revision FROM checkpoint_pointers p JOIN checkpoints c ON c.ns=p.ns AND c.id=p.checkpoint_id WHERE p.ns=? AND p.project_id=?',
      [_ns, projectId],
    );
    BigInt? receipt({required bool explicit}) {
      final rows = _db.select(
        'SELECT c.revision FROM save_receipts r JOIN checkpoints c ON c.ns=r.ns AND c.id=r.checkpoint_id JOIN save_operations o ON o.ns=r.ns AND o.id=r.operation_id WHERE r.ns=? AND c.project_id=? ${explicit ? 'AND o.explicit=1' : 'AND o.target_path=?'} ORDER BY r.seq DESC LIMIT 1',
        [_ns, projectId, if (!explicit) targetPath],
      );
      return rows.isEmpty ? null : BigInt.from(rows.single['revision'] as int);
    }

    return PersistenceView(
      p.revision,
      checkpoint.isEmpty
          ? null
          : BigInt.from(checkpoint.single['revision'] as int),
      receipt(explicit: true),
      targetPath == null ? null : receipt(explicit: false),
    );
  }
}
