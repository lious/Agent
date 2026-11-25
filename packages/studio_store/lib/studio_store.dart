import 'package:uuid/uuid.dart' show Uuid;

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
export 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/builtin_compute.dart';
part 'persistence.dart';
part 'harness_persistence.dart';
part 'peer_authority.dart';

const _ddl = '''
CREATE TABLE schema_migrations(version INTEGER PRIMARY KEY, checksum TEXT NOT NULL);
CREATE TABLE snapshots(ns TEXT NOT NULL, hash TEXT NOT NULL, json TEXT NOT NULL,
 PRIMARY KEY(ns,hash));
CREATE TABLE project_heads(ns TEXT NOT NULL,project_id TEXT NOT NULL,
 revision INTEGER NOT NULL CHECK(revision>=0), snapshot_hash TEXT NOT NULL,
 owner TEXT, fence INTEGER NOT NULL DEFAULT 0 CHECK(fence>=0),
 PRIMARY KEY(ns,project_id), FOREIGN KEY(ns,snapshot_hash) REFERENCES snapshots(ns,hash));
CREATE TABLE commands(ns TEXT NOT NULL,id TEXT NOT NULL,project_id TEXT NOT NULL,
 input_hash TEXT NOT NULL,expected_revision INTEGER NOT NULL,
 before_ref TEXT NOT NULL,after_ref TEXT NOT NULL,inverse_ref TEXT NOT NULL,
 payload_json TEXT NOT NULL,PRIMARY KEY(ns,id),
 FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id),
 FOREIGN KEY(ns,before_ref) REFERENCES snapshots(ns,hash),
 FOREIGN KEY(ns,after_ref) REFERENCES snapshots(ns,hash),
 FOREIGN KEY(ns,inverse_ref) REFERENCES snapshots(ns,hash));
CREATE TABLE revisions(ns TEXT NOT NULL,project_id TEXT NOT NULL,revision INTEGER NOT NULL CHECK(revision>0),
 parent_revision INTEGER NOT NULL,snapshot_hash TEXT NOT NULL,command_id TEXT NOT NULL,
 PRIMARY KEY(ns,project_id,revision),UNIQUE(ns,command_id),
 FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id),
 FOREIGN KEY(ns,command_id) REFERENCES commands(ns,id),
 FOREIGN KEY(ns,snapshot_hash) REFERENCES snapshots(ns,hash));
CREATE TABLE receipts(ns TEXT NOT NULL,receipt_key TEXT NOT NULL,command_id TEXT NOT NULL,
 input_hash TEXT NOT NULL,result_json TEXT NOT NULL,
 PRIMARY KEY(ns,receipt_key),UNIQUE(ns,command_id));
CREATE TABLE stream_heads(ns TEXT NOT NULL,project_id TEXT NOT NULL,next_seq INTEGER NOT NULL CHECK(next_seq>0),
 PRIMARY KEY(ns,project_id),FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id));
CREATE TABLE events(ns TEXT NOT NULL,project_id TEXT NOT NULL,seq INTEGER NOT NULL CHECK(seq>0),
 command_id TEXT NOT NULL,payload_ref TEXT NOT NULL,PRIMARY KEY(ns,project_id,seq),UNIQUE(ns,command_id),
 FOREIGN KEY(ns,project_id) REFERENCES stream_heads(ns,project_id));
CREATE TABLE outbox(ns TEXT NOT NULL,id TEXT NOT NULL,kind TEXT NOT NULL,intent_ref TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state='pending'),PRIMARY KEY(ns,id),
 FOREIGN KEY(ns,intent_ref) REFERENCES snapshots(ns,hash));
CREATE TABLE entity_versions(ns TEXT NOT NULL,project_id TEXT NOT NULL,entity_id TEXT NOT NULL,
 version INTEGER NOT NULL CHECK(version>=0),content_hash TEXT NOT NULL,
 PRIMARY KEY(ns,project_id,entity_id,version),
 FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id));
CREATE TABLE sessions(ns TEXT NOT NULL,id TEXT NOT NULL,title TEXT NOT NULL,PRIMARY KEY(ns,id));
CREATE TABLE immutable_blobs(ns TEXT NOT NULL,hash TEXT NOT NULL,bytes BLOB NOT NULL,PRIMARY KEY(ns,hash));
''';
const _ddl2 = '''
CREATE TABLE project_preferences(ns TEXT PRIMARY KEY,project_id TEXT NOT NULL,
 FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id));
CREATE TABLE blob_edges(ns TEXT NOT NULL,project_id TEXT NOT NULL,revision INTEGER NOT NULL,
 blob_hash TEXT NOT NULL,PRIMARY KEY(ns,project_id,revision,blob_hash),
 FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id));
''';

