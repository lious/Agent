import 'dart:convert';
import 'dart:io';

import 'package:studio_contracts/studio_contracts.dart';

import 'library_store.dart';
import 'portrait_rights.dart';

/// Official 8E revocation coordinator.
///
/// [revoke] writes a live AccessRecord, advances the epoch, invalidates
/// derived semantic caches, and requests cancel of in-flight candidate
/// tasks. Already-ready pins are isolated at revoke time. A result that
/// arrives or completes after revoke is isolated by
/// [arriveCandidateResult] and is not accepted as a normal ready output.
/// Existing user output files are classified by [existingOutputsPolicy]
/// and are never deleted here.
final class PortraitRevocationCoordinator {
  PortraitRevocationCoordinator({
    required this.store,
    required this.cache,
    required this.generations,
  });

  final CharacterLibraryStore store;
  final CharacterDerivedCache cache;
  final CharacterGenerationLedger generations;

  RevocationReport revoke(String rightsId, String expectedEpoch) {
    requireId(rightsId);
    return store.transaction(() {
      final live = _live(rightsId);
      if (live == null) {
        throw const StudioException('RESOURCE_MISSING', 'rightsId');
      }
      if (live['epoch'] != expectedEpoch) {
        throw const StudioException('HEAD_CONFLICT', 'epoch');
      }
      final nextEpoch = _incrementU64(expectedEpoch);
      cache.invalidateRights(rightsId);
      cache.resetCounters();
      generations.reset();
      store.execute(
        'UPDATE portrait_rights_live SET epoch=?, state=? WHERE namespace=? '
        'AND rights_id=?',
        [nextEpoch, 'revoked', store.ns, rightsId],
      );
      _recordDenylist(rightsId, nextEpoch);
      final cancelled = _transitionCandidates(
        rightsId,
        from: 'processing',
        to: 'cancelled',
      );
      final isolated = _transitionCandidates(
        rightsId,
        from: 'ready',
        to: 'isolated',
      );
      final policy = existingOutputsPolicy(rightsId);
      return RevocationReport(
        rightsId: rightsId,
        epoch: nextEpoch,
        state: 'revoked',
        newGenerations: generations.dispatched,
        cacheHits: cache.hits,
        existingOutputsPolicy: policy,
        cancelledTasks: cancelled,
        isolatedTasks: isolated,
      );
    });
  }

  /// Arrival/completion gate for a candidate-task result.
  ///
  /// If the task's rightsId is already revoked, or the pin was cancelled
  /// at revoke time, the arriving result is moved to [isolated] and is
  /// not accepted as a normal ready output. User files on disk are not
  /// deleted. A still-authorized processing task may complete as ready.
  CandidateArrivalReport arriveCandidateResult({
    required String taskId,
    String? outputPath,
    String? outputId,
  }) {
    requireId(taskId);
    return store.transaction(() {
      final rows = store.select(
        'SELECT task_id, library_id, kind, entity_id, version, pack_hash, '
        'state FROM library_candidate_pins WHERE namespace=? AND task_id=?',
        [store.ns, taskId],
      );
      if (rows.isEmpty) {
        throw const StudioException('RESOURCE_MISSING', 'taskId');
      }
      final pin = Map<String, Object?>.from(rows.single);
      final packHash = pin['pack_hash'] as String;
      final rightsId = _rightsIdOfPack(packHash);
      final current = pin['state'] as String;
      final revoked = isKnownRevoked(rightsId: rightsId, packHash: packHash);
      final mustIsolate =
          revoked || current == 'cancelled' || current == 'isolated';
      if (mustIsolate) {
        if (current != 'isolated') {
          store.execute(
            'UPDATE library_candidate_pins SET state=? WHERE namespace=? AND '
            'task_id=?',
            ['isolated', store.ns, taskId],
          );
        }
        return CandidateArrivalReport(
          taskId: taskId,
          state: 'isolated',
          isolated: true,
          outputAccepted: false,
          code: revoked ? 'RIGHTS_REVOKED' : 'CANDIDATE_ISOLATED',
          rightsId: rightsId,
        );
      }
      if (current == 'processing') {
        store.execute(
          'UPDATE library_candidate_pins SET state=? WHERE namespace=? AND '
          'task_id=?',
          ['ready', store.ns, taskId],
        );
      }
      if (outputPath != null) {
        recordOutput(
          ExistingOutputRecord(
            outputId: outputId ?? 'out-$taskId',
            rightsId: rightsId,
            path: outputPath,
          ),
        );
      }
      return CandidateArrivalReport(
        taskId: taskId,
        state: 'ready',
        isolated: false,
        outputAccepted: true,
        rightsId: rightsId,
      );
    });
  }

