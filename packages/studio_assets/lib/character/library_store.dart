import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_document/studio_document.dart';

import 't57_library_ddl.dart';

/// Dedicated character-library workspace database.
///
/// Applies official T57_LIBRARY_DDL as library workspace w5 → w6. This is not
/// the core project store: [Database.userVersion] here is the library
/// workspace number (6) and never writes the project store's user_version
/// (frozen at 9 in this slice). CAS blob bytes live beside the database, not
/// in invented Project 2.0 root tables. Events/outbox stay on the original
/// project store and are not reimplemented here.
///
/// The official DDL text includes `craft_fts`. The approved SQLite 3.54.1
/// library in this checkout is compiled without `SQLITE_ENABLE_FTS5`, so that
/// virtual table is not instantiated here and the approved binary is not
/// replaced. I-037 craft FTS is not opened.
final class CharacterLibraryStore {
  static const libraryWorkspaceVersion = 6;

  CharacterLibraryStore._(this.namespace, this._db, this.root);

  final Namespace namespace;
  final Database _db;
  final String root;
  bool _closed = false;
  int _transactionDepth = 0;

  String get ns => namespace.key;

  static CharacterLibraryStore open(String root, Namespace namespace) {
    final dir = Directory(root)..createSync(recursive: true);
    Directory(p.join(dir.path, 'cas')).createSync();
    final db = sqlite3.open(p.join(dir.path, 'library.sqlite'));
    try {
      db.execute('PRAGMA foreign_keys=ON');
      db.execute('BEGIN IMMEDIATE');
      try {
        final version = db.userVersion;
        if (version == 0 || version == 5) {
          applyT57LibraryDdl(db);
          db.userVersion = libraryWorkspaceVersion;
        } else if (version != libraryWorkspaceVersion) {
          throw const StudioException('UNSUPPORTED_LIBRARY_WORKSPACE');
        }
        _requireOfficialTables(db);
        _ensureLeaseGcLedgers(db);
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
    return CharacterLibraryStore._(namespace, db, dir.path);
  }

  static void _requireOfficialTables(Database db) {
    const required = {
      'library_versions',
      'library_heads',
      'character_look_index',
      'model_adapter_bindings',
      'portrait_rights_versions',
      'portrait_rights_live',
      'library_project_pins',
      'audio_candidates',
      'license_decisions',
    };
    final names = {
      for (final row in db.select(
        "SELECT name FROM sqlite_master WHERE type='table' OR type='view'",
      ))
        row['name'] as String,
    };
    for (final name in required) {
      if (!names.contains(name)) {
        throw StudioException('LIBRARY_DDL_MISSING', name);
      }
    }
    if (sqliteHasFts5(db) && !names.contains('craft_fts')) {
      throw const StudioException('LIBRARY_DDL_MISSING', 'craft_fts');
    }
  }

  /// I-036 lease / revocation / GC ledgers. These are library-workspace
  /// application tables, not official T57 DDL, not Project root tables, and
  /// they do not bump the library workspace number (stays 6) or the core
  /// project store user_version.
  static void _ensureLeaseGcLedgers(Database db) {
    db.execute("""
CREATE TABLE IF NOT EXISTS library_export_pins (
  namespace TEXT NOT NULL,
  export_id TEXT NOT NULL,
  library_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  version TEXT NOT NULL,
  pack_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY(namespace, export_id),
  FOREIGN KEY(namespace, library_id, kind, entity_id, version)
    REFERENCES library_versions(namespace, library_id, kind, entity_id, version)
);
""");
    db.execute("""
CREATE TABLE IF NOT EXISTS library_candidate_pins (
  namespace TEXT NOT NULL,
  task_id TEXT NOT NULL,
  library_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  version TEXT NOT NULL,
  pack_hash TEXT NOT NULL,
  state TEXT NOT NULL CHECK(state IN ('processing','ready','cancelled','isolated')),
  PRIMARY KEY(namespace, task_id),
  FOREIGN KEY(namespace, library_id, kind, entity_id, version)
    REFERENCES library_versions(namespace, library_id, kind, entity_id, version)
);
""");
    db.execute("""
CREATE TABLE IF NOT EXISTS library_retention_plans (
  namespace TEXT NOT NULL,
  plan_id TEXT NOT NULL,
  library_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  version TEXT NOT NULL,
  reason TEXT NOT NULL CHECK(reason IN ('retain','revocationCleanup')),
  PRIMARY KEY(namespace, plan_id, library_id, kind, entity_id, version),
  FOREIGN KEY(namespace, library_id, kind, entity_id, version)
    REFERENCES library_versions(namespace, library_id, kind, entity_id, version)
);
""");
    db.execute("""
CREATE TABLE IF NOT EXISTS portrait_revocation_denylist (
  namespace TEXT NOT NULL,
  rights_id TEXT NOT NULL,
  pack_hash TEXT NOT NULL,
  evidence_hash TEXT NOT NULL,
  source_rights_id TEXT NOT NULL,
  epoch TEXT NOT NULL,
  PRIMARY KEY(namespace, rights_id, pack_hash, evidence_hash)
);
""");
    db.execute("""
CREATE TABLE IF NOT EXISTS character_existing_outputs (
  namespace TEXT NOT NULL,
  output_id TEXT NOT NULL,
  rights_id TEXT NOT NULL,
  path TEXT NOT NULL,
  body_hash TEXT,
  PRIMARY KEY(namespace, output_id)
);
""");
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _db.dispose();
  }

  T transaction<T>(T Function() action) {
    final depth = _transactionDepth++;
    final savepoint = 'library_$_transactionDepth';
    try {
      _db.execute(depth == 0 ? 'BEGIN IMMEDIATE' : 'SAVEPOINT $savepoint');
      try {
        final result = action();
        _db.execute(depth == 0 ? 'COMMIT' : 'RELEASE $savepoint');
        return result;
      } catch (_) {
        _db.execute(depth == 0 ? 'ROLLBACK' : 'ROLLBACK TO $savepoint');
        if (depth > 0) {
          _db.execute('RELEASE $savepoint');
        }
        rethrow;
      }
    } finally {
      _transactionDepth--;
    }
  }

  List<Row> select(String sql, [List<Object?> params = const []]) =>
      _db.select(sql, params);

  void execute(String sql, [List<Object?> params = const []]) =>
      _db.execute(sql, params);

  int get userVersion => _db.userVersion;

  bool get fts5Enabled => sqliteHasFts5(_db);

  void putCas(String hash, List<int> bytes) {
    if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(hash)) {
      throw const StudioException('INVALID_HASH');
    }
    final actual = rawBytesHash(bytes);
    if (actual != hash) {
      throw const StudioException('BLOB_HASH_MISMATCH');
    }
    final file = File(_casPath(hash));
    if (file.existsSync()) {
      final existing = file.readAsBytesSync();
      if (rawBytesHash(existing) != hash) {
        throw const StudioException('CAS_CORRUPT');
      }
      return;
    }
    final stage = File('${file.path}.stage');
    stage.writeAsBytesSync(bytes, flush: true);
    stage.renameSync(file.path);
  }

  Uint8List readCas(String hash) {
    if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(hash)) {
      throw const StudioException('INVALID_HASH');
    }
    final file = File(_casPath(hash));
    if (!file.existsSync()) {
      throw const StudioException('RESOURCE_MISSING');
    }
    final bytes = file.readAsBytesSync();
    if (rawBytesHash(bytes) != hash) {
      throw const StudioException('CAS_CORRUPT');
    }
    return bytes;
  }

