part of 'studio_store.dart';

String _definitionKey(dynamic kind, dynamic id, dynamic version) =>
    '$kind:$id@$version';

final class _DefinitionValue {
  _DefinitionValue(this.hash, this.raw, {this.kind, this.id, this.version});
  final String hash, raw;
  final String? kind, id, version;
}

// Bounded rebuildable in-memory acceleration ONLY. Existing snapshot anchors and
// immutable bytes remain authority. No SQL migration/hash rewrite/certificate.
final class _DefinitionLedger {
  _DefinitionLedger(this.limit);
  final int limit;
  final values = <String, Map<String, Set<String>>>{};
  int observations = 0;
  bool overflow = false;
  void add(Map<String, _DefinitionValue> proof) {
    if (overflow) return;
    for (final e in proof.entries) {
      final raws = values
          .putIfAbsent(e.key, () => {})
          .putIfAbsent(e.value.hash, () => <String>{});
      if (raws.add(e.value.raw) && ++observations > limit) {
        values.clear();
        overflow =
            true; // Stream candidate-only decisions; never waive the check.
        return;
      }
    }
  }
}

final class _DefinitionMatch {
  String? first;
  bool ambiguous = false, digestKnown = false, rawKnown = false;
  void add(
    _DefinitionValue old,
    _DefinitionValue candidate,
    String? storedRaw,
  ) {
    first ??= old.hash;
    ambiguous |= first != old.hash;
    if (old.hash == candidate.hash) {
      digestKnown = true;
      rawKnown |= old.raw == storedRaw;
    }
  }
}

extension DefinitionHistory on DocumentRepository {
  /// Read-only, transaction-consistent proposed-definition validation. Does not
  /// publish/allocate/edit, authorize media execution or permit historical undo.
  void checkDefinitionCompatibility(ProjectDocument candidate) =>
      _transaction(() {
        if (candidate.namespace != namespace) {
          throw const StudioException('NAMESPACE_MISMATCH');
        }
        final before = read(candidate.projectId);
        if (before == null) throw const StudioException('PROJECT_NOT_FOUND');
        requireLocalEditingWritable(candidate);
        _verifyDefinitionHistory(
          candidate,
          _definitionProof(candidate, _legacyDefinitions(candidate)),
          previous: before,
        );
      });

  Map<String, _DefinitionValue> _definitionProof(
    ProjectDocument p,
    List<Map<String, dynamic>> legacy,
  ) {
    final raw = {
      for (final e in legacy)
        _definitionKey(e['_kind'], e['id'], e['version']):
            e['_legacyHash'] as String,
    };
    final fingerprinter = DefinitionFingerprinter(p, const {});
    fingerprinter.registerSnapshot(p);
    return {
      for (final d in fingerprinter.resolvedDefinitions)
        _definitionKey(d['kind'], d['id'], d['version']): _DefinitionValue(
          d['hash']!,
          raw[_definitionKey(d['kind'], d['id'], d['version'])] ??
              (throw const StudioException('DEFINITION_HISTORY_UNQUALIFIED')),
          kind: d['kind'],
          id: d['id'],
          version: d['version'],
        ),
    };
  }

  // Page immutable *anchored project roots*, never arbitrary/orphan snapshots,
  // another project/namespace or the not-yet-published proposed snapshot.
  void _visitDefinitionHistory(
    String projectId,
    void Function(Map<String, _DefinitionValue>) visit,
  ) {
    var offset = 0;
    while (true) {
      final rows = _db.select(
        '''SELECT hash,rev FROM (
        SELECT snapshot_hash AS hash,revision AS rev FROM project_heads WHERE ns=? AND project_id=?
        UNION SELECT snapshot_hash,revision FROM revisions WHERE ns=? AND project_id=?
        UNION SELECT before_ref,expected_revision FROM commands WHERE ns=? AND project_id=?
        UNION SELECT after_ref,expected_revision+1 FROM commands WHERE ns=? AND project_id=?
      ) ORDER BY hash,rev LIMIT 128 OFFSET ?''',
        [
          _ns,
          projectId,
          _ns,
          projectId,
          _ns,
          projectId,
          _ns,
          projectId,
          offset,
        ],
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        final stored = _db.select(
          'SELECT json FROM snapshots WHERE ns=? AND hash=?',
          [_ns, row['hash']],
        );
        if (stored.length != 1) throw const StudioException('STORE_INTEGRITY');
        final p = ProjectDocument.fromJson(
          jsonDecode(stored.single['json'] as String) as Map<String, dynamic>,
        );
        if (p.hash != row['hash'] ||
            p.namespace != namespace ||
            p.projectId != projectId ||
            p.revision != BigInt.from(row['rev'] as int)) {
          throw const StudioException('STORE_INTEGRITY');
        }
        visit(_definitionProof(p, _legacyDefinitions(p)));
      }
      offset += rows.length;
    }
  }

