import 'dart:io';

import 'package:studio_sdk/save_coordinator.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

/// Increment 1.91 official I-012 remainingAcceptance clause
/// 「head继续编辑不伪改userSavedRevision」 on the already-admitted
/// save journal. This file does not rewrite save_test.dart,
/// save_crash_test.dart, files_test.dart, or the Increment 1.90
/// durableRevision suites.
void main() {
  late Directory dir;
  late DocumentRepository repo;
  late BlobStore blobs;
  late WriterToken writer;
  late ProjectDocument before;
  late File target;
  var command = 0;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('i012-user-saved-save-');
    final ns = Namespace('test', 'local', 'user-saved-rev');
    repo = DocumentRepository.open('${dir.path}/db.sqlite', ns);
    before = ProjectDocument.empty(
      namespace: ns,
      projectId: 'p',
      title: 'before',
    );
    repo.create(before);
    writer = repo.acquireWriter('p', 'owner', expectedEpoch: 0);
    blobs = BlobStore(Directory('${dir.path}/media'), ns);
    target = File('${dir.path}/good.archive');
    await ProjectArchive().save(before, blobs, target);
  });
  tearDown(() {
    repo.close();
    dir.deleteSync(recursive: true);
  });

  void rename(String title) {
    final id = 'rename-${command++}';
    repo.rename(
      writer: writer,
      commandId: id,
      receiptKey: id,
      expectedRevision: repo.read('p')!.revision,
      title: title,
    );
  }

  test('an in-flight explicit archive of a frozen snapshot does not rewrite userSavedRevision to a later head', () async {
    expect(repo.persistenceView('p').userSavedRevision, isNull);
    final handle = SaveCoordinator(
      repo,
      blobs,
      onPhase: (phase, _) {
        if (phase == 'verifying') {
          expect(
            repo
                .persistenceView('p', targetPath: target.absolute.path)
                .userSavedRevision,
            isNull,
          );
          rename('during-save');
          expect(repo.read('p')!.revision, BigInt.one);
          final mid = repo.persistenceView(
            'p',
            targetPath: target.absolute.path,
          );
          // A later head must not invent a userSavedRevision or copy itself
          // into the last receipt while the frozen save is still in flight.
          expect(mid.headRevision, BigInt.one);
          expect(mid.userSavedRevision, isNull);
          expect(mid.targetSavedRevision, isNull);
        }
      },
    ).request(writer, before, target);
    await handle.result;
    final after = repo.persistenceView('p', targetPath: target.absolute.path);
    expect(after.headRevision, BigInt.one);
    expect(repo.read('p')!.title, 'during-save');
    // The completed receipt is the frozen snapshot, not the later head.
    expect(after.userSavedRevision, BigInt.zero);
    expect(after.targetSavedRevision, BigInt.zero);
    expect(after.packageBehind, isTrue);
    expect(ProjectArchive().open(target).project.hash, before.hash);

    rename('after-save');
    final edited = repo.persistenceView('p', targetPath: target.absolute.path);
    expect(edited.headRevision, BigInt.two);
    expect(edited.userSavedRevision, BigInt.zero);
    expect(edited.targetSavedRevision, BigInt.zero);
    expect(edited.packageBehind, isTrue);
    expect(repo.read('p')!.title, 'after-save');
  });
}
