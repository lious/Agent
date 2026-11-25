part of 'studio_store.dart';

final class ImportedProject {
  ImportedProject(this.project, this.writer);
  final ProjectDocument project;
  final WriterToken writer;
}

extension ResourceImport on DocumentRepository {
  /// All authority and selected-project changes are in one existing transaction.
  /// Byte/native qualifications are a trusted-host SDK responsibility, never SQL.
  ImportedProject createResourceFork({
    required ProjectDocument source,
    required WriterToken activeWriter,
    required String expectedActiveHash,
    required String Function() newId,
  }) => _transaction(() {
    validateWriter(activeWriter);
    final before = read(activeWriter.projectId)!;
    if (before.hash != expectedActiveHash ||
        selectedProjectId != before.projectId) {
      throw const StudioException('REVISION_CONFLICT');
    }
    final ids = <String, String>{};
    final fork = forkLocalProject(
      source,
      namespace,
      newId: newId,
      importIds: ids,
    );
    create(fork);
    final map = {
      'kind': 'ImportMap',
      'version': 1,
      'origin': {
        'namespace': source.namespace.toJson(),
        'projectId': source.projectId,
        'revision': source.revision.toString(),
        'snapshotHash': source.hash,
      },
      'local': {
        'namespace': namespace.toJson(),
        'projectId': fork.projectId,
        'revision': '0',
        'snapshotHash': fork.hash,
      },
      'entityIds': ids,
      'historicalRevisionsMapped': false,
      'sessionsImported': false,
    };
    _db.execute('INSERT INTO import_maps VALUES(?,?,?,?)', [
      _ns,
      fork.projectId,
      jsonEncode(map),
      contentHash(map),
    ]);
    selectProject(fork.projectId);
    final writer = acquireWriter(fork.projectId, newId(), expectedEpoch: 0);
    captureCheckpoint(writer);
    return ImportedProject(fork, writer);
  });

  Map<String, dynamic>? importMap(String projectId) {
    requireId(projectId);
    final rows = _db.select(
      'SELECT json,hash FROM import_maps WHERE ns=? AND project_id=?',
      [_ns, projectId],
    );
    if (rows.isEmpty) return null;
    final map =
        jsonDecode(rows.single['json'] as String) as Map<String, dynamic>;
    if (contentHash(map) != rows.single['hash'] ||
        map['kind'] != 'ImportMap' ||
        map['local']['projectId'] != projectId ||
        contentHash(map['local']['namespace']) !=
            contentHash(namespace.toJson())) {
      throw const StudioException('STORE_INTEGRITY');
    }
    return map;
  }
}
