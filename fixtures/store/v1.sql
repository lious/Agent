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