  bool hasCas(String hash) => File(_casPath(hash)).existsSync();

  String _casPath(String hash) {
    final hex = hash.substring('sha256:'.length);
    return p.join(root, 'cas', hex);
  }
}

String sha256Bytes(List<int> bytes) => 'sha256:${sha256.convert(bytes)}';

bool sqliteHasFts5(Database db) {
  final options = db.select('PRAGMA compile_options');
  return options.any((row) => (row.values.first as String).contains('FTS5'));
}

/// Apply official T57_LIBRARY_DDL in a transaction already begun by the
/// caller. The `craft_fts` virtual table is part of the frozen official text
/// but is skipped when this approved SQLite build has no FTS5 module.
void applyT57LibraryDdl(Database db) {
  final enableFts5 = sqliteHasFts5(db);
  for (final statement in officialT57Statements) {
    final trimmed = statement.trim();
    if (trimmed.isEmpty || trimmed.startsWith('--')) {
      continue;
    }
    final isCraftFts = trimmed.toUpperCase().startsWith(
      'CREATE VIRTUAL TABLE CRAFT_FTS',
    );
    if (isCraftFts && !enableFts5) {
      continue;
    }
    db.execute(statement);
  }
}

/// Individual official statements, including comment lines, in file order.
final officialT57Statements = splitOfficialSql(t57LibraryDdl);

List<String> splitOfficialSql(String sql) {
  final statements = <String>[];
  final buffer = StringBuffer();
  for (final line in sql.split('\n')) {
    if (line.trim().startsWith('--') && buffer.isEmpty) {
      statements.add(line);
      continue;
    }
    buffer.writeln(line);
    if (line.trim().endsWith(';')) {
      statements.add(buffer.toString());
      buffer.clear();
    }
  }
  if (buffer.isNotEmpty) {
    statements.add(buffer.toString());
  }
  return statements;
}
