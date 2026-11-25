import 'dart:io';

import 'package:studio_document/studio_document.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:studio_sdk/save_coordinator.dart';

Future<void> main(List<String> args) async {
  final dir = Directory(args[0]),
      phase = args[1],
      ns = Namespace('crash', 'local', 'ws');
  final repo = DocumentRepository.open('${dir.path}/db.sqlite', ns),
      blobs = BlobStore(Directory('${dir.path}/media'), ns);
  final p = ProjectDocument.empty(
    namespace: ns,
    projectId: 'p',
    title: 'before',
  );
  repo.create(p);
  final writer = repo.acquireWriter('p', 'child', expectedEpoch: 0);
  final target = File('${dir.path}/good.archive');
  await ProjectArchive().save(p, blobs, target);
  repo.rename(
    writer: writer,
    commandId: 'edit',
    receiptKey: 'edit',
    expectedRevision: BigInt.zero,
    title: 'after',
  );
  final coordinator = SaveCoordinator(
    repo,
    blobs,
    onPhase: (value, id) {
      if (value == phase) {
        stdout.writeln('BARRIER:$id');
        stdin.readByteSync();
      }
    },
  );
  await coordinator.request(writer, repo.read('p')!, target).result;
  repo.close();
}