const _ddl3 = """
CREATE TABLE checkpoints(ns TEXT NOT NULL,id TEXT NOT NULL,project_id TEXT NOT NULL,revision INTEGER NOT NULL,snapshot_hash TEXT NOT NULL,
 PRIMARY KEY(ns,id),UNIQUE(ns,project_id,snapshot_hash),FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id),FOREIGN KEY(ns,snapshot_hash) REFERENCES snapshots(ns,hash));
CREATE TABLE checkpoint_pointers(ns TEXT NOT NULL,project_id TEXT NOT NULL,checkpoint_id TEXT NOT NULL,PRIMARY KEY(ns,project_id),FOREIGN KEY(ns,checkpoint_id) REFERENCES checkpoints(ns,id));
CREATE TABLE save_operations(ns TEXT NOT NULL,id TEXT NOT NULL,checkpoint_id TEXT NOT NULL,target_path TEXT,stage_path TEXT,old_hash TEXT,new_hash TEXT,
 explicit INTEGER NOT NULL CHECK(explicit IN (0,1)),state TEXT NOT NULL CHECK(state IN ('preparing','publishing','committed','failed','cancelled','uncertain')),error TEXT,
 PRIMARY KEY(ns,id),FOREIGN KEY(ns,checkpoint_id) REFERENCES checkpoints(ns,id));
CREATE TABLE save_receipts(seq INTEGER PRIMARY KEY AUTOINCREMENT,ns TEXT NOT NULL,operation_id TEXT NOT NULL,checkpoint_id TEXT NOT NULL,artifact_hash TEXT NOT NULL,
 UNIQUE(ns,operation_id),FOREIGN KEY(ns,operation_id) REFERENCES save_operations(ns,id),FOREIGN KEY(ns,checkpoint_id) REFERENCES checkpoints(ns,id));
""";

const _ddl4 = """
CREATE TABLE harness_plans(ns TEXT NOT NULL,session_id TEXT NOT NULL,plan_hash TEXT NOT NULL,project_id TEXT NOT NULL,json TEXT NOT NULL,started_ms INTEGER NOT NULL,last_ms INTEGER NOT NULL,boot TEXT NOT NULL,
 PRIMARY KEY(ns,session_id,plan_hash),FOREIGN KEY(ns,project_id) REFERENCES project_heads(ns,project_id));
CREATE TABLE harness_steps(ns TEXT NOT NULL,session_id TEXT NOT NULL,plan_hash TEXT NOT NULL,node_id TEXT NOT NULL,attempt INTEGER NOT NULL,state_json TEXT NOT NULL,
 PRIMARY KEY(ns,session_id,plan_hash,node_id),FOREIGN KEY(ns,session_id,plan_hash) REFERENCES harness_plans(ns,session_id,plan_hash));
CREATE TABLE harness_outbox(ns TEXT NOT NULL,id TEXT NOT NULL,session_id TEXT NOT NULL,plan_hash TEXT NOT NULL,node_id TEXT NOT NULL,kind TEXT NOT NULL,payload_json TEXT NOT NULL,
 PRIMARY KEY(ns,id),FOREIGN KEY(ns,session_id,plan_hash) REFERENCES harness_plans(ns,session_id,plan_hash));
""";

