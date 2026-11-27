import 'package:studio_contracts/studio_contracts.dart';

import 'library_store.dart';
import 'portrait_rights.dart';

/// Library GC for CharacterPack versions.
///
/// Project pins, export pins, and candidate-task pins are all GC roots.
/// Deleting a library head does not delete versions still referenced by old
/// projects. A version may be recycled only when it has zero references and
/// is not in a retain or revocation-cleanup plan. Revocation first blocks
/// access; physical GC may be retried later.
final class CharacterLibraryGc {
  CharacterLibraryGc(this.store);

  final CharacterLibraryStore store;
  static const _kind = 'character';

  void pinExport(ExportPin pin, {DateTime? now}) {
    requireId(pin.exportId);
    requireId(pin.libraryId);
    requireId(pin.entityId);
    _requireVersion(pin.libraryId, pin.entityId, pin.version, pin.packHash);
    final created = (now ?? DateTime.now()).toUtc().toIso8601String();
    store.transaction(() {
      store.execute(
        'INSERT INTO library_export_pins(namespace,export_id,library_id,kind,'
        'entity_id,version,pack_hash,created_at) VALUES(?,?,?,?,?,?,?,?)',
        [
          store.ns,
          pin.exportId,
          pin.libraryId,
          pin.kind,
          pin.entityId,
          pin.version,
          pin.packHash,
          created,
        ],
      );
    });
  }

  void releaseExportPin(String exportId) {
    store.execute(
      'DELETE FROM library_export_pins WHERE namespace=? AND export_id=?',
      [store.ns, exportId],
    );
  }

  void pinCandidateTask(CandidateTaskPin pin) {
    requireId(pin.taskId);
    requireId(pin.libraryId);
    requireId(pin.entityId);
    const allowed = {'processing', 'ready', 'cancelled', 'isolated'};
    if (!allowed.contains(pin.state)) {
      throw const StudioException('SCHEMA_INVALID', 'state');
    }
    _requireVersion(pin.libraryId, pin.entityId, pin.version, pin.packHash);
    store.transaction(() {
      store.execute(
        'INSERT INTO library_candidate_pins(namespace,task_id,library_id,kind,'
        'entity_id,version,pack_hash,state) VALUES(?,?,?,?,?,?,?,?)',
        [
          store.ns,
          pin.taskId,
          pin.libraryId,
          pin.kind,
          pin.entityId,
          pin.version,
          pin.packHash,
          pin.state,
        ],
      );
    });
  }

  void releaseCandidatePin(String taskId) {
    store.execute(
      'DELETE FROM library_candidate_pins WHERE namespace=? AND task_id=?',
      [store.ns, taskId],
    );
  }

  List<Map<String, Object?>> candidatePinsForRightsPack({
    required String libraryId,
    required String entityId,
    required String version,
  }) {
    return [
      for (final row in store.select(
        'SELECT task_id, state, pack_hash FROM library_candidate_pins '
        'WHERE namespace=? AND library_id=? AND kind=? AND entity_id=? '
        'AND version=?',
        [store.ns, libraryId, _kind, entityId, version],
      ))
        Map<String, Object?>.from(row),
    ];
  }

  /// Remove the library head pointer. Referenced library_versions rows are
  /// retained.
  HeadDeleteReport deleteHead(String libraryId, String entityId) {
    requireId(libraryId);
    requireId(entityId);
    return store.transaction(() {
      final head = store.select(
        'SELECT head_version FROM library_heads WHERE namespace=? AND '
        'library_id=? AND kind=? AND entity_id=?',
        [store.ns, libraryId, _kind, entityId],
      );
      final current = head.isEmpty
          ? null
          : head.single['head_version'] as String;
      if (current != null) {
        store.execute(
          'DELETE FROM library_heads WHERE namespace=? AND library_id=? AND '
          'kind=? AND entity_id=?',
          [store.ns, libraryId, _kind, entityId],
        );
      }
      final versions = store.select(
        'SELECT version FROM library_versions WHERE namespace=? AND '
        'library_id=? AND kind=? AND entity_id=? '
        'ORDER BY length(version), version',
        [store.ns, libraryId, _kind, entityId],
      );
      return HeadDeleteReport(
        libraryId: libraryId,
        entityId: entityId,
        deletedHeadVersion: current,
        remainingVersions: [
          for (final row in versions) row['version'] as String,
        ],
      );
    });
  }

  void retainVersion({
    required String planId,
    required String libraryId,
    required String entityId,
    required String version,
    String kind = _kind,
  }) {
    requireId(planId);
    _insertPlan(
      planId: planId,
      libraryId: libraryId,
      entityId: entityId,
      version: version,
      kind: kind,
      reason: 'retain',
    );
  }

  void planRevocationCleanup({
    required String planId,
    required String libraryId,
    required String entityId,
    required String version,
    String kind = _kind,
  }) {
    requireId(planId);
    _insertPlan(
      planId: planId,
      libraryId: libraryId,
      entityId: entityId,
      version: version,
      kind: kind,
      reason: 'revocationCleanup',
    );
  }

  void releasePlan(String planId) {
    store.execute(
      'DELETE FROM library_retention_plans WHERE namespace=? AND plan_id=?',
      [store.ns, planId],
    );
  }