  bool isKnownRevoked({
    String? rightsId,
    String? packHash,
    String? evidenceHash,
    String? sourceRightsId,
  }) {
    if (rightsId != null) {
      final live = _live(rightsId);
      if (live != null && live['state'] == 'revoked') {
        return true;
      }
      final byId = store.select(
        'SELECT 1 FROM portrait_revocation_denylist WHERE namespace=? AND '
        '(rights_id=? OR source_rights_id=?) LIMIT 1',
        [store.ns, rightsId, rightsId],
      );
      if (byId.isNotEmpty) return true;
    }
    if (packHash != null) {
      final rows = store.select(
        'SELECT 1 FROM portrait_revocation_denylist WHERE namespace=? AND '
        'pack_hash=? LIMIT 1',
        [store.ns, packHash],
      );
      if (rows.isNotEmpty) return true;
    }
    if (evidenceHash != null && evidenceHash.isNotEmpty) {
      final rows = store.select(
        'SELECT 1 FROM portrait_revocation_denylist WHERE namespace=? AND '
        'evidence_hash=? LIMIT 1',
        [store.ns, evidenceHash],
      );
      if (rows.isNotEmpty) return true;
    }
    if (sourceRightsId != null) {
      final rows = store.select(
        'SELECT 1 FROM portrait_revocation_denylist WHERE namespace=? AND '
        '(rights_id=? OR source_rights_id=?) LIMIT 1',
        [store.ns, sourceRightsId, sourceRightsId],
      );
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  void recordDenylistEntry({
    required String rightsId,
    required String packHash,
    required String evidenceHash,
    required String sourceRightsId,
    required String epoch,
  }) {
    store.execute(
      'INSERT OR IGNORE INTO portrait_revocation_denylist(namespace,rights_id,'
      'pack_hash,evidence_hash,source_rights_id,epoch) VALUES(?,?,?,?,?,?)',
      [store.ns, rightsId, packHash, evidenceHash, sourceRightsId, epoch],
    );
  }

  void recordOutput(ExistingOutputRecord output) {
    requireId(output.outputId);
    requireId(output.rightsId);
    store.execute(
      'INSERT INTO character_existing_outputs(namespace,output_id,rights_id,'
      'path,body_hash) VALUES(?,?,?,?,?)',
      [
        store.ns,
        output.outputId,
        output.rightsId,
        output.path,
        output.bodyHash,
      ],
    );
  }

  ExistingOutputsDisposition existingOutputs(String rightsId) {
    final policy = existingOutputsPolicy(rightsId);
    final rows = store.select(
      'SELECT output_id, path, body_hash FROM character_existing_outputs '
      'WHERE namespace=? AND rights_id=?',
      [store.ns, rightsId],
    );
    final outputs = <ExistingOutputUse>[];
    for (final row in rows) {
      final path = row['path'] as String;
      outputs.add(
        ExistingOutputUse(
          outputId: row['output_id'] as String,
          path: path,
          disposition: policy,
          fileRetained: File(path).existsSync(),
        ),
      );
    }
    return ExistingOutputsDisposition(
      policy: policy,
      outputs: outputs,
      deletedAny: false,
    );
  }

  /// Classify use of an existing output. Never deletes the file.
  ExistingOutputUse useExistingOutput(String outputId) {
    final rows = store.select(
      'SELECT output_id, rights_id, path FROM character_existing_outputs '
      'WHERE namespace=? AND output_id=?',
      [store.ns, outputId],
    );
    if (rows.isEmpty) {
      throw const StudioException('RESOURCE_MISSING', 'outputId');
    }
    final row = rows.single;
    final path = row['path'] as String;
    final rightsId = row['rights_id'] as String;
    final live = _live(rightsId);
    final policy = existingOutputsPolicy(rightsId);
    final revoked = live != null && live['state'] == 'revoked';
    final disposition = revoked ? policy : existingOutputsRetainAllowed;
    final use = ExistingOutputUse(
      outputId: outputId,
      path: path,
      disposition: disposition,
      fileRetained: File(path).existsSync(),
    );
    if (revoked && policy == existingOutputsBlockUse) {
      throw StudioException('RIGHTS_OUTPUT_BLOCKED', outputId);
    }
    if (revoked && policy == existingOutputsReviewRequired) {
      throw StudioException('RIGHTS_OUTPUT_REVIEW_REQUIRED', outputId);
    }
    return use;
  }

  String existingOutputsPolicy(String rightsId) {
    final versions = store.select(
      'SELECT version, body_hash FROM portrait_rights_versions WHERE '
      'namespace=? AND rights_id=? ORDER BY length(version), version',
      [store.ns, rightsId],
    );
    if (versions.isEmpty) {
      throw const StudioException('RESOURCE_MISSING', 'rightsId');
    }
    final body = jsonDecode(
      utf8.decode(store.readCas(versions.last['body_hash'] as String)),
    ) as Map;
    return body['existingOutputsPolicy'] as String;
  }

  void _recordDenylist(String rightsId, String epoch) {
    final versions = store.select(
      'SELECT body_hash FROM library_versions WHERE namespace=? AND kind=?',
      [store.ns, 'character'],
    );
    var recorded = false;
    for (final row in versions) {
      final hash = row['body_hash'] as String;
      final pack =
          jsonDecode(utf8.decode(store.readCas(hash))) as Map<String, dynamic>;
      final asset = Map<String, Object?>.from(pack['asset'] as Map);
      if (asset['portraitRightsId'] != rightsId) continue;
      for (final item in (pack['rights'] as List)) {
        final record = Map<String, Object?>.from(item as Map);
        if (record['id'] != rightsId) continue;
        final evidence = (record['evidenceHash'] as String?) ?? 'none';
        recordDenylistEntry(
          rightsId: rightsId,
          packHash: hash,
          evidenceHash: evidence,
          sourceRightsId: rightsId,
          epoch: epoch,
        );
        recorded = true;
      }
    }
    if (!recorded) {
      recordDenylistEntry(
        rightsId: rightsId,
        packHash: 'sha256:${'0' * 64}',
        evidenceHash: 'none',
        sourceRightsId: rightsId,
        epoch: epoch,
      );
    }
  }

  int _transitionCandidates(
    String rightsId, {
    required String from,
    required String to,
  }) {
    final pins = store.select(
      'SELECT task_id, pack_hash FROM library_candidate_pins '
      'WHERE namespace=? AND state=?',
      [store.ns, from],
    );
    var count = 0;
    for (final pin in pins) {
      final packHash = pin['pack_hash'] as String;
      if (!_packUsesRights(packHash, rightsId)) continue;
      store.execute(
        'UPDATE library_candidate_pins SET state=? WHERE namespace=? AND '
        'task_id=?',
        [to, store.ns, pin['task_id']],
      );
      count++;
    }
    return count;
  }

  bool _packUsesRights(String packHash, String rightsId) {
    if (!store.hasCas(packHash)) return false;
    return _rightsIdOfPack(packHash) == rightsId;
  }

  String _rightsIdOfPack(String packHash) {
    if (!store.hasCas(packHash)) {
      throw const StudioException('RESOURCE_MISSING', 'packHash');
    }
    final pack = jsonDecode(
      utf8.decode(store.readCas(packHash)),
    ) as Map<String, dynamic>;
    final asset = Map<String, Object?>.from(pack['asset'] as Map);
    final rightsId = asset['portraitRightsId'] as String?;
    if (rightsId == null || rightsId.isEmpty) {
      throw const StudioException('RESOURCE_MISSING', 'portraitRightsId');
    }
    return rightsId;
  }

  Map<String, Object?>? _live(String rightsId) {
    final rows = store.select(
      'SELECT rights_id, epoch, state, checked_at, lease_until '
      'FROM portrait_rights_live WHERE namespace=? AND rights_id=?',
      [store.ns, rightsId],
    );
    if (rows.isEmpty) return null;
    return Map<String, Object?>.from(rows.single);
  }

  String _incrementU64(String value) =>
      (BigInt.parse(value) + BigInt.one).toString();
}