const _ddl5 = r"""
ALTER TABLE harness_steps ADD COLUMN attempt_deadline_ms INTEGER NOT NULL DEFAULT 0;
UPDATE harness_steps SET attempt_deadline_ms=CAST(json_extract(state_json,'$.lease.untilMs') AS INTEGER);
CREATE TABLE harness_takeovers(ns TEXT NOT NULL,session_id TEXT NOT NULL,plan_hash TEXT NOT NULL,id TEXT NOT NULL,input_hash TEXT NOT NULL,old_boot TEXT NOT NULL,new_boot TEXT NOT NULL,charged_ms INTEGER NOT NULL,PRIMARY KEY(ns,session_id,plan_hash,id));
CREATE TABLE harness_quarantine(ns TEXT NOT NULL,device_id TEXT NOT NULL,boot TEXT NOT NULL,until_ms INTEGER NOT NULL,PRIMARY KEY(ns,device_id,boot));
CREATE TABLE peer_clock(ns TEXT PRIMARY KEY,last_ms INTEGER NOT NULL);
CREATE TABLE peer_offers(ns TEXT NOT NULL,id TEXT NOT NULL,json TEXT NOT NULL,expires_ms INTEGER NOT NULL,used INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(ns,id));
CREATE TABLE peer_grants(ns TEXT NOT NULL,fingerprint TEXT NOT NULL,session_id TEXT NOT NULL,plan_hash TEXT NOT NULL,epoch INTEGER NOT NULL,json TEXT NOT NULL,revoked INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(ns,fingerprint,session_id,plan_hash));
CREATE TABLE peer_requests(ns TEXT NOT NULL,fingerprint TEXT NOT NULL,session_id TEXT NOT NULL,plan_hash TEXT NOT NULL,epoch INTEGER NOT NULL,id TEXT NOT NULL,input_hash TEXT NOT NULL,response_json TEXT NOT NULL,PRIMARY KEY(ns,fingerprint,session_id,plan_hash,epoch,id));
CREATE TABLE peer_task_bindings(ns TEXT NOT NULL,session_id TEXT NOT NULL,plan_hash TEXT NOT NULL,node_id TEXT NOT NULL,fence TEXT NOT NULL,fingerprint TEXT NOT NULL,epoch INTEGER NOT NULL,PRIMARY KEY(ns,session_id,plan_hash,node_id,fence));
""";

const approvedSqliteVersion = '3.54.1';
const approvedSqliteSourceId =
    '2026-10-16 14:45:20 555e07ef33f69a0957d24d8e555b702464a131d6f1607f4c3c1e4551e8e6ca76';

final class WriterToken {
  WriterToken(this.namespace, this.projectId, this.owner, this.epoch);
  final Namespace namespace;
  final String projectId, owner;
  final int epoch;
}

final class CommitReceipt {
  CommitReceipt._(this._json);
  final String _json;
  Map<String, dynamic> toJson() => jsonDecode(_json) as Map<String, dynamic>;
  BigInt get revision => BigInt.parse(toJson()['revision'] as String);
  String get disposition => toJson()['disposition'] as String;
}

