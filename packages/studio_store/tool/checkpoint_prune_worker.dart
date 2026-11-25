// Synthetic SIGKILL qualification worker; requires caller-owned isolated fixture.
import 'dart:io';

import 'package:studio_store/studio_store.dart';
import 'package:studio_store/blob_store.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('fixture DB and fixture media root required');
  }
  final parent = File(args[0]).parent.resolveSymbolicLinksSync();
  if (!parent.startsWith(
        '${Directory.systemTemp.resolveSymbolicLinksSync()}/checkpoint-retention-',
      ) ||
      Directory(args[1]).parent.resolveSymbolicLinksSync() != parent) {
    throw ArgumentError(
      'only isolated checkpoint-retention temp fixtures allowed',
    );
  }
  final ns = Namespace('studio', 'local', 'retention'),
      repo = DocumentRepository.open(
        args[0],
        Namespace('studio', 'local', 'retention'),
      );
  final blobs = BlobStore(Directory(args[1]), ns);
  final writer = repo.acquireWriter(
    'p',
    'crash-worker',
    expectedEpoch: repo.writerEpoch('p'),
  );
  try {
    await blobs.withMaintenanceLease(() async {
      final revision = repo.read('p')!.revision,
          review = repo.reviewCheckpointPruning(
            writer,
            repo.read('p')!.revision,
          );
      var checks = 0;
      repo.applyCheckpointPruning(
        writer,
        revision,
        reviewHash: review['reviewHash'],
        confirmed: true,
        validateStorageAuthority: () {
          blobs.requireExclusiveRepairDatabase(args[0]);
          if (++checks == 2) {
            File('/dev/stdout').writeAsStringSync(
              'PRUNED_UNCOMMITTED\n',
              mode: FileMode.writeOnly,
              flush: false,
            );
            if (stdin.readByteSync() < 0) {
              throw StateError('barrier closed before SIGKILL');
            }
          }
        },
      );
    });
  } finally {
    repo.close();
  }
}
