part of 'studio_store.dart';

/// Rebuildable cursor over immutable committed commands, never an in-memory truth.
final class CommandHistoryCursor {
  const CommandHistoryCursor(
    this.undoCommandId,
    this.redoUndoCommandId,
    this.undoDepth,
    this.redoDepth,
  );
  final String? undoCommandId, redoUndoCommandId;
  final int undoDepth, redoDepth;
}

extension CommandHistory on DocumentRepository {
  CommandHistoryCursor commandHistory(String projectId) {
    requireId(projectId);
    // One SQL statement: head and journal see the SAME SQLite read snapshot,
    // including outside a writer transaction. No read path acquires a writer.
    final rows = _db.select(
      """
      SELECT h.revision AS head_revision,h.snapshot_hash AS head_hash,
       r.revision,r.parent_revision,r.snapshot_hash,c.id,c.expected_revision,
       c.before_ref,c.after_ref,c.payload_json,c.input_hash
      FROM project_heads h LEFT JOIN revisions r
       ON r.ns=h.ns AND r.project_id=h.project_id
      LEFT JOIN commands c ON c.ns=r.ns AND c.id=r.command_id
       AND c.project_id=h.project_id
      WHERE h.ns=? AND h.project_id=? ORDER BY r.revision
    """,
      [_ns, projectId],
    );
    if (rows.isEmpty) throw const StudioException('PROJECT_NOT_FOUND');
    final undo = <String>[], redo = <({String target, String undoId})>[];
    var revision = 0;
    String? lastHash;
    for (final row in rows) {
      if (row['revision'] == null) continue;
      if (row['revision'] != revision + 1 ||
          row['parent_revision'] != revision ||
          row['expected_revision'] != revision ||
          row['id'] is! String ||
          row['snapshot_hash'] != row['after_ref'] ||
          (lastHash != null && row['before_ref'] != lastHash)) {
        throw const StudioException('HISTORY_INTEGRITY');
      }
      dynamic payload;
      try {
        payload = jsonDecode(row['payload_json'] as String);
      } on FormatException {
        throw const StudioException('HISTORY_FORMAT_UNSUPPORTED');
      }
      if (payload is! Map<String, dynamic> ||
          payload['kind'] is! String ||
          row['input_hash'] !=
              contentHash({
                'projectId': projectId,
                'commandId': row['id'],
                'expectedRevision': revision.toString(),
                'payload': payload,
              })) {
        throw const StudioException('HISTORY_INTEGRITY');
      }
      final id = row['id'] as String;
      if (payload['kind'] == 'undo') {
        if (payload.length != 3 ||
            payload['historyVersion'] != 1 ||
            undo.isEmpty ||
            undo.last != payload['targetCommandId']) {
          throw const StudioException('HISTORY_FORMAT_UNSUPPORTED');
        }
        redo.add((target: undo.removeLast(), undoId: id));
      } else if (payload['kind'] == 'redo') {
        if (payload.length != 3 ||
            payload['historyVersion'] != 1 ||
            redo.isEmpty ||
            redo.last.undoId != payload['undoCommandId']) {
          throw const StudioException('HISTORY_FORMAT_UNSUPPORTED');
        }
        undo.add(redo.removeLast().target);
      } else {
        // Legacy undoLatest is a real historical restore transition. Preserve it
        // as an undoable chronological command, NOT a fabricated modern cursor.
        undo.add(id);
        redo.clear();
      }
      revision++;
      lastHash = row['after_ref'] as String;
    }
    if (revision != rows.first['head_revision'] ||
        (lastHash != null && lastHash != rows.first['head_hash'])) {
      throw const StudioException('HISTORY_INTEGRITY');
    }
    return CommandHistoryCursor(
      undo.lastOrNull,
      redo.lastOrNull?.undoId,
      undo.length,
      redo.length,
    );
  }

  CommitReceipt undoCommand({
    required WriterToken writer,
    required String commandId,
    required String receiptKey,
    required BigInt expectedRevision,
    required String targetCommandId,
  }) => _commit(writer, commandId, receiptKey, expectedRevision, {
    'kind': 'undo',
    'historyVersion': 1,
    'targetCommandId': targetCommandId,
  });

  CommitReceipt redoCommand({
    required WriterToken writer,
    required String commandId,
    required String receiptKey,
    required BigInt expectedRevision,
    required String undoCommandId,
  }) => _commit(writer, commandId, receiptKey, expectedRevision, {
    'kind': 'redo',
    'historyVersion': 1,
    'undoCommandId': undoCommandId,
  });

