import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

/// Increment 1.90 official I-011 remainingAcceptance clause
/// 「durableRevision不虚报」. Official durableRevision is the derived
/// PersistenceView.headRevision (spec s5b): it equals the last ACK'd
/// project_heads.revision and is not a stored counter. This file does
/// not rewrite save_test.dart, save_crash_test.dart, or files_test.dart.
Namespace get ns => Namespace('studio', 'local', 'durable-rev');

BigInt durableRevision(PersistenceView view) => view.headRevision;

ProjectDocument empty() =>
    ProjectDocument.empty(namespace: ns, projectId: 'p1', title: 'Before');

Set<String> columnNames(Database db) {
  final names = <String>{};
  final tables = db.select(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
  );
  for (final table in tables) {
    final cols = db.select('PRAGMA table_info(${table['name']})');
    for (final col in cols) {
      names.add((col['name'] as String).toLowerCase());
    }
  }
  return names;
}

void main() {
  late Directory dir;
  late String path;
  late DocumentRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i011-durable-');
    path = '${dir.path}/workspace.sqlite';
    repo = DocumentRepository.open(path, ns);
    repo.create(empty());
  });
  tearDown(() {
    repo.close();
    dir.deleteSync(recursive: true);
  });

  test(
    'durableRevision is the derived headRevision and is not a stored column',
    () {
      final db = sqlite3.open(path);
      final columns = columnNames(db);
      db.dispose();
      expect(
        columns.intersection({
          'durablerevision',
          'dirty',
          'usersavedrevision',
          'snapshotrevision',
        }),
        isEmpty,
      );
      expect(columns, contains('revision'));
      final view = repo.persistenceView('p1');
      expect(durableRevision(view), BigInt.zero);
      expect(durableRevision(view), view.headRevision);
      expect(durableRevision(view), repo.read('p1')!.revision);
    },
  );

  test('reopen reports the last acknowledged head as durableRevision and does not invent a later value', () {
    final writer = repo.acquireWriter('p1', 'owner', expectedEpoch: 0);
    repo.rename(
      writer: writer,
      commandId: 'c1',
      receiptKey: 'r1',
      expectedRevision: BigInt.zero,
      title: 'After',
    );
    expect(durableRevision(repo.persistenceView('p1')), BigInt.one);
    expect(repo.read('p1')!.title, 'After');
    repo.close();
    repo = DocumentRepository.open(path, ns);
    final view = repo.persistenceView('p1');
    expect(durableRevision(view), BigInt.one);
    expect(view.headRevision, BigInt.one);
    expect(repo.read('p1')!.revision, BigInt.one);
    expect(repo.read('p1')!.title, 'After');
    final db = sqlite3.open(path);
    final head = db.select(
      'SELECT revision FROM project_heads WHERE project_id=?',
      ['p1'],
    ).single;
    db.dispose();
    expect(BigInt.from(head['revision'] as int), BigInt.one);
    expect(durableRevision(view), BigInt.from(head['revision'] as int));
  });
}
