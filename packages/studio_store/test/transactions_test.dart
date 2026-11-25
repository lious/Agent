import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Namespace get ns => Namespace('studio', 'local', 'ws');
Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));
ProjectDocument empty(Namespace scope) =>
    ProjectDocument.empty(namespace: scope, projectId: 'p1', title: 'Before');

/// Ten independent SQLite connections start together; 100 commands share revision0.
Future<void> competingWriter((String, SendPort) input) async {
  final (path, reply) = input;
  final gate = ReceivePort();
  reply.send(gate.sendPort);
  final worker = (await gate.first) as int;
  gate.close();
  final repo = DocumentRepository.open(path, ns);
  var won = 0, conflicts = 0;
  final errors = <String>[];
  try {
    for (var i = 0; i < 10; i++) {
      try {
        repo.rename(
          writer: WriterToken(ns, 'p1', 'owner', 1),
          commandId: 'c$worker-$i',
          receiptKey: 'r$worker-$i',
          expectedRevision: BigInt.zero,
          title: 'Worker$worker-$i',
        );
        won++;
      } on StudioException catch (e) {
        if (e.code == 'REVISION_CONFLICT') {
          conflicts++;
        } else {
          errors.add(e.toString());
        }
      }
    }
  } finally {
    repo.close();
  }
  reply.send([won, conflicts, errors]);
}

