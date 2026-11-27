import 'package:sqlite3/sqlite3.dart';

/// Official graphics-library/1 DDL from store/graphics_library.sql.
/// This is a private library document, not a Project 2.0 schema change.
const officialGraphicsLibraryDdl = r'''-- additive graphics-library/1，私有库而非可移植Project新增表。
-- workspace_features hosts the official feature row; it is not a Project 2.0 table.
CREATE TABLE workspace_features(
  name TEXT NOT NULL PRIMARY KEY,
  version TEXT NOT NULL,
  document TEXT NOT NULL
);
INSERT INTO workspace_features VALUES('graphics_library','1.0.0','graphics-library/1');
CREATE TABLE graphic_versions(ns TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind IN ('graphic','template')),
 id TEXT NOT NULL,version TEXT NOT NULL,body_hash TEXT NOT NULL,
 PRIMARY KEY(ns,kind,id,version));
CREATE TRIGGER graphic_version_no_update BEFORE UPDATE ON graphic_versions
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_GRAPHIC_VERSION'); END;
CREATE TRIGGER graphic_version_no_replace BEFORE INSERT ON graphic_versions
 WHEN EXISTS(SELECT 1 FROM graphic_versions WHERE ns=NEW.ns AND kind=NEW.kind AND id=NEW.id AND version=NEW.version)
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_GRAPHIC_VERSION'); END;
CREATE TABLE graphic_heads(ns TEXT NOT NULL,kind TEXT NOT NULL,id TEXT NOT NULL,version TEXT NOT NULL,
 PRIMARY KEY(ns,kind,id),FOREIGN KEY(ns,kind,id,version) REFERENCES graphic_versions(ns,kind,id,version));
-- studio.graphics-library.v1 pin index. Project pins follow this sidecar
-- manifest and are not mutable template content or Project 2.0 root fields.
CREATE TABLE graphics_library_pins(
  project_id TEXT NOT NULL,
  ns TEXT NOT NULL,
  kind TEXT NOT NULL,
  id TEXT NOT NULL,
  version TEXT NOT NULL,
  hash TEXT NOT NULL,
  PRIMARY KEY(project_id, ns, kind, id),
  FOREIGN KEY(ns,kind,id,version) REFERENCES graphic_versions(ns,kind,id,version)
);
CREATE TABLE graphic_rights(
  rights_id TEXT NOT NULL PRIMARY KEY,
  epoch TEXT NOT NULL,
  allowed_uses TEXT NOT NULL,
  redistributable INTEGER NOT NULL CHECK(redistributable IN (0,1))
);
CREATE TABLE graphics_library_trash(
  ns TEXT NOT NULL,
  kind TEXT NOT NULL,
  id TEXT NOT NULL,
  version TEXT NOT NULL,
  trashed_at TEXT NOT NULL,
  PRIMARY KEY(ns,kind,id,version)
);
''';

const officialGraphicsLibraryStatements = <String>[
    r'''CREATE TABLE workspace_features(
  name TEXT NOT NULL PRIMARY KEY,
  version TEXT NOT NULL,
  document TEXT NOT NULL
)''',
    r'''INSERT INTO workspace_features VALUES('graphics_library','1.0.0','graphics-library/1')''',
    r'''CREATE TABLE graphic_versions(ns TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind IN ('graphic','template')),
 id TEXT NOT NULL,version TEXT NOT NULL,body_hash TEXT NOT NULL,
 PRIMARY KEY(ns,kind,id,version))''',
    r'''CREATE TRIGGER graphic_version_no_update BEFORE UPDATE ON graphic_versions
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_GRAPHIC_VERSION'); END''',
    r'''CREATE TRIGGER graphic_version_no_replace BEFORE INSERT ON graphic_versions
 WHEN EXISTS(SELECT 1 FROM graphic_versions WHERE ns=NEW.ns AND kind=NEW.kind AND id=NEW.id AND version=NEW.version)
 BEGIN SELECT RAISE(ABORT,'IMMUTABLE_GRAPHIC_VERSION'); END''',
    r'''CREATE TABLE graphic_heads(ns TEXT NOT NULL,kind TEXT NOT NULL,id TEXT NOT NULL,version TEXT NOT NULL,
 PRIMARY KEY(ns,kind,id),FOREIGN KEY(ns,kind,id,version) REFERENCES graphic_versions(ns,kind,id,version))''',
    r'''CREATE TABLE graphics_library_pins(
  project_id TEXT NOT NULL,
  ns TEXT NOT NULL,
  kind TEXT NOT NULL,
  id TEXT NOT NULL,
  version TEXT NOT NULL,
  hash TEXT NOT NULL,
  PRIMARY KEY(project_id, ns, kind, id),
  FOREIGN KEY(ns,kind,id,version) REFERENCES graphic_versions(ns,kind,id,version)
)''',
    r'''CREATE TABLE graphic_rights(
  rights_id TEXT NOT NULL PRIMARY KEY,
  epoch TEXT NOT NULL,
  allowed_uses TEXT NOT NULL,
  redistributable INTEGER NOT NULL CHECK(redistributable IN (0,1))
)''',
    r'''CREATE TABLE graphics_library_trash(
  ns TEXT NOT NULL,
  kind TEXT NOT NULL,
  id TEXT NOT NULL,
  version TEXT NOT NULL,
  trashed_at TEXT NOT NULL,
  PRIMARY KEY(ns,kind,id,version)
)''',
];

void applyOfficialGraphicsLibraryDdl(Database db) {
  for (final stmt in officialGraphicsLibraryStatements) {
    db.execute(stmt);
  }
}
