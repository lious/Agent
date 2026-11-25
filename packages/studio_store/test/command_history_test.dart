import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

Future<void> competingUndo((String, SendPort, int) input) async {
  final ns = Namespace('history', 'local', 'fixture');
  final r = DocumentRepository.open(input.$1, ns), gate = ReceivePort();
  var result = 'unreached';
  try {
    final before = r.read('p')!, target = r.commandHistory('p').undoCommandId!;
    input.$2.send(gate.sendPort);
    await gate.first;
    gate.close();
    try {
      r.undoCommand(
        writer: WriterToken(ns, 'p', 'owner', 1),
        commandId: 'race-${input.$3}',
        receiptKey: 'race-${input.$3}',
        expectedRevision: before.revision,
        targetCommandId: target,
      );
      result = 'won';
    } on StudioException catch (e) {
      result = e.code;
    }
  } finally {
    r.close();
  }
  input.$2.send(result);
}

void main() {
  final ns = Namespace('history', 'local', 'fixture');
  late Directory dir;
  late String path;
  late DocumentRepository r;
  late WriterToken w;
  var serial = 0;
  String id() => 'command-${serial++}';
  BigInt getRevision() => r.read('p')!.revision;
  String contents() => contentHash(r.read('p')!.toJson()..remove('revision'));
  void rename(String title) {
    final c = id();
    r.rename(
      writer: w,
      commandId: c,
      receiptKey: c,
      expectedRevision: getRevision(),
      title: title,
    );
  }

  CommitReceipt undo() {
    final c = id();
    return r.undoCommand(
      writer: w,
      commandId: c,
      receiptKey: c,
      expectedRevision: getRevision(),
      targetCommandId: r.commandHistory('p').undoCommandId!,
    );
  }

  CommitReceipt redo() {
    final c = id();
    return r.redoCommand(
      writer: w,
      commandId: c,
      receiptKey: c,
      expectedRevision: getRevision(),
      undoCommandId: r.commandHistory('p').redoUndoCommandId!,
    );
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('undo-redo-');
    path = '${dir.path}/db';
    r = DocumentRepository.open(path, ns);
    r.create(
      ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'base'),
    );
    w = r.acquireWriter('p', 'owner', expectedEpoch: 0);
  });
  tearDown(() {
    r.close();
    dir.deleteSync(recursive: true);
  });
  test('persistent deep undo/redo, no-op preserves redo, branch invalidates redo without deleting journal, reopen and fencing', () {
    final hashes = [contents()];
    for (final s in ['A', 'B', 'C']) {
      rename(s);
      hashes.add(contents());
    }
    undo();
    undo();
    expect(contents(), hashes[1]);
    final redoId = r.commandHistory('p').redoUndoCommandId!;
    rename('A');
    expect(r.commandHistory('p').redoUndoCommandId, redoId);
    r.close();
    r = DocumentRepository.open(path, ns);
    expect(r.commandHistory('p').undoDepth, 1);
    redo();
    expect(contents(), hashes[2]);
    redo();
    expect(contents(), hashes[3]);
    undo();
    rename('branch');
    expect(r.commandHistory('p').redoDepth, 0);
    expect(
      () => r.redoCommand(
        writer: w,
        commandId: id(),
        receiptKey: id(),
        expectedRevision: getRevision(),
        undoCommandId: redoId,
      ),
      throwsA(isA<StudioException>()),
    );
    final other = DocumentRepository.open(path, ns);
    try {
      final old = getRevision();
      undo();
      expect(
        () => other.undoCommand(
          writer: w,
          commandId: id(),
          receiptKey: id(),
          expectedRevision: old,
          targetCommandId: 'unknown',
        ),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'REVISION_CONFLICT',
          ),
        ),
      );
      other.acquireWriter('p', 'other', expectedEpoch: w.epoch);
      expect(
        () => undo(),
        throwsA(
          isA<StudioException>().having((e) => e.code, 'code', 'WRITER_FENCED'),
        ),
      );
    } finally {
      other.close();
    }
  });
  test('late SQL failure rolls back cursor/head/events; retry exactly once; malformed journal refuses, no history swallowed', () {
    rename('A');
    rename('B');
    final before = contents(),
        revision = getRevision(),
        target = r.commandHistory('p').undoCommandId!;
    final db = sqlite3.open(path);
    try {
      db.execute(
        "CREATE TRIGGER fail_history BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'fixture');END",
      );
      final c = id();
      CommitReceipt run() => r.undoCommand(
        writer: w,
        commandId: c,
        receiptKey: c,
        expectedRevision: revision,
        targetCommandId: target,
      );
      expect(run, throwsA(isA<SqliteException>()));
      expect(contents(), before);
      expect(r.commandHistory('p').undoDepth, 2);
      db.execute('DROP TRIGGER fail_history');
      final receipt = run();
      expect(run().toJson(), receipt.toJson());
      expect(r.commandHistory('p').redoDepth, 1);
      final journal =
          db.select('SELECT payload_json FROM commands WHERE ns=? AND id=?', [
                ns.key,
                c,
              ]).single['payload_json']
              as String;
      final futurePayload = {
        'kind': 'undo',
        'historyVersion': 99,
        'targetCommandId': target,
      };
      final futureHash = contentHash({
        'projectId': 'p',
        'commandId': c,
        'expectedRevision': revision.toString(),
        'payload': futurePayload,
      });
      final originalHash = contentHash({
        'projectId': 'p',
        'commandId': c,
        'expectedRevision': revision.toString(),
        'payload': jsonDecode(journal),
      });
      db.execute(
        'UPDATE commands SET payload_json=?,input_hash=? WHERE ns=? AND id=?',
        [jsonEncode(futurePayload), futureHash, ns.key, c],
      );
      expect(
        () => r.commandHistory('p'),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'HISTORY_FORMAT_UNSUPPORTED',
          ),
        ),
      );
      db.execute('UPDATE commands SET payload_json=? WHERE ns=? AND id=?', [
        '{bad',
        ns.key,
        c,
      ]);
      expect(
        () => r.commandHistory('p'),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'HISTORY_FORMAT_UNSUPPORTED',
          ),
        ),
      );
      db.execute(
        'UPDATE commands SET payload_json=?,input_hash=? WHERE ns=? AND id=?',
        [journal, originalHash, ns.key, c],
      );
      expect(r.commandHistory('p').redoDepth, 1);
    } finally {
      db.dispose();
    }
  });
  test('legacy undoLatest transitions remain immutable and traversable, not rewritten as modern stack', () {
    rename('A');
    rename('B');
    final target = r.latestCommandId('p')!, c = id();
    r.undoLatest(
      writer: w,
      commandId: c,
      receiptKey: c,
      expectedRevision: getRevision(),
      targetCommandId: target,
    );
    expect(r.read('p')!.title, 'A');
    expect(r.commandHistory('p').undoDepth, 3);
    undo();
    expect(r.read('p')!.title, 'B');
    undo();
    expect(r.read('p')!.title, 'A');
    redo();
    expect(r.read('p')!.title, 'B');
    redo();
    expect(r.read('p')!.title, 'A');
  });
  test('actual simultaneous SQLite undo contenders publish exactly one revision/cursor transition', () async {
    rename('A');
    rename('B');
    final port = ReceivePort(), it = StreamIterator<dynamic>(port);
    for (var i = 0; i < 2; i++) {
      await Isolate.spawn(competingUndo, (path, port.sendPort, i));
    }
    final gates = <SendPort>[];
    for (var i = 0; i < 2; i++) {
      expect(await it.moveNext(), true);
      gates.add(it.current as SendPort);
    }
    for (final gate in gates) {
      gate.send(true);
    }
    final results = <String>[];
    for (var i = 0; i < 2; i++) {
      expect(await it.moveNext(), true);
      results.add(it.current as String);
    }
    await it.cancel();
    port.close();
    expect(results.where((x) => x == 'won').length, 1);
    expect(results.where((x) => x == 'REVISION_CONFLICT').length, 1);
    expect(getRevision(), BigInt.from(3));
    expect(r.commandHistory('p').undoDepth, 1);
    expect(r.commandHistory('p').redoDepth, 1);
  });
  test('1000 seeded committed edits then full undo/redo preserve exact content roots and monotonic revisions', () {
    final random = Random(251126), hashes = [contents()];
    for (var i = 0; i < 1000; i++) {
      rename('step-$i-${random.nextInt(1000000)}');
      hashes.add(contents());
    }
    for (var i = 999; i >= 0; i--) {
      undo();
      expect(contents(), hashes[i]);
    }
    expect(r.commandHistory('p').undoDepth, 0);
    expect(r.commandHistory('p').redoDepth, 1000);
    r.close();
    r = DocumentRepository.open(path, ns);
    for (var i = 1; i <= 1000; i++) {
      redo();
      expect(contents(), hashes[i]);
    }
    expect(getRevision(), BigInt.from(3000));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