/// Trusted host only: one bound namespace for every query, never caller SQL.
/// Sharing a file is logical isolation, not an OS sandbox/security boundary.
final class DocumentRepository {
  DocumentRepository.open(
    String path,
    this.namespace, {
    bool allowUnqualifiedSqliteForDevelopment = false,
  }) : _db = sqlite3.open(path) {
    try {
      if (!allowUnqualifiedSqliteForDevelopment) {
        final runtime = _db
            .select(
              "SELECT sqlite_version() AS version,sqlite_source_id() AS source,sqlite_compileoption_used('THREADSAFE=1') AS threadsafe",
            )
            .single;
        if (runtime['version'] != approvedSqliteVersion ||
            runtime['source'] != approvedSqliteSourceId ||
            runtime['threadsafe'] != 1) {
          throw const StudioException('SQLITE_RUNTIME_NOT_APPROVED');
        }
      }
      _db.execute('PRAGMA foreign_keys=ON');
      _db.execute('PRAGMA busy_timeout=10000');
      _transaction(() {
        final version = _db.userVersion;
        if (version > 5) {
          throw const StudioException('STORE_VERSION_UNSUPPORTED');
        }
        if (version == 0) {
          _db.execute(_ddl);
          _db.execute('INSERT INTO schema_migrations VALUES(1,?)', [
            contentHash(_ddl),
          ]);
          _db.userVersion = 1;
        }
        final rows = _db.select(
          'SELECT checksum FROM schema_migrations WHERE version=1',
        );
        if (rows.length != 1 || rows.single['checksum'] != contentHash(_ddl)) {
          throw const StudioException('MIGRATION_CHECKSUM_MISMATCH');
        }
        if (version < 2) {
          _db.execute(_ddl2);
          _db.execute('INSERT INTO schema_migrations VALUES(2,?)', [
            contentHash(_ddl2),
          ]);
          _db.userVersion = 2;
        }
        final v2 = _db.select(
          'SELECT checksum FROM schema_migrations WHERE version=2',
        );
        if (v2.length != 1 || v2.single['checksum'] != contentHash(_ddl2)) {
          throw const StudioException('MIGRATION_CHECKSUM_MISMATCH');
        }
        if (version < 3) {
          _db.execute(_ddl3);
          _db.execute('INSERT INTO schema_migrations VALUES(3,?)', [
            contentHash(_ddl3),
          ]);
          _db.userVersion = 3;
        }
        final v3 = _db.select(
          'SELECT checksum FROM schema_migrations WHERE version=3',
        );
        if (v3.length != 1 || v3.single['checksum'] != contentHash(_ddl3)) {
          throw const StudioException('MIGRATION_CHECKSUM_MISMATCH');
        }
        if (version < 4) {
          _db.execute(_ddl4);
          _db.execute('INSERT INTO schema_migrations VALUES(4,?)', [
            contentHash(_ddl4),
          ]);
          _db.userVersion = 4;
        }
        final v4 = _db.select(
          'SELECT checksum FROM schema_migrations WHERE version=4',
        );
        if (v4.length != 1 || v4.single['checksum'] != contentHash(_ddl4)) {
          throw const StudioException('MIGRATION_CHECKSUM_MISMATCH');
        }
        if (version < 5) {
          _db.execute(_ddl5);
          _db.execute('INSERT INTO schema_migrations VALUES(5,?)', [
            contentHash(_ddl5),
          ]);
          _db.userVersion = 5;
        }
        final v5 = _db.select(
          'SELECT checksum FROM schema_migrations WHERE version=5',
        );
        if (v5.length != 1 || v5.single['checksum'] != contentHash(_ddl5)) {
          throw const StudioException('MIGRATION_CHECKSUM_MISMATCH');
        }
      });
      _db.execute('PRAGMA journal_mode=WAL');
      _db.execute('PRAGMA synchronous=FULL');
    } catch (_) {
      _db.dispose();
      rethrow;
    }
  }
  final Namespace namespace;
  final Database _db;
  String get _ns => namespace.key;
  bool _closed = false;
  int _transactionDepth = 0;
  T _transaction<T>(T Function() action) {
    final depth = _transactionDepth++,
        savepoint = 'studio_nested_$_transactionDepth';
    try {
      _db.execute(depth == 0 ? 'BEGIN IMMEDIATE' : 'SAVEPOINT $savepoint');
      try {
        final result = action();
        _db.execute(depth == 0 ? 'COMMIT' : 'RELEASE $savepoint');
        return result;
      } catch (_) {
        if (depth == 0) {
          _db.execute('ROLLBACK');
        } else {
          _db.execute('ROLLBACK TO $savepoint');
          _db.execute('RELEASE $savepoint');
        }
        rethrow;
      }
    } finally {
      _transactionDepth--;
    }
  }

  void close() {
    if (!_closed) {
      _closed = true;
      _db.dispose();
    }
  }

  void _put(String hash, String json) {
    _db.execute('INSERT OR IGNORE INTO snapshots VALUES(?,?,?)', [
      _ns,
      hash,
      json,
    ]);
    final stored = _db.select(
      'SELECT json FROM snapshots WHERE ns=? AND hash=?',
      [_ns, hash],
    ).single['json'];
    if (stored != json) throw const StudioException('HASH_COLLISION');
  }

