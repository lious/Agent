import 'dart:io';
import 'dart:convert';

import 'package:studio_store/studio_store.dart';
import 'package:studio_store/blob_store.dart';

Future<void> main(List<String> args) async {
  final input =
      jsonDecode(File(args.single).readAsStringSync()) as Map<String, dynamic>;
  final ns = Namespace(
    input['ns']['appId'],
    input['ns']['tenantId'],
    input['ns']['workspaceId'],
  );
  final repo = DocumentRepository.open(input['db'], ns);
  final store = BlobStore(Directory(input['media']), ns);
  final project = repo.read(input['project'])!;
  final writer = repo.acquireWriter(
    project.projectId,
    'synthetic-interruption-child',
    expectedEpoch: repo.writerEpoch(project.projectId),
  );
  try {
    await store.withMaintenanceLease(() async {
      repo.withExclusivePreviewRepair(
        writer: writer,
        expectedRevision: project.revision,
        expectedSnapshot: project.hash,
        sourceHash: input['source'],
        roles: Map<String, String>.from(input['roles']),
        publish: () => store.repairPreviewStagesSync(
          {
            for (final e in (input['stages'] as Map).entries)
              e.key as String: File(e.value as String),
          },
          {'syntheticFixture': true, 'snapshotHash': project.hash},
          databasePath: input['db'],
          onPhase: (phase) {
            if (phase == 'published:1') {
              File('/dev/stdout').writeAsStringSync(
                'FIRST_OBJECT_DURABLE\n',
                mode: FileMode.writeOnly,
              );
              stdin.readByteSync(); // parent SIGKILL; genuine file/SQLite locks held
            }
          },
        ),
      );
    });
  } finally {
    repo.close();
  }
}
