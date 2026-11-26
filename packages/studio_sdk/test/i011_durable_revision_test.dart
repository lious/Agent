import 'dart:io';

import 'package:studio_sdk/save_coordinator.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:studio_store/studio_store.dart';
import 'package:test/test.dart';

/// Increment 1.90 official I-011 remainingAcceptance clause
/// 「durableRevision不虚报」 on the already-admitted save journal.
/// This file does not rewrite save_test.dart or save_crash_test.dart.
BigInt durableRevision(PersistenceView view) => view.headRevision;

void main() {
  late Directory dir;
  late DocumentRepository repo;
  late BlobStore blobs;
  late WriterToken writer;
  late ProjectDocument before;
  late File target;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('i011-durable-save-');
    final ns = Namespace('test', 'local', 'durable-rev');
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

  test('a failed or unacked save does not report durableRevision ahead of the acknowledged head', () async {
    final start = repo.persistenceView('p');
    expect(durableRevision(start), BigInt.zero);
    expect(start.userSavedRevision, isNull);
    final failing = SaveCoordinator(
      repo,
      blobs,
      onPhase: (phase, _) {
        if (phase == 'verifying') {
          throw StateError('injected after real stage write');
        }
      },
    );
    await expectLater(
      failing.request(writer, before, target).result,
      throwsStateError,
    );
    final afterFail = repo.persistenceView('p', targetPath: target.path);
    expect(durableRevision(afterFail), BigInt.zero);
    expect(afterFail.headRevision, BigInt.zero);
    expect(afterFail.userSavedRevision, isNull);
    expect(repo.read('p')!.revision, BigInt.zero);
    expect(repo.read('p')!.title, 'before');

    await SaveCoordinator(repo, blobs).request(writer, before, target).result;
    final saved = repo.persistenceView('p', targetPath: target.path);
    expect(durableRevision(saved), BigInt.zero);
    expect(saved.userSavedRevision, BigInt.zero);
    expect(saved.targetSavedRevision, BigInt.zero);

    repo.rename(
      writer: writer,
      commandId: 'c1',
      receiptKey: 'r1',
      expectedRevision: BigInt.zero,
      title: 'after',
    );
    final edited = repo.persistenceView('p', targetPath: target.path);
    expect(durableRevision(edited), BigInt.one);
    // A later head does not rewrite the last receipt into a false durable value.
    expect(edited.userSavedRevision, BigInt.zero);
    expect(edited.targetSavedRevision, BigInt.zero);
    expect(edited.packageBehind, isTrue);
    expect(repo.read('p')!.revision, BigInt.one);
  });
}
