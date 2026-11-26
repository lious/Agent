import 'dart:io';

import 'package:studio_document/studio_document.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

/// Increment 1.91 official I-012 remainingAcceptance clause
/// 「head继续编辑不伪改userSavedRevision」. userSavedRevision is the
/// latest explicit save receipt's checkpoint revision, not head.
/// Continued edits must not rewrite that receipt into the new head.
/// This file does not rewrite save_test.dart, save_crash_test.dart,
/// files_test.dart, or the Increment 1.90 durableRevision suites.
Namespace get ns => Namespace('studio', 'local', 'user-saved-rev');

ProjectDocument empty() =>
    ProjectDocument.empty(namespace: ns, projectId: 'p1', title: 'Before');

void main() {
  late Directory dir;
  late String path;
  late DocumentRepository repo;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('i012-user-saved-');
    path = '${dir.path}/workspace.sqlite';
    repo = DocumentRepository.open(path, ns);
    repo.create(empty());
  });
  tearDown(() {
    repo.close();
    dir.deleteSync(recursive: true);
  });

  test('continued head edits after saveManaged leave userSavedRevision at the receipt revision', () {
    final writer = repo.acquireWriter('p1', 'owner', expectedEpoch: 0);
    expect(repo.persistenceView('p1').userSavedRevision, isNull);
    expect(repo.saveManaged(writer), BigInt.zero);
    final saved = repo.persistenceView('p1');
    expect(saved.userSavedRevision, BigInt.zero);
    expect(saved.headRevision, BigInt.zero);

    repo.rename(
      writer: writer,
      commandId: 'c1',
      receiptKey: 'r1',
      expectedRevision: BigInt.zero,
      title: 'After',
    );
    final edited = repo.persistenceView('p1');
    expect(edited.headRevision, BigInt.one);
    expect(edited.userSavedRevision, BigInt.zero);
    expect(repo.read('p1')!.title, 'After');

    repo.close();
    repo = DocumentRepository.open(path, ns);
    final reopened = repo.persistenceView('p1');
    expect(reopened.headRevision, BigInt.one);
    expect(reopened.userSavedRevision, BigInt.zero);
    expect(repo.read('p1')!.title, 'After');
  });
}
