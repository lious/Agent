import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';
export 'package:studio_contracts/studio_contracts.dart';

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
  DocumentRepository.open(String path, this.namespace)
    : _db = sqlite3.open(path) {
    try {
      _db.execute('PRAGMA foreign_keys=ON');
      _db.execute('PRAGMA busy_timeout=10000');
      _transaction(() {
        final version = _db.userVersion;
        if (version > 1) {
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
  T _transaction<T>(T Function() action) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      _db.execute('COMMIT');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
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
    project.requireFoundationWritable();
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
      for (final seq in project.toJson()['sequences'] as List) {
        _db.execute('INSERT INTO entity_versions VALUES(?,?,?,?,?)', [
          _ns,
          project.projectId,
          seq['id'],
          int.parse(seq['version'] as String),
          contentHash(seq),
        ]);
      }
    });
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
  });
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

  CommitReceipt _commit(
    WriterToken writer,
    String commandId,
    String receiptKey,
    BigInt expectedRevision,
    Map<String, dynamic> payload,
  ) {
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
      before.requireFoundationWritable();
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
      String title;
      if (payload['kind'] == 'renameProject') {
        title = payload['title'] as String;
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
        historical.requireFoundationWritable();
        title = historical.title;
      }
      final changed = title != before.title;
      if (changed && expectedRevision == maxI64) {
        throw const StudioException('REVISION_OVERFLOW');
      }
      final after = before.withTitle(
        title,
        changed ? expectedRevision + BigInt.one : expectedRevision,
      );
      final previousSeq =
          (_db.select(
                'SELECT next_seq FROM stream_heads WHERE ns=? AND project_id=?',
                [_ns, writer.projectId],
              ).single['next_seq']
              as int) -
          1;
      final inverse = {'kind': 'restoreProjectTitle', 'title': before.title};
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
        'invalidatedRanges': [],
        'warnings': [],
      };
      if (changed) {
        _put(after.hash, after.canonicalJson);
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