  ProjectDocument _restoreCommandHistory(
    ProjectDocument before,
    Map<String, Object?> payload,
  ) {
    final cursor = commandHistory(before.projectId);
    final isUndo = payload['kind'] == 'undo';
    final requested = payload[isUndo ? 'targetCommandId' : 'undoCommandId'];
    if (requested is! String) throw const StudioException('UNDO_CONFLICT');
    requireId(requested);
    final expected = isUndo ? cursor.undoCommandId : cursor.redoUndoCommandId;
    if (expected == null || requested != expected) {
      throw const StudioException('UNDO_CONFLICT');
    }
    // Redo restores the saved before-image of the undo, not a re-execution of
    // the original command/model/transcode. This also preserves legacy versions.
    final row = _db.select(
      'SELECT * FROM commands WHERE ns=? AND project_id=? AND id=?',
      [_ns, before.projectId, requested],
    ).single;
    ProjectDocument image(String column, int revision) {
      final ref = row[column];
      final rows = _db.select(
        'SELECT json FROM snapshots WHERE ns=? AND hash=?',
        [_ns, ref],
      );
      if (rows.length != 1) throw const StudioException('STORE_INTEGRITY');
      final p = ProjectDocument.fromJson(
        jsonDecode(rows.single['json'] as String) as Map<String, dynamic>,
      );
      if (p.hash != ref ||
          p.namespace != namespace ||
          p.projectId != before.projectId ||
          p.revision != BigInt.from(revision)) {
        throw const StudioException('STORE_INTEGRITY');
      }
      requireLocalEditingWritable(p);
      return p;
    }

    final revision = row['expected_revision'] as int;
    final savedBefore = image('before_ref', revision);
    final savedAfter = image('after_ref', revision + 1);
    String contents(ProjectDocument p) =>
        contentHash(p.toJson()..remove('revision'));
    if (contents(before) != contents(savedAfter)) {
      throw const StudioException('UNDO_CONFLICT');
    }
    return savedBefore.withTitle(savedBefore.title, before.revision);
  }

  /// Named field-aware invert of a prior command that is not the undo tip.
  /// Restores only that command's content fields when they still match the
  /// command's after-image; a later edit to any of those fields, or a tip
  /// target, is whole-group UNDO_CONFLICT and does not roll the database back.
  /// Linear [undoCommand]/[redoCommand] stay snapshot restores of the tip.
  CommitReceipt invertCommand({
    required WriterToken writer,
    required String commandId,
    required String receiptKey,
    required BigInt expectedRevision,
    required String targetCommandId,
  }) => _commit(writer, commandId, receiptKey, expectedRevision, {
    'kind': 'invertCommand',
    'historyVersion': 1,
    'targetCommandId': targetCommandId,
  });

  /// Chronological committed commands, including undo/redo/invert rows.
  List<Map<String, String>> listCommands(String projectId) {
    requireId(projectId);
    final rows = _db.select(
      """
        SELECT r.revision,c.id,c.payload_json
        FROM project_heads h
        JOIN revisions r ON r.ns=h.ns AND r.project_id=h.project_id
        JOIN commands c ON c.ns=r.ns AND c.id=r.command_id AND c.project_id=h.project_id
        WHERE h.ns=? AND h.project_id=?
        ORDER BY r.revision
      """,
      [_ns, projectId],
    );
    final out = <Map<String, String>>[];
    for (final row in rows) {
      final payload = jsonDecode(row['payload_json'] as String);
      if (payload is! Map || payload['kind'] is! String) {
        throw const StudioException('HISTORY_FORMAT_UNSUPPORTED');
      }
      out.add({
        'id': row['id'] as String,
        'kind': payload['kind'] as String,
        'revision': (row['revision'] as int).toString(),
      });
    }
    return out;
  }

