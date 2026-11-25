import 'dart:convert';
import 'dart:io';

import 'package:studio_store/studio_store.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:studio_sdk/save_coordinator.dart';
import 'package:test/test.dart';

void main() {
  for (final phase in [
    'preparing',
    'verifying',
    'publishing',
    'published',
    'committed',
  ]) {
    test(
      'real SIGKILL at $phase, 10 repeats: acknowledged head survives; file is old/new verified snapshot',
      () async {
        for (var i = 0; i < 10; i++) {
          final dir = Directory.systemTemp.createTempSync('save-kill-$phase-');
          Process? process;
          try {
            process = await Process.start(Platform.resolvedExecutable, [
              'run',
              'packages/studio_sdk/test/workers/save_crash_worker.dart',
              dir.path,
              phase,
            ]);
            final errors = StringBuffer();
            final stderr = process.stderr
                .transform(utf8.decoder)
                .listen(errors.write);
            final barrier = await process.stdout
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .firstWhere((line) => line.startsWith('BARRIER:'))
                .timeout(const Duration(seconds: 15));
            final id = barrier.substring(8);
            expect(process.kill(ProcessSignal.sigkill), true);
            expect(await process.exitCode, isNot(0));
            await stderr.cancel();
            final ns = Namespace('crash', 'local', 'ws'),
                repo = DocumentRepository.open(
                  '${dir.path}/db.sqlite',
                  Namespace('crash', 'local', 'ws'),
                );
            try {
              final p = repo.read('p')!;
              expect(p.title, 'after');
              expect(p.revision, BigInt.one);
              expect(repo.persistenceView('p').checkpointRevision, BigInt.one);
              final target = File('${dir.path}/good.archive'),
                  actual = ProjectArchive().open(target).project;
              final published = ['published', 'committed'].contains(phase);
              expect(actual.title, published ? 'after' : 'before');
              final writer = repo.acquireWriter(
                    'p',
                    'parent',
                    expectedEpoch: 1,
                  ),
                  coordinator = SaveCoordinator(
                    repo,
                    BlobStore(Directory('${dir.path}/media'), ns),
                  );
              if (phase == 'published') {
                expect(repo.persistenceView('p').userSavedRevision, isNull);
                await coordinator.reconcile(
                  writer,
                  id,
                  LocalFileGrant.fromUserSelection(target),
                );
                expect(repo.persistenceView('p').userSavedRevision, BigInt.one);
              }
              if (phase == 'publishing') {
                await expectLater(
                  coordinator.reconcile(
                    writer,
                    id,
                    LocalFileGrant.fromUserSelection(target),
                  ),
                  throwsA(isA<StudioException>()),
                );
                expect(ProjectArchive().open(target).project.title, 'before');
              }
              if (phase == 'committed') {
                expect(repo.persistenceView('p').userSavedRevision, BigInt.one);
              }
            } finally {
              repo.close();
            }
          } finally {
            process?.kill(ProcessSignal.sigkill);
            dir.deleteSync(recursive: true);
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