  ProjectDocument? read(String projectId) {
    requireId(projectId);
    final rows = _db.select(
      'SELECT s.json,s.hash,h.revision FROM project_heads h LEFT JOIN snapshots s ON s.ns=h.ns AND s.hash=h.snapshot_hash WHERE h.ns=? AND h.project_id=?',
      [_ns, projectId],
    );
    if (rows.isEmpty) return null;
    if (rows.single['json'] is! String) {
      throw const StudioException('STORE_INTEGRITY');
    }
    final p = ProjectDocument.fromJson(
      jsonDecode(rows.single['json'] as String) as Map<String, dynamic>,
    );
    if (p.namespace != namespace ||
        p.projectId != projectId ||
        p.hash != rows.single['hash'] ||
        p.revision != BigInt.from(rows.single['revision'] as int)) {
      throw const StudioException('STORE_INTEGRITY');
    }
    return p;
  }

  void create(ProjectDocument project) {
    if (project.namespace != namespace) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
    requireLocalEditingWritable(project);
    if (project.revision != BigInt.zero) {
      throw const StudioException('INITIAL_REVISION_REQUIRED');
    }
    _transaction(() {
      if (read(project.projectId) != null) {
        throw const StudioException('PROJECT_EXISTS');
      }
      _put(project.hash, project.canonicalJson);
      _db.execute(
        'INSERT INTO project_heads(ns,project_id,revision,snapshot_hash) VALUES(?,?,0,?)',
        [_ns, project.projectId, project.hash],
      );
      _db.execute('INSERT INTO stream_heads VALUES(?,?,1)', [
        _ns,
        project.projectId,
      ]);
      _registerDefinitions(project);
      _pinBlobs(project);
    });
  }

  String? get selectedProjectId {
    final row = _db.select(
      'SELECT project_id FROM project_preferences WHERE ns=?',
      [_ns],
    );
    return row.isEmpty ? null : row.single['project_id'] as String;
  }

  void selectProject(String id) {
    requireId(id);
    if (read(id) == null) throw const StudioException('PROJECT_NOT_FOUND');
    _db.execute(
      'INSERT INTO project_preferences VALUES(?,?) ON CONFLICT(ns) DO UPDATE SET project_id=excluded.project_id',
      [_ns, id],
    );
  }

  int writerEpoch(String projectId) {
    requireId(projectId);
    final rows = _db.select(
      'SELECT fence FROM project_heads WHERE ns=? AND project_id=?',
      [_ns, projectId],
    );
    if (rows.isEmpty) throw const StudioException('PROJECT_NOT_FOUND');
    return rows.single['fence'] as int;
  }

  String? latestCommandId(String projectId) {
    requireId(projectId);
    final rows = _db.select(
      'SELECT command_id FROM revisions WHERE ns=? AND project_id=? ORDER BY revision DESC LIMIT 1',
      [_ns, projectId],
    );
    return rows.isEmpty ? null : rows.single['command_id'] as String;
  }

  WriterToken acquireWriter(
    String projectId,
    String owner, {
    required int expectedEpoch,
  }) {
    requireId(projectId);
    requireId(owner);
    if (expectedEpoch < 0 || BigInt.from(expectedEpoch) >= maxI64) {
      throw const StudioException('FENCE_OVERFLOW');
    }
    return _transaction(() {
      _db.execute(
        'UPDATE project_heads SET owner=?,fence=fence+1 WHERE ns=? AND project_id=? AND fence=?',
        [owner, _ns, projectId, expectedEpoch],
      );
      if (_db.updatedRows != 1) {
        throw const StudioException('WRITER_FENCE_CONFLICT');
      }
      return WriterToken(namespace, projectId, owner, expectedEpoch + 1);
    });
  }

  CommitReceipt rename({
    required WriterToken writer,
    required String commandId,
    required String receiptKey,
    required BigInt expectedRevision,
    required String title,
  }) => _commit(writer, commandId, receiptKey, expectedRevision, {
    'kind': 'renameProject',
    'title': title,
  }, operation: RenameProject(title));
  CommitReceipt undoLatest({
    required WriterToken writer,
    required String commandId,
    required String receiptKey,
    required BigInt expectedRevision,
    required String targetCommandId,
  }) => _commit(writer, commandId, receiptKey, expectedRevision, {
    'kind': 'undoLatest',
    'targetCommandId': targetCommandId,
  });