  Set<String> _verifyDefinitionHistory(
    ProjectDocument candidate,
    Map<String, _DefinitionValue> proof, {
    required ProjectDocument? previous,
    bool restoringHistory = false,
  }) {
    final dataVersion =
        _db.select('PRAGMA data_version').single.values.single as int;
    if (previous == null) {
      // Only create() reaches this branch, after checking no existing project.
      _clearDefinitionHistory();
      _definitionProject = candidate.projectId;
      _definitionDataVersion = dataVersion;
      _definitionLedger = _DefinitionLedger(_definitionHistoryLimit);
      return {};
    }
    if (_definitionProject != candidate.projectId ||
        _definitionDataVersion != dataVersion) {
      _clearDefinitionHistory();
      final ledger = _DefinitionLedger(_definitionHistoryLimit);
      _visitDefinitionHistory(candidate.projectId, ledger.add);
      _definitionProject = candidate.projectId;
      _definitionDataVersion = dataVersion;
      _definitionLedger = ledger;
    }
    final stored = <String, String?>{};
    // Typed IDs/versions come from the already resolved projection. Never split
    // arbitrary IDs at a delimiter or re-resolve the complete candidate twice.
    for (final entry in proof.entries) {
      final d = entry.value;
      final rows = _db.select(
        'SELECT content_hash FROM entity_versions WHERE ns=? AND project_id=? AND entity_id=? AND version=?',
        [_ns, candidate.projectId, d.id, int.parse(d.version!)],
      );
      stored[entry.key] = rows.isEmpty
          ? null
          : rows.single['content_hash'] as String;
    }
    final matches = {for (final key in proof.keys) key: _DefinitionMatch()};
    final ledger = _definitionLedger!;
    if (ledger.overflow) {
      _visitDefinitionHistory(candidate.projectId, (old) {
        for (final e in proof.entries) {
          final value = old[e.key];
          if (value != null) matches[e.key]!.add(value, e.value, stored[e.key]);
        }
      });
    } else {
      for (final e in proof.entries) {
        for (final old
            in (ledger.values[e.key] ?? const <String, Set<String>>{})
                .entries) {
          for (final raw in old.value) {
            matches[e.key]!.add(
              _DefinitionValue(old.key, raw),
              e.value,
              stored[e.key],
            );
          }
        }
      }
    }
    final before = _definitionProof(previous, _legacyDefinitions(previous)),
        compatible = <String>{};
    for (final e in proof.entries) {
      final m = matches[e.key]!, raw = stored[e.key];
      if (m.first == null) {
        if (raw != null) {
          throw const StudioException('DEFINITION_HISTORY_UNQUALIFIED');
        }
        continue; // Fresh version, not grandfathered from a raw hash match.
      }
      if (raw == null) throw const StudioException('STORE_INTEGRITY');
      if (!m.digestKnown ||
          (m.ambiguous &&
              !restoringHistory &&
              before[e.key]?.hash != e.value.hash)) {
        throw const StudioException('IMMUTABLE_VERSION_CONFLICT');
      }
      // Recognize actual historical raw hashes for *this* resolved identity;
      // never reinterpret an unknown/corrupt old row as the new profile.
      if (!m.rawKnown) throw const StudioException('STORE_INTEGRITY');
      compatible.add(e.key);
    }
    return compatible;
  }
}
