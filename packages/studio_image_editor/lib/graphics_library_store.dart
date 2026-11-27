import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_contracts/studio_contracts.dart';

import 'graphics_library_ddl.dart';
import 'image_codes.dart';

/// Dedicated graphics-library/1 workspace database.
///
/// This is not the core project store. [Database.userVersion] here is the
/// private library document number (1) and never writes the project store's
/// `user_version` (frozen at 9 in this slice). Pin rows belong to the
/// `studio.graphics-library.v1` sidecar, not Project 2.0 root fields.
final class GraphicsLibraryStore {
  static const libraryDocumentVersion = 1;
  static const featureName = 'graphics_library';
  static const featureVersion = '1.0.0';
  static const featureDocument = 'graphics-library/1';

  GraphicsLibraryStore._(this.namespace, this._db, this.root);

  final Namespace namespace;
  final Database _db;
  final String root;
  bool _closed = false;

  String get ns => namespace.key;

  static GraphicsLibraryStore open(String root, Namespace namespace) {
    final dir = Directory(root)..createSync(recursive: true);
    Directory(p.join(dir.path, 'cas')).createSync();
    final db = sqlite3.open(p.join(dir.path, 'graphics.sqlite'));
    try {
      db.execute('PRAGMA foreign_keys=ON');
      db.execute('BEGIN IMMEDIATE');
      try {
        final version = db.userVersion;
        if (version == 0) {
          applyOfficialGraphicsLibraryDdl(db);
          db.userVersion = libraryDocumentVersion;
        } else if (version != libraryDocumentVersion) {
          throw const StudioException('UNSUPPORTED_LIBRARY_WORKSPACE');
        }
        _requireOfficialTables(db);
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
      db.execute('PRAGMA journal_mode=WAL');
      db.execute('PRAGMA synchronous=FULL');
    } catch (_) {
      db.dispose();
      rethrow;
    }
    return GraphicsLibraryStore._(namespace, db, dir.path);
  }

  static void _requireOfficialTables(Database db) {
    final tables = db
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((r) => r['name'] as String)
        .toSet();
    const required = {
      'workspace_features',
      'graphic_versions',
      'graphic_heads',
      'graphics_library_pins',
    };
    if (!required.every(tables.contains)) {
      throw const StudioException('UNSUPPORTED_LIBRARY_WORKSPACE', 'tables');
    }
    final feature = db.select(
      'SELECT version, document FROM workspace_features WHERE name=?',
      [featureName],
    );
    if (feature.isEmpty ||
        feature.first['version'] != featureVersion ||
        feature.first['document'] != featureDocument) {
      throw const StudioException('UNSUPPORTED_LIBRARY_WORKSPACE', 'feature');
    }
  }

  int get userVersion => _db.userVersion;

  void close() {
    if (_closed) return;
    _db.dispose();
    _closed = true;
  }

  void putCas(String hash, List<int> bytes) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const StudioException('INVALID_ID', 'body_hash');
    }
    final file = File(p.join(root, 'cas', hash));
    if (!file.existsSync()) {
      file.writeAsBytesSync(Uint8List.fromList(bytes), flush: true);
    }
  }

  Uint8List readCas(String hash) {
    final file = File(p.join(root, 'cas', hash));
    if (!file.existsSync()) {
      throw StudioException('RESOURCE_MISSING', hash);
    }
    return file.readAsBytesSync();
  }

  void insertVersion({
    required String kind,
    required String id,
    required String version,
    required String bodyHash,
  }) {
    _guard();
    try {
      _db.execute(
        'INSERT INTO graphic_versions(ns,kind,id,version,body_hash) VALUES(?,?,?,?,?)',
        [ns, kind, id, version, bodyHash],
      );
    } on SqliteException catch (e) {
      if (e.message.contains('IMMUTABLE_GRAPHIC_VERSION')) {
        throw const StudioException(immutableGraphicVersion);
      }
      rethrow;
    }
  }

  void setHead({
    required String kind,
    required String id,
    required String version,
  }) {
    _guard();
    final existing = _db.select(
      'SELECT version FROM graphic_heads WHERE ns=? AND kind=? AND id=?',
      [ns, kind, id],
    );
    if (existing.isEmpty) {
      _db.execute(
        'INSERT INTO graphic_heads(ns,kind,id,version) VALUES(?,?,?,?)',
        [ns, kind, id, version],
      );
    } else {
      _db.execute(
        'UPDATE graphic_heads SET version=? WHERE ns=? AND kind=? AND id=?',
        [version, ns, kind, id],
      );
    }
  }

  String? headVersion(String kind, String id) {
    final rows = _db.select(
      'SELECT version FROM graphic_heads WHERE ns=? AND kind=? AND id=?',
      [ns, kind, id],
    );
    return rows.isEmpty ? null : rows.first['version'] as String;
  }

  Map<String, Object?>? versionRow(String kind, String id, String version) {
    final rows = _db.select(
      'SELECT ns,kind,id,version,body_hash FROM graphic_versions '
      'WHERE ns=? AND kind=? AND id=? AND version=?',
      [ns, kind, id, version],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      'ns': r['ns'],
      'kind': r['kind'],
      'id': r['id'],
      'version': r['version'],
      'body_hash': r['body_hash'],
    };
  }

  List<Map<String, Object?>> versionsInNamespace({String? text, List<String>? tags}) {
    final rows = _db.select(
      'SELECT v.kind,v.id,v.version,v.body_hash,h.version AS head '
      'FROM graphic_versions v '
      'JOIN graphic_heads h ON h.ns=v.ns AND h.kind=v.kind AND h.id=v.id AND h.version=v.version '
      'WHERE v.ns=? '
      'AND NOT EXISTS (SELECT 1 FROM graphics_library_trash t '
      ' WHERE t.ns=v.ns AND t.kind=v.kind AND t.id=v.id AND t.version=v.version)',
      [ns],
    );
    return [
      for (final r in rows)
        {
          'kind': r['kind'],
          'id': r['id'],
          'version': r['version'],
          'body_hash': r['body_hash'],
        },
    ];
  }

  void pin({
    required String projectId,
    required String kind,
    required String id,
    required String version,
    required String hash,
  }) {
    requireId(projectId);
    _guard();
    _db.execute(
      'INSERT INTO graphics_library_pins(project_id,ns,kind,id,version,hash) '
      'VALUES(?,?,?,?,?,?) '
      'ON CONFLICT(project_id,ns,kind,id) DO UPDATE SET version=excluded.version, hash=excluded.hash',
      [projectId, ns, kind, id, version, hash],
    );
  }

  Map<String, Object?>? projectPin(String projectId, String kind, String id) {
    final rows = _db.select(
      'SELECT project_id,kind,id,version,hash FROM graphics_library_pins '
      'WHERE project_id=? AND ns=? AND kind=? AND id=?',
      [projectId, ns, kind, id],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      'projectId': r['project_id'],
      'kind': r['kind'],
      'id': r['id'],
      'version': r['version'],
      'hash': r['hash'],
    };
  }

  List<String> projectsPinning(String kind, String id, String version) {
    return _db
        .select(
          'SELECT DISTINCT project_id FROM graphics_library_pins '
          'WHERE ns=? AND kind=? AND id=? AND version=?',
          [ns, kind, id, version],
        )
        .map((r) => r['project_id'] as String)
        .toList();
  }

  List<Map<String, Object?>> pinsFor(String kind, String id) {
    return [
      for (final r in _db.select(
        'SELECT project_id,version,hash FROM graphics_library_pins '
        'WHERE ns=? AND kind=? AND id=?',
        [ns, kind, id],
      ))
        {
          'projectId': r['project_id'],
          'version': r['version'],
          'hash': r['hash'],
        },
    ];
  }

  void putRights({
    required String rightsId,
    required String epoch,
    required List<String> allowedUses,
    required bool redistributable,
  }) {
    requireId(rightsId);
    _db.execute(
      'INSERT INTO graphic_rights(rights_id,epoch,allowed_uses,redistributable) '
      'VALUES(?,?,?,?) '
      'ON CONFLICT(rights_id) DO UPDATE SET epoch=excluded.epoch, '
      'allowed_uses=excluded.allowed_uses, redistributable=excluded.redistributable',
      [rightsId, epoch, allowedUses.join(','), redistributable ? 1 : 0],
    );
  }

  Map<String, Object?>? rights(String rightsId) {
    final rows = _db.select(
      'SELECT rights_id,epoch,allowed_uses,redistributable FROM graphic_rights WHERE rights_id=?',
      [rightsId],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return {
      'rightsId': r['rights_id'],
      'epoch': r['epoch'],
      'allowedUses': (r['allowed_uses'] as String)
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      'redistributable': (r['redistributable'] as int) == 1,
    };
  }

  void trash({required String kind, required String id, required String version}) {
    _db.execute(
      'INSERT OR IGNORE INTO graphics_library_trash(ns,kind,id,version,trashed_at) '
      'VALUES(?,?,?,?,?)',
      [ns, kind, id, version, DateTime.now().toUtc().toIso8601String()],
    );
    final head = headVersion(kind, id);
    if (head == version) {
      _db.execute(
        'DELETE FROM graphic_heads WHERE ns=? AND kind=? AND id=?',
        [ns, kind, id],
      );
    }
  }

  void _guard() {
    if (_closed) throw const StudioException('INVALID_ID', 'closed');
  }
}