  CommitReceipt edit({
    required WriterToken writer,
    required String commandId,
    required String receiptKey,
    required BigInt expectedRevision,
    required EditOperation operation,
  }) => _commit(
    writer,
    commandId,
    receiptKey,
    expectedRevision,
    operation.toJson(),
    operation: operation,
  );

  void _registerDefinitions(ProjectDocument project) {
    final d = project.toJson();
    final definitions = <Map<String, dynamic>>[];
    for (final a in d['assets'] as List) {
      definitions.add(a as Map<String, dynamic>);
    }
    for (final c in d['captions'] as List) {
      definitions.add(c as Map<String, dynamic>);
    }
    for (final seq in d['sequences'] as List) {
      final used = <String>{};
      for (final t in seq['tracks']) {
        for (final c in t['items']) {
          if (c['source'] != null) {
            used.add(c['source']['id'] as String);
            definitions.add(c as Map<String, dynamic>);
          }
        }
      }
      final baseHash = used.isEmpty
          ? contentHash(seq)
          : contentHash({
              'definition': seq,
              'sources':
                  (d['assets'] as List)
                      .where((a) => used.contains(a['id']))
                      .toList()
                    ..sort(
                      (a, b) =>
                          (a['id'] as String).compareTo(b['id'] as String),
                    ),
            });
      final trackIds = (seq['tracks'] as List).map((t) => t['id']).toSet();
      final cues =
          (d['captions'] as List)
              .where((c) => trackIds.contains(c['trackId']))
              .toList()
            ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      final seqHash = cues.isEmpty
          ? baseHash
          : contentHash({'base': baseHash, 'captions': cues});
      _registerVersion(
        project.projectId,
        seq['id'] as String,
        seq['version'] as String,
        seqHash,
      );
    }
    for (final entity in definitions) {
      _registerVersion(
        project.projectId,
        entity['id'] as String,
        entity['version'] as String,
        contentHash(entity),
      );
    }
  }

  void _registerVersion(
    String projectId,
    String id,
    String version,
    String hash,
  ) {
    final previous = _db.select(
      'SELECT content_hash FROM entity_versions WHERE ns=? AND project_id=? AND entity_id=? AND version=?',
      [_ns, projectId, id, int.parse(version)],
    );
    if (previous.isNotEmpty) {
      if (previous.single['content_hash'] != hash) {
        throw const StudioException('IMMUTABLE_VERSION_CONFLICT');
      }
      return;
    }
    _db.execute('INSERT INTO entity_versions VALUES(?,?,?,?,?)', [
      _ns,
      projectId,
      id,
      int.parse(version),
      hash,
    ]);
  }

  void _pinBlobs(ProjectDocument project) {
    for (final b in project.toJson()['blobs'] as List) {
      _db.execute('INSERT OR IGNORE INTO blob_edges VALUES(?,?,?,?)', [
        _ns,
        project.projectId,
        project.revision.toInt(),
        b['hash'],
      ]);
    }
  }

