import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/blob_store.dart';

void main() {
  test('REAL SDK video proxies, named checkpoint/undo/archive/reopen survive explicit index pruning; shared DB refuses', () async {
    final dir = Directory.systemTemp.createTempSync('retention-sdk-');
    StudioWorkspace open([String file = 'db']) => StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/$file',
      tenantId: 'local',
      workspaceId: 'retention',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    var w = open();
    StudioWorkspace? other;
    try {
      w.openDemo();
      await w.importVideo(
        LocalFileGrant.fromUserSelection(
          File(Platform.environment['STUDIO_TEST_VIDEO']!),
        ),
        expectedRevision: w.current.revision,
      );
      await w.buildTimelinePreviewProxies();
      w.flushCheckpoint();
      await w.nameCurrentCheckpoint(
        'Media',
        expectedRevision: w.current.revision,
      );
      final store = BlobStore(
        Directory('${dir.path}/media'),
        w.current.namespace,
      );
      final originalFiles = {
        for (final f in store.directory.listSync().whereType<File>().where(
          (f) => RegExp(r'[a-f0-9]{64}$').hasMatch(f.path),
        ))
          f.path: await f.readAsBytes(),
      };
      expect(originalFiles, isNotEmpty);
      for (var i = 0; i < 4; i++) {
        w.rename('Edit$i', expectedRevision: w.current.revision);
        w.flushCheckpoint();
      }
      expect((await w.reviewCheckpointRetention())['candidates'], isEmpty);
      await w.configureCheckpointRetention(1, confirmed: true);
      final review = await w.reviewCheckpointRetention(), before = w.current;
      expect(review['candidates'], isNotEmpty);
      final audit = await w.applyCheckpointRetention(
        reviewHash: review['reviewHash'],
        expectedRevision: before.revision,
        confirmed: true,
      );
      expect(audit['removedCheckpointIds'], isNotEmpty);
      expect(w.current.hash, before.hash);
      expect(w.checkpointRetentionAuditHistory(), hasLength(1));
      for (final entry in originalFiles.entries) {
        expect(await File(entry.key).readAsBytes(), entry.value);
      }
      w.undo(expectedRevision: w.current.revision);
      expect(w.current.toJson()['title'], 'Edit2');
      await w.saveArchive(File('${dir.path}/project.zip'));
      w.close();
      w = open();
      w.openDemo();
      expect((await w.reviewCheckpointRetention())['policy']['keepLatest'], 1);
      final restored = await w.restoreArchive(
        LocalFileGrant.fromUserSelection(File('${dir.path}/project.zip')),
      );
      expect(restored.toJson()['assets'][0]['proxyRefs'], isNotEmpty);
      expect((await w.buildTimelinePreviewProxies())['built'], 0);
      other = open('shared-db');
      other.openDemo();
      await expectLater(
        w.configureCheckpointRetention(1, confirmed: true),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'PROXY_REPAIR_STORAGE_SHARED',
          ),
        ),
      );
    } finally {
      other?.close();
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
}