  /// Recycle a version only when it has zero GC-root references and is not
  /// held by a retain or revocation-cleanup plan. A still-current library
  /// head must be deleted first. Pending revocation cleanup is retryable.
  RecycleReport recycle({
    required String libraryId,
    required String entityId,
    required String version,
    String kind = _kind,
  }) {
    requireId(libraryId);
    requireId(entityId);
    return store.transaction(() {
      final exists = store.select(
        'SELECT body_hash FROM library_versions WHERE namespace=? AND '
        'library_id=? AND kind=? AND entity_id=? AND version=?',
        [store.ns, libraryId, kind, entityId, version],
      );
      if (exists.isEmpty) {
        throw const StudioException('RESOURCE_MISSING', 'library_versions');
      }
      final head = store.select(
        'SELECT head_version FROM library_heads WHERE namespace=? AND '
        'library_id=? AND kind=? AND entity_id=?',
        [store.ns, libraryId, kind, entityId],
      );
      if (head.isNotEmpty && head.single['head_version'] == version) {
        return const RecycleReport(
          recycled: false,
          retryable: false,
          code: 'HEAD_PRESENT',
        );
      }
      final projectRefs = _count(
        'SELECT COUNT(*) AS c FROM library_project_pins WHERE namespace=? '
        'AND library_id=? AND kind=? AND entity_id=? AND version=?',
        [store.ns, libraryId, kind, entityId, version],
      );
      final exportRefs = _count(
        'SELECT COUNT(*) AS c FROM library_export_pins WHERE namespace=? '
        'AND library_id=? AND kind=? AND entity_id=? AND version=?',
        [store.ns, libraryId, kind, entityId, version],
      );
      final candidateRefs = _count(
        'SELECT COUNT(*) AS c FROM library_candidate_pins WHERE namespace=? '
        'AND library_id=? AND kind=? AND entity_id=? AND version=?',
        [store.ns, libraryId, kind, entityId, version],
      );
      final references = projectRefs + exportRefs + candidateRefs;
      if (references > 0) {
        return RecycleReport(
          recycled: false,
          retryable: false,
          code: 'HAS_REFERENCES',
          referenceCount: references,
        );
      }
      final retain = _count(
        'SELECT COUNT(*) AS c FROM library_retention_plans WHERE namespace=? '
        'AND library_id=? AND kind=? AND entity_id=? AND version=? AND '
        "reason='retain'",
        [store.ns, libraryId, kind, entityId, version],
      );
      if (retain > 0) {
        return const RecycleReport(
          recycled: false,
          retryable: false,
          code: 'RETAINED',
        );
      }
      final cleanup = _count(
        'SELECT COUNT(*) AS c FROM library_retention_plans WHERE namespace=? '
        'AND library_id=? AND kind=? AND entity_id=? AND version=? AND '
        "reason='revocationCleanup'",
        [store.ns, libraryId, kind, entityId, version],
      );
      if (cleanup > 0) {
        return const RecycleReport(
          recycled: false,
          retryable: true,
          code: 'REVOCATION_CLEANUP_PENDING',
        );
      }
      store.execute(
        'DELETE FROM character_look_index WHERE namespace=? AND library_id=? '
        'AND kind=? AND asset_id=? AND asset_version=?',
        [store.ns, libraryId, kind, entityId, version],
      );
      store.execute(
        'DELETE FROM model_adapter_bindings WHERE namespace=? AND library_id=? '
        'AND kind=? AND asset_id=? AND asset_version=?',
        [store.ns, libraryId, kind, entityId, version],
      );
      store.execute(
        'DELETE FROM library_versions WHERE namespace=? AND library_id=? AND '
        'kind=? AND entity_id=? AND version=?',
        [store.ns, libraryId, kind, entityId, version],
      );
      return RecycleReport(recycled: true, retryable: false, referenceCount: 0);
    });
  }

  int referenceCount({
    required String libraryId,
    required String entityId,
    required String version,
    String kind = _kind,
  }) {
    return _count(
          'SELECT COUNT(*) AS c FROM library_project_pins WHERE namespace=? '
          'AND library_id=? AND kind=? AND entity_id=? AND version=?',
          [store.ns, libraryId, kind, entityId, version],
        ) +
        _count(
          'SELECT COUNT(*) AS c FROM library_export_pins WHERE namespace=? '
          'AND library_id=? AND kind=? AND entity_id=? AND version=?',
          [store.ns, libraryId, kind, entityId, version],
        ) +
        _count(
          'SELECT COUNT(*) AS c FROM library_candidate_pins WHERE namespace=? '
          'AND library_id=? AND kind=? AND entity_id=? AND version=?',
          [store.ns, libraryId, kind, entityId, version],
        );
  }

  void _insertPlan({
    required String planId,
    required String libraryId,
    required String entityId,
    required String version,
    required String kind,
    required String reason,
  }) {
    final exists = store.select(
      'SELECT 1 FROM library_versions WHERE namespace=? AND library_id=? AND '
      'kind=? AND entity_id=? AND version=?',
      [store.ns, libraryId, kind, entityId, version],
    );
    if (exists.isEmpty) {
      throw const StudioException('RESOURCE_MISSING', 'library_versions');
    }
    store.execute(
      'INSERT INTO library_retention_plans(namespace,plan_id,library_id,kind,'
      'entity_id,version,reason) VALUES(?,?,?,?,?,?,?)',
      [store.ns, planId, libraryId, kind, entityId, version, reason],
    );
  }

  void _requireVersion(
    String libraryId,
    String entityId,
    String version,
    String packHash,
  ) {
    final rows = store.select(
      'SELECT body_hash FROM library_versions WHERE namespace=? AND '
      'library_id=? AND kind=? AND entity_id=? AND version=?',
      [store.ns, libraryId, _kind, entityId, version],
    );
    if (rows.isEmpty) {
      throw const StudioException('RESOURCE_MISSING', 'pinnedVersion');
    }
    if (rows.single['body_hash'] != packHash) {
      throw const StudioException('BINDING_MISMATCH', 'packHash');
    }
  }

  int _count(String sql, List<Object?> params) {
    final rows = store.select(sql, params);
    final value = rows.single['c'];
    if (value is int) return value;
    return int.parse('$value');
  }
}