  CommitReceipt _commit(
    WriterToken writer,
    String commandId,
    String receiptKey,
    BigInt expectedRevision,
    Map<String, dynamic> payload, {
    EditOperation? operation,
  }) {
    if (writer.namespace != namespace) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
    requireId(commandId);
    requireId(receiptKey);
    requireId(writer.projectId);
    if (expectedRevision.isNegative || expectedRevision > maxI64) {
      throw const StudioException('REVISION_OVERFLOW');
    }
    final inputHash = contentHash({
      'projectId': writer.projectId,
      'commandId': commandId,
      'expectedRevision': expectedRevision.toString(),
      'payload': payload,
    });
    return _transaction(() {
      final prior = _db.select(
        'SELECT input_hash,result_json FROM receipts WHERE ns=? AND receipt_key=?',
        [_ns, receiptKey],
      );
      if (prior.isNotEmpty) {
        if (prior.single['input_hash'] != inputHash) {
          throw const StudioException('IDEMPOTENCY_KEY_REUSED');
        }
        return CommitReceipt._(prior.single['result_json'] as String);
      }
      if (_db.select('SELECT 1 FROM receipts WHERE ns=? AND command_id=?', [
        _ns,
        commandId,
      ]).isNotEmpty) {
        throw const StudioException('COMMAND_ID_REUSED');
      }
      final before = read(writer.projectId);
      if (before == null) throw const StudioException('PROJECT_NOT_FOUND');
      requireLocalEditingWritable(before);
      if (before.revision != expectedRevision) {
        throw const StudioException('REVISION_CONFLICT');
      }
      final head = _db.select(
        'SELECT owner,fence FROM project_heads WHERE ns=? AND project_id=?',
        [_ns, writer.projectId],
      ).single;
      if (head['owner'] != writer.owner || head['fence'] != writer.epoch) {
        throw const StudioException('WRITER_FENCED');
      }
      ProjectDocument candidate;
      if (operation != null) {
        final allocations = <String, String>{};
        String nextVersion(String id) => allocations.putIfAbsent(id, () {
          final max =
              _db.select(
                    'SELECT max(version) AS version FROM entity_versions WHERE ns=? AND project_id=? AND entity_id=?',
                    [_ns, writer.projectId, id],
                  ).single['version']
                  as int?;
          final next = BigInt.from(max ?? 0) + BigInt.one;
          if (next > maxI64) throw const StudioException('VERSION_OVERFLOW');
          return next.toString();
        });
        candidate = applyEdit(
          before,
          operation,
          nextVersion: nextVersion,
          newId: () => const Uuid().v7(),
        );
      } else {
        requireId(payload['targetCommandId'] as String);
        final target = _db.select(
          'SELECT c.before_ref,r.revision FROM commands c JOIN revisions r ON r.ns=c.ns AND r.command_id=c.id WHERE c.ns=? AND c.project_id=? AND c.id=?',
          [_ns, writer.projectId, payload['targetCommandId']],
        );
        if (target.isEmpty ||
            target.single['revision'] != expectedRevision.toInt()) {
          throw const StudioException('UNDO_CONFLICT');
        }
        final old = _db.select(
          'SELECT json FROM snapshots WHERE ns=? AND hash=?',
          [_ns, target.single['before_ref']],
        );
        if (old.length != 1) throw const StudioException('STORE_INTEGRITY');
        final historical = ProjectDocument.fromJson(
          jsonDecode(old.single['json'] as String) as Map<String, dynamic>,
        );
        if (historical.hash != target.single['before_ref'] ||
            historical.namespace != namespace ||
            historical.projectId != writer.projectId ||
            historical.revision != expectedRevision - BigInt.one) {
          throw const StudioException('STORE_INTEGRITY');
        }
        requireLocalEditingWritable(historical);
        candidate = historical.withTitle(historical.title, expectedRevision);
      }
      final changed = candidate.canonicalJson != before.canonicalJson;
      if (changed && expectedRevision == maxI64) {
        throw const StudioException('REVISION_OVERFLOW');
      }
      final after = candidate.withTitle(
        candidate.title,
        changed ? expectedRevision + BigInt.one : expectedRevision,
      );
      final previousSeq =
          (_db.select(
                'SELECT next_seq FROM stream_heads WHERE ns=? AND project_id=?',
                [_ns, writer.projectId],
              ).single['next_seq']
              as int) -
          1;
      final inverse = {'kind': 'restoreSnapshot', 'snapshotHash': before.hash};
      final inverseHash = contentHash(inverse);
      final result = {
        'disposition': changed ? 'applied' : 'noDocumentChange',
        'commandId': commandId,
        'previousRevision': expectedRevision.toString(),
        'revision': after.revision.toString(),
        'eventSeq': (changed ? previousSeq + 1 : previousSeq).toString(),
        'beforeImageRef': before.hash,
        'afterImageRef': after.hash,
        'inversePatchRef': changed ? inverseHash : null,
        'invalidatedRanges':
            changed &&
                contentHash(before.toJson()['sequences']) !=
                    contentHash(after.toJson()['sequences']) &&
                (Q.fromJson(before.toJson()['sequences'][0]['duration']) >
                        Q.of(0) ||
                    Q.fromJson(after.toJson()['sequences'][0]['duration']) >
                        Q.of(0))
            ? [
                {
                  'sequenceId': after.toJson()['rootSequenceId'],
                  'range': {
                    'start': Q.of(0).toJson(),
                    'duration':
                        (Q.fromJson(
                                      before
                                          .toJson()['sequences'][0]['duration'],
                                    ) >
                                    Q.fromJson(
                                      after
                                          .toJson()['sequences'][0]['duration'],
                                    )
                                ? Q.fromJson(
                                    before.toJson()['sequences'][0]['duration'],
                                  )
                                : Q.fromJson(
                                    after.toJson()['sequences'][0]['duration'],
                                  ))
                            .toJson(),
                  },
                },
              ]
            : [],
        'warnings': [],
      };
      if (changed) {
        _put(after.hash, after.canonicalJson);
        _registerDefinitions(after);
        _pinBlobs(after);
        _put(inverseHash, jsonEncode(inverse));
        _db.execute(
          'UPDATE project_heads SET revision=?,snapshot_hash=? WHERE ns=? AND project_id=? AND revision=? AND owner=? AND fence=?',
          [
            after.revision.toInt(),
            after.hash,
            _ns,
            writer.projectId,
            expectedRevision.toInt(),
            writer.owner,
            writer.epoch,
          ],
        );
        if (_db.updatedRows != 1) {
          throw const StudioException('REVISION_CONFLICT');
        }
        _db.execute('INSERT INTO commands VALUES(?,?,?,?,?,?,?,?,?)', [
          _ns,
          commandId,
          writer.projectId,
          inputHash,
          expectedRevision.toInt(),
          before.hash,
          after.hash,
          inverseHash,
          jsonEncode(payload),
        ]);
        _db.execute('INSERT INTO revisions VALUES(?,?,?,?,?,?)', [
          _ns,
          writer.projectId,
          after.revision.toInt(),
          expectedRevision.toInt(),
          after.hash,
          commandId,
        ]);
        _db.execute(
          'UPDATE stream_heads SET next_seq=next_seq+1 WHERE ns=? AND project_id=?',
          [_ns, writer.projectId],
        );
        _db.execute('INSERT INTO events VALUES(?,?,?,?,?)', [
          _ns,
          writer.projectId,
          previousSeq + 1,
          commandId,
          after.hash,
        ]);
        _db.execute(
          "INSERT INTO outbox VALUES(?,?,'projection.documentChanged',?,'pending')",
          [_ns, commandId, after.hash],
        );
      }
      final encoded = jsonEncode(result);
      _db.execute('INSERT INTO receipts VALUES(?,?,?,?,?)', [
        _ns,
        receiptKey,
        commandId,
        inputHash,
        encoded,
      ]);
      return CommitReceipt._(encoded);
    });
  }

