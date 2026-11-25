import 'dart:io';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/blob_store.dart';

void main() {
  test('REAL missing proxy explicit detach/rebuild; corrupt collision refuses, source export/history/GC survive', () async {
    final dir = Directory.systemTemp.createTempSync('proxy-discard-');
    StudioWorkspace open() => StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'discard',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    var w = open();
    try {
      w.openDemo();
      await w.importVideo(
        LocalFileGrant.fromUserSelection(
          File(Platform.environment['STUDIO_TEST_VIDEO']!),
        ),
        expectedRevision: w.current.revision,
      );
      final pending = w.buildTimelinePreviewProxies();
      expect(
        () => w.discardTimelinePreviewProxies(
          assetId: w.current.toJson()['assets'][0]['id'],
          expectedRevision: w.current.revision,
          confirmed: true,
        ),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'PROXY_BUILD_BUSY',
          ),
        ),
      );
      w.cancelPreviewProxyBuild();
      await expectLater(
        pending,
        throwsA(
          isA<StudioException>().having((e) => e.code, 'code', 'CANCELED'),
        ),
      );
      await w.buildTimelinePreviewProxies();
      final assetId = w.current.toJson()['assets'][0]['id'] as String;
      var revision = w.current.revision;
      final a = w.current.toJson()['assets'][0], ref = a['proxyRefs'][0];
      final store = BlobStore(
        Directory('${dir.path}/media'),
        w.current.namespace,
      );
      final raw = await store.resolve(ref['blobHash']),
          map = await store.resolve(ref['ptsMapBlobHash']);
      final original = await store.resolve(a['originalBlobHash']);
      final originalBytes = await original.readAsBytes();
      expect(
        () => w.discardTimelinePreviewProxies(
          assetId: assetId,
          expectedRevision: revision,
          confirmed: false,
        ),
        throwsA(isA<StudioException>()),
      );
      expect(
        () => w.discardTimelinePreviewProxies(
          assetId: 'missing',
          expectedRevision: revision,
          confirmed: true,
        ),
        throwsA(isA<StudioException>()),
      );
      expect(w.current.revision, revision);
      expect(
        () =>
            w.edit(DiscardPreviewProxies(assetId), expectedRevision: revision),
        throwsA(isA<StudioException>()),
      );
      // Synthetic owned fixture corruption/deletion, not production repair logic.
      raw.deleteSync();
      w.clearPreviewProxies();
      await expectLater(
        w.buildTimelinePreviewProxies(),
        throwsA(isA<StudioException>()),
      );
      w.discardTimelinePreviewProxies(
        assetId: assetId,
        expectedRevision: revision,
        confirmed: true,
      );
      expect(w.current.revision, revision + BigInt.one);
      expect(w.current.toJson()['assets'][0]['proxyRefs'], isEmpty);
      expect(map.existsSync(), isTrue);
      revision = w.current.revision;
      w.discardTimelinePreviewProxies(
        assetId: assetId,
        expectedRevision: revision,
        confirmed: true,
      );
      expect(
        w.current.revision,
        revision,
      ); // duplicate/no-op: no new version/revision
      expect((await w.buildTimelinePreviewProxies())['built'], 1);
      expect(raw.existsSync(), true);
      expect(
        w.current.toJson()['assets'][0]['proxyRefs'][0]['blobHash'],
        ref['blobHash'],
      );
      final bad = await raw.readAsBytes();
      bad[0] ^= 1;
      raw.writeAsBytesSync(bad, flush: true);
      w.clearPreviewProxies();
      await expectLater(
        w.buildTimelinePreviewProxies(),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'BLOB_HASH_MISMATCH',
          ),
        ),
      );
      revision = w.current.revision;
      expect(
        () => w.discardTimelinePreviewProxies(
          assetId: assetId,
          expectedRevision: revision - BigInt.one,
          confirmed: true,
        ),
        throwsA(isA<StudioException>()),
      );
      expect(w.current.revision, revision);
      w.discardTimelinePreviewProxies(
        assetId: assetId,
        expectedRevision: revision,
        confirmed: true,
      );
      w.undo(expectedRevision: w.current.revision);
      expect(w.current.toJson()['assets'][0]['proxyRefs'], hasLength(1));
      w.discardTimelinePreviewProxies(
        assetId: assetId,
        expectedRevision: w.current.revision,
        confirmed: true,
      );
      await w.collectLocalGarbage();
      expect(raw.existsSync(), true);
      expect(map.existsSync(), true); // history owns these
      await expectLater(
        w.buildTimelinePreviewProxies(),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'BLOB_HASH_MISMATCH',
          ),
        ),
      );
      await w.exportVideo(File('${dir.path}/source.mp4'));
      await w.saveArchive(File('${dir.path}/originals.zip'));
      await w.restoreArchive(
        LocalFileGrant.fromUserSelection(File('${dir.path}/originals.zip')),
      );
      expect(w.current.toJson()['assets'][0]['proxyRefs'], isEmpty);
      final savedHash = w.current.hash;
      w.close();
      w = open();
      expect(w.openDemo().hash, savedHash);
      await w.exportVideo(File('${dir.path}/reopened.mp4'));
      expect(await original.readAsBytes(), originalBytes);
      expect(
        raw.readAsBytesSync(),
        bad,
      ); // repair never overwrites corrupt pinned bytes
    } finally {
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
  test('REAL shared derived hashes stay in current resource closure after selecting only one asset; unsupported metadata still refuses', () async {
    final dir = Directory.systemTemp.createTempSync('discard-shared-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'shared',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    try {
      w.openDemo();
      for (var i = 0; i < 2; i++) {
        await w.importVideo(
          LocalFileGrant.fromUserSelection(
            File(Platform.environment['STUDIO_TEST_VIDEO']!),
          ),
          expectedRevision: w.current.revision,
        );
      }
      await w.buildTimelinePreviewProxies();
      final before = w.current.toJson(), assets = before['assets'];
      expect(
        assets[0]['proxyRefs'][0]['blobHash'],
        assets[1]['proxyRefs'][0]['blobHash'],
      );
      final incompatible = w.current.toJson();
      incompatible['assets'][0]['proxyRefs'][0]['pipelineHash'] =
          'sha256:${'f' * 64}';
      final document = ProjectDocument.fromJson(incompatible),
          hash = document.hash;
      expect(
        () => applyEdit(
          document,
          DiscardPreviewProxies(assets[0]['id']),
          nextVersion: (_) => '99',
          newId: () => w.newEntityId(),
        ),
        throwsA(isA<StudioException>()),
      );
      expect(document.hash, hash); // unsupported recipe admission NOT relaxed
      w.discardTimelinePreviewProxies(
        assetId: assets[0]['id'],
        expectedRevision: w.current.revision,
        confirmed: true,
      );
      final after = w.current.toJson();
      expect(after['assets'][0]['proxyRefs'], isEmpty);
      expect(after['assets'][1], assets[1]);
      expect(after['blobs'], before['blobs']);
      requireLocalEditingWritable(w.current);
      expect((await w.buildTimelinePreviewProxies())['built'], 1);
      expect(w.current.toJson()['assets'][1], assets[1]);
      await w.collectLocalGarbage();
    } finally {
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
}