void main() {
  late Directory dir;
  late String path;
  late DocumentRepository repo;
  late WriterToken writer;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('studio-store-test-');
    path = '${dir.path}/workspace.sqlite';
    repo = DocumentRepository.open(path, ns);
    repo.create(empty(ns));
    writer = repo.acquireWriter('p1', 'owner', expectedEpoch: 0);
  });
  tearDown(() {
    repo.close();
    dir.deleteSync(recursive: true);
  });
  CommitReceipt rename({
    String id = 'c1',
    String key = 'r1',
    String title = 'After',
    int revision = 0,
  }) => repo.rename(
    writer: writer,
    commandId: id,
    receiptKey: key,
    expectedRevision: BigInt.from(revision),
    title: title,
  );

  test('migration, commit, reopen, checksum and foreign key enforcement', () {
    final receipt = rename();
    expect(receipt.revision, BigInt.one);
    expect(receipt.toJson()['eventSeq'], '1');
    repo.close();
    repo = DocumentRepository.open(path, ns);
    expect(repo.read('p1')!.title, 'After');
    expect(repo.read('p1')!.revision, BigInt.one);
    final db = sqlite3.open(path);
    addTearDown(db.dispose);
    expect(db.userVersion, 3);
    expect(db.select('PRAGMA integrity_check').single.values.single, 'ok');
    expect(db.select('PRAGMA foreign_key_check'), isEmpty);
    expect(db.select('SELECT count(*) AS n FROM revisions').single['n'], 1);
    expect(db.select('SELECT count(*) AS n FROM outbox').single['n'], 1);
  });
  test(
    'same key same input returns original receipt even after a new writer',
    () {
      final first = rename().toJson();
      writer = repo.acquireWriter('p1', 'new-owner', expectedEpoch: 1);
      expect(rename().toJson(), first);
      expect(repo.read('p1')!.revision, BigInt.one);
      expect(() => rename(title: 'Different'), code('IDEMPOTENCY_KEY_REUSED'));
      expect(
        () => rename(key: 'new-key', revision: 1),
        code('COMMAND_ID_REUSED'),
      );
    },
  );
  test(
    'no-op records only receipt, retains revision, images and event tail',
    () {
      final first = rename(title: 'Before').toJson();
      expect(first['disposition'], 'noDocumentChange');
      expect(first['revision'], '0');
      expect(first['eventSeq'], '0');
      expect(first['inversePatchRef'], null);
      expect(first['beforeImageRef'], first['afterImageRef']);
      final db = sqlite3.open(path);
      addTearDown(db.dispose);
      for (final table in ['commands', 'revisions', 'events', 'outbox']) {
        expect(
          db.select('SELECT count(*) AS n FROM $table').single['n'],
          0,
          reason: table,
        );
      }
      expect(() => rename(key: 'r2'), code('COMMAND_ID_REUSED'));
    },
  );
  test(
    'undo restores content in a NEW revision, stale undo cannot overwrite',
    () {
      final before = repo.read('p1')!.toJson()..remove('revision');
      rename();
      final receipt = repo.undoLatest(
        writer: writer,
        commandId: 'undo1',
        receiptKey: 'u1',
        expectedRevision: BigInt.one,
        targetCommandId: 'c1',
      );
      expect(receipt.revision, BigInt.two);
      expect(repo.read('p1')!.toJson()..remove('revision'), before);
      expect(
        () => repo.undoLatest(
          writer: writer,
          commandId: 'undo2',
          receiptKey: 'u2',
          expectedRevision: BigInt.two,
          targetCommandId: 'c1',
        ),
        code('UNDO_CONFLICT'),
      );
    },
  );
  test('fence transfer invalidates old writer and expected epoch CAS', () {
    repo.acquireWriter('p1', 'owner2', expectedEpoch: 1);
    expect(() => rename(), code('WRITER_FENCED'));
    expect(
      () => repo.acquireWriter('p1', 'owner3', expectedEpoch: 1),
      code('WRITER_FENCE_CONFLICT'),
    );
    expect(repo.read('p1')!.revision, BigInt.zero);
  });
  test('SQL failure after event append rolls back EVERY write', () {
    final db = sqlite3.open(path);
    addTearDown(db.dispose);
    db.execute(
      "CREATE TRIGGER injected_failure BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'fault'); END",
    );
    expect(() => rename(), throwsA(isA<SqliteException>()));
    expect(repo.read('p1')!.title, 'Before');
    expect(repo.read('p1')!.revision, BigInt.zero);
    for (final table in [
      'commands',
      'revisions',
      'events',
      'receipts',
      'outbox',
    ]) {
      expect(
        db.select('SELECT count(*) AS n FROM $table').single['n'],
        0,
        reason: table,
      );
    }
    expect(
      db.select('SELECT next_seq FROM stream_heads').single['next_seq'],
      1,
    );
    expect(db.select('SELECT count(*) AS n FROM snapshots').single['n'], 1);
    db.execute('DROP TRIGGER injected_failure');
    expect(rename().revision, BigInt.one);
  });
  test(
    'invalid title, project namespace and duplicate create are rejected',
    () {
      expect(() => rename(title: ''), code('SCHEMA_SIZE'));
      expect(repo.read('p1')!.revision, BigInt.zero);
      expect(
        () => repo.create(empty(Namespace('image', 'local', 'ws'))),
        code('NAMESPACE_MISMATCH'),
      );
      expect(() => repo.create(empty(ns)), code('PROJECT_EXISTS'));
      expect(() => repo.read('../p'), code('INVALID_ID'));
    },
  );
  test(
    'dual hosts, tenants and workspaces cannot read each other through APIs',
    () {
      repo.createSession('session', 'Private');
      final bytes = Uint8List.fromList(utf8.encode('same fixture'));
      final hash = repo.putFixtureBytes(bytes);
      for (final other in [
        Namespace('image', 'local', 'ws'),
        Namespace('studio', 'other', 'ws'),
        Namespace('studio', 'local', 'other'),
      ]) {
        final b = DocumentRepository.open(path, other);
        try {
          expect(b.read('p1'), null);
          expect(b.sessionTitle('session'), null);
          expect(b.fixtureBytes(hash), null);
          expect(
            () => b.rename(
              writer: writer,
              commandId: 'x',
              receiptKey: 'y',
              expectedRevision: BigInt.zero,
              title: 'X',
            ),
            code('NAMESPACE_MISMATCH'),
          );
          b.create(empty(other));
          b.createSession('session', 'Other');
          expect(b.putFixtureBytes(bytes), hash);
          expect(b.fixtureBytes(hash), bytes);
          expect(repo.sessionTitle('session'), 'Private');
        } finally {
          b.close();
        }
      }
      final copy = repo.fixtureBytes(hash)!;
      copy[0] = 0;
      expect(repo.fixtureBytes(hash), bytes);
    },
  );
  test(
    'real 100 competing commands on 10 isolates: exactly one CAS succeeds',
    () async {
      final replies = ReceivePort();
      final ports = <SendPort>[];
      final results = <List>[];
      for (var i = 0; i < 10; i++) {
        await Isolate.spawn(competingWriter, (path, replies.sendPort));
      }
      await for (final message in replies) {
        if (message is SendPort) {
          ports.add(message);
          if (ports.length == 10) {
            for (var i = 0; i < ports.length; i++) {
              ports[i].send(i);
            }
          }
        } else {
          results.add(message as List);
          if (results.length == 10) {
            replies.close();
            break;
          }
        }
      }
      expect(results.expand((r) => r[2] as List), isEmpty);
      expect(results.fold<int>(0, (n, r) => n + (r[0] as int)), 1);
      expect(results.fold<int>(0, (n, r) => n + (r[1] as int)), 99);
      expect(repo.read('p1')!.revision, BigInt.one);
    },
    timeout: Timeout(Duration(seconds: 90)),
  );
  test('unknown schema version refuses without modifying it', () {
    final futurePath = '${dir.path}/future.sqlite';
    final db = sqlite3.open(futurePath);
    db.userVersion = 99;
    db.dispose();
    expect(
      () => DocumentRepository.open(futurePath, ns),
      code('STORE_VERSION_UNSUPPORTED'),
    );
    final check = sqlite3.open(futurePath);
    expect(check.userVersion, 99);
    check.dispose();
  });
  test('migration checksum mismatch fails closed', () {
    final bad = '${dir.path}/bad.sqlite';
    final original = DocumentRepository.open(bad, ns);
    original.close();
    final db = sqlite3.open(bad);
    db.execute("UPDATE schema_migrations SET checksum='bad'");
    db.dispose();
    expect(
      () => DocumentRepository.open(bad, ns),
      code('MIGRATION_CHECKSUM_MISMATCH'),
    );
  });
  test('stored snapshot tampering is detected on read', () {
    final db = sqlite3.open(path);
    addTearDown(db.dispose);
    final row = db.select('SELECT hash,json FROM snapshots').single;
    final json = jsonDecode(row['json'] as String) as Map<String, dynamic>;
    json['title'] = 'tampered';
    db.execute('UPDATE snapshots SET json=? WHERE hash=?', [
      jsonEncode(json),
      row['hash'],
    ]);
    expect(() => repo.read('p1'), code('STORE_INTEGRITY'));
  });
  test(
    'writer tokens cannot cross namespaces even with identical owner/epoch',
    () {
      final otherNs = Namespace('image', 'local', 'ws');
      final other = DocumentRepository.open(path, otherNs);
      try {
        other.create(empty(otherNs));
        final otherToken = other.acquireWriter('p1', 'owner', expectedEpoch: 0);
        expect(
          () => repo.rename(
            writer: otherToken,
            commandId: 'cross',
            receiptKey: 'cross',
            expectedRevision: BigInt.zero,
            title: 'bad',
          ),
          code('NAMESPACE_MISMATCH'),
        );
        expect(
          () => other.rename(
            writer: writer,
            commandId: 'cross',
            receiptKey: 'cross',
            expectedRevision: BigInt.zero,
            title: 'bad',
          ),
          code('NAMESPACE_MISMATCH'),
        );
        expect(other.read('p1')!.revision, BigInt.zero);
      } finally {
        other.close();
      }
    },
  );
  test('fixture blob corruption is detected', () {
    final hash = repo.putFixtureBytes(Uint8List.fromList([1, 2, 3]));
    final db = sqlite3.open(path);
    try {
      db.execute('UPDATE immutable_blobs SET bytes=? WHERE hash=?', [
        Uint8List.fromList([9]),
        hash,
      ]);
      expect(() => repo.fixtureBytes(hash), code('STORE_INTEGRITY'));
    } finally {
      db.dispose();
    }
  });
  test(
    'missing referenced snapshot is corruption, never an absent project',
    () {
      final db = sqlite3.open(path);
      try {
        db.execute('PRAGMA foreign_keys=OFF');
        db.execute('DELETE FROM snapshots');
        expect(() => repo.read('p1'), code('STORE_INTEGRITY'));
      } finally {
        db.dispose();
      }
    },
  );
  test('failed first migration preserves original database and version', () {
    final bad = '${dir.path}/collision.sqlite';
    final db = sqlite3.open(bad);
    try {
      db.execute('CREATE TABLE snapshots(original TEXT)');
      db.execute("INSERT INTO snapshots VALUES('keep')");
      expect(
        () => DocumentRepository.open(bad, ns),
        throwsA(isA<SqliteException>()),
      );
      expect(db.userVersion, 0);
      expect(
        db.select('SELECT original FROM snapshots').single['original'],
        'keep',
      );
      expect(
        db.select(
          "SELECT name FROM sqlite_master WHERE name='schema_migrations'",
        ),
        isEmpty,
      );
    } finally {
      db.dispose();
    }
  });
  test('undo verifies historical before-image hash, not just current head', () {
    final beforeHash = repo.read('p1')!.hash;
    rename();
    final db = sqlite3.open(path);
    try {
      final historical = empty(ns).toJson()..['title'] = 'tampered history';
      db.execute('UPDATE snapshots SET json=? WHERE hash=?', [
        jsonEncode(historical),
        beforeHash,
      ]);
      expect(
        () => repo.undoLatest(
          writer: writer,
          commandId: 'u-corrupt',
          receiptKey: 'u-corrupt',
          expectedRevision: BigInt.one,
          targetCommandId: 'c1',
        ),
        code('STORE_INTEGRITY'),
      );
      expect(repo.read('p1')!.revision, BigInt.one);
    } finally {
      db.dispose();
    }
  });
}