  void createSession(String id, String title) {
    requireId(id);
    if (title.isEmpty || title.runes.length > 1024) {
      throw const StudioException('INVALID_SESSION_TITLE');
    }
    _db.execute('INSERT INTO sessions VALUES(?,?,?)', [_ns, id, title]);
  }

  String? sessionTitle(String id) {
    requireId(id);
    final rows = _db.select('SELECT title FROM sessions WHERE ns=? AND id=?', [
      _ns,
      id,
    ]);
    return rows.isEmpty ? null : rows.single['title'] as String;
  }

  /// Tiny fixture assets only; production media CAS/files are I-004, not this table.
  String putFixtureBytes(Uint8List bytes) {
    if (bytes.length > 1024 * 1024) {
      throw const StudioException('FIXTURE_BLOB_LIMIT');
    }
    // Hash the raw bytes, not JSON; scoped access is independent of byte identity.
    final hash = rawBytesHash(bytes);
    _db.execute('INSERT OR IGNORE INTO immutable_blobs VALUES(?,?,?)', [
      _ns,
      hash,
      bytes,
    ]);
    return hash;
  }

  Uint8List? fixtureBytes(String hash) {
    final rows = _db.select(
      'SELECT bytes FROM immutable_blobs WHERE ns=? AND hash=?',
      [_ns, hash],
    );
    if (rows.isEmpty) return null;
    final bytes = Uint8List.fromList(rows.single['bytes'] as Uint8List);
    if (rawBytesHash(bytes) != hash) {
      throw const StudioException('STORE_INTEGRITY');
    }
    return bytes;
  }
}