  ProjectDocument _invertCommand(
    ProjectDocument current,
    Map<String, Object?> payload,
  ) {
    if (payload['historyVersion'] != 1 ||
        payload['targetCommandId'] is! String ||
        payload.length != 3) {
      throw const StudioException('HISTORY_FORMAT_UNSUPPORTED');
    }
    final targetId = payload['targetCommandId'] as String;
    requireId(targetId);
    final cursor = commandHistory(current.projectId);
    if (cursor.undoCommandId == null || cursor.undoCommandId == targetId) {
      throw const StudioException('UNDO_CONFLICT');
    }
    final row = _db.select(
      'SELECT * FROM commands WHERE ns=? AND project_id=? AND id=?',
      [_ns, current.projectId, targetId],
    );
    if (row.length != 1) {
      throw const StudioException('UNDO_CONFLICT');
    }
    dynamic targetPayload;
    try {
      targetPayload = jsonDecode(row.single['payload_json'] as String);
    } on FormatException {
      throw const StudioException('HISTORY_FORMAT_UNSUPPORTED');
    }
    if (targetPayload is! Map ||
        targetPayload['kind'] is! String ||
        targetPayload['kind'] == 'undo' ||
        targetPayload['kind'] == 'redo' ||
        targetPayload['kind'] == 'undoLatest' ||
        targetPayload['kind'] == 'invertCommand') {
      throw const StudioException('UNDO_CONFLICT');
    }
    ProjectDocument image(String column, int revision) {
      final ref = row.single[column];
      final rows = _db.select(
        'SELECT json FROM snapshots WHERE ns=? AND hash=?',
        [_ns, ref],
      );
      if (rows.length != 1) throw const StudioException('STORE_INTEGRITY');
      final p = ProjectDocument.fromJson(
        jsonDecode(rows.single['json'] as String) as Map<String, dynamic>,
      );
      if (p.hash != ref ||
          p.namespace != namespace ||
          p.projectId != current.projectId ||
          p.revision != BigInt.from(revision)) {
        throw const StudioException('STORE_INTEGRITY');
      }
      return p;
    }

    final revision = row.single['expected_revision'] as int;
    final savedBefore = image('before_ref', revision);
    final savedAfter = image('after_ref', revision + 1);
    final changes = documentFieldChanges(
      savedBefore.toJson(),
      savedAfter.toJson(),
    );
    if (changes.isEmpty) {
      throw const StudioException('UNDO_CONFLICT');
    }
    if (fieldInvertConflicts(current.toJson(), changes)) {
      throw const StudioException('UNDO_CONFLICT');
    }
    var next = applyFieldInvert(current.toJson(), changes);
    String bump(String id) {
      final max =
          _db.select(
                'SELECT max(version) AS version FROM entity_versions WHERE ns=? AND project_id=? AND entity_id=?',
                [_ns, current.projectId, id],
              ).single['version']
              as int?;
      final value = BigInt.from(max ?? 0) + BigInt.one;
      if (value > maxI64) throw const StudioException('VERSION_OVERFLOW');
      return value.toString();
    }

    // Source refs share an asset id and version but are not the asset entity.
    // Indexing them would overwrite the asset and can bump clip source.version.
    bool isVersionedEntity(dynamic value) =>
        value is Map &&
        value['id'] is String &&
        value.containsKey('version') &&
        value['streamId'] == null;

    Map<String, Map<String, dynamic>> index(dynamic node) {
      final out = <String, Map<String, dynamic>>{};
      void walk(dynamic value) {
        if (value is Map) {
          if (isVersionedEntity(value)) {
            out[value['id'] as String] = Map<String, dynamic>.from(value);
          }
          for (final child in value.values) {
            walk(child);
          }
        } else if (value is List) {
          for (final child in value) {
            walk(child);
          }
        }
      }

      walk(node);
      return out;
    }

    dynamic stripClocks(dynamic node) {
      if (node is Map) {
        return {
          for (final e in node.entries)
            if (e.key != 'version' && e.key != 'revision')
              e.key: stripClocks(e.value),
        };
      }
      if (node is List) {
        return [for (final e in node) stripClocks(e)];
      }
      return node;
    }

    String clocksOff(dynamic node) => contentHash(stripClocks(node));
    final beforeIndex = index(current.toJson());
    final afterIndex = index(next);
    final bumpIds = <String>{};
    for (final e in afterIndex.entries) {
      final previous = beforeIndex[e.key];
      if (previous == null || clocksOff(previous) != clocksOff(e.value)) {
        bumpIds.add(e.key);
      }
    }
    // Sequence fingerprints already close captions and transitions that live
    // outside the sequence object. Invert must mint a new sequence version
    // when those children change, same as later marker or caption text edits.
    if (clocksOff(current.toJson()['captions']) !=
            clocksOff(next['captions']) ||
        clocksOff(current.toJson()['markers']) != clocksOff(next['markers']) ||
        clocksOff(current.toJson()['transitions']) !=
            clocksOff(next['transitions'])) {
      for (final sequence in next['sequences'] as List) {
        if (sequence is Map && sequence['id'] is String) {
          bumpIds.add(sequence['id'] as String);
        }
      }
    }
    final allocated = <String, String>{};
    void bumpIn(dynamic node) {
      if (node is Map) {
        if (isVersionedEntity(node) && bumpIds.contains(node['id'])) {
          node['version'] = allocated.putIfAbsent(
            node['id'] as String,
            () => bump(node['id'] as String),
          );
        }
        for (final value in node.values) {
          bumpIn(value);
        }
      } else if (node is List) {
        for (final value in node) {
          bumpIn(value);
        }
      }
    }

    bumpIn(next);
    final result = ProjectDocument.fromJson(next);
    requireLocalEditingWritable(result);
    return result.withTitle(result.title, current.revision);
  }
}
