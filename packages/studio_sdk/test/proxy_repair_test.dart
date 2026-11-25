import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/studio_store.dart';
import 'package:sqlite3/sqlite3.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));
void main() {
  test('REAL source-qualified repair, busy/cancel/writer fences, SIGKILL partial publication and deterministic recovery preserve root/history', () async {
    final dir = Directory.systemTemp.createTempSync('repair-sdk-');
    StudioWorkspace open() => StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'repair',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    var w = open();
    Process? child;
    try {
      w.openDemo();
      await w.importVideo(
        LocalFileGrant.fromUserSelection(
          File(Platform.environment['STUDIO_TEST_VIDEO']!),
        ),
        expectedRevision: w.current.revision,
      );
      await w.buildTimelinePreviewProxies();
      final snapshot = w.current,
          asset = snapshot.toJson()['assets'][0],
          ref = asset['proxyRefs'][0],
          id = asset['id'] as String;
      final store = BlobStore(
            Directory('${dir.path}/media'),
            snapshot.namespace,
          ),
          raw = await store.resolve(ref['blobHash']),
          map = await store.resolve(ref['ptsMapBlobHash']);
      final rawBytes = await raw.readAsBytes(),
          mapBytes = await map.readAsBytes();
      Future<Map<String, dynamic>> repair({
        bool confirmed = true,
        BigInt? rev,
      }) => w.repairTimelinePreviewProxies(
        assetId: id,
        expectedRevision: rev ?? w.current.revision,
        confirmed: confirmed,
      );
      await expectLater(
        repair(confirmed: false),
        code('PROXY_REPAIR_CONFIRMATION_REQUIRED'),
      );
      expect(
        (await repair())['replaced'],
        0,
      ); // valid immutable files never rewritten
      final canceled = repair();
      await expectLater(repair(), code('PROXY_BUILD_BUSY'));
      w.cancelPreviewProxyBuild();
      await expectLater(canceled, code('CANCELED'));
      final stale = repair();
      w.rename('concurrent writer edit', expectedRevision: w.current.revision);
      await expectLater(stale, code('CANCELED'));
      final changed = w.current;
      await expectLater(
        repair(rev: snapshot.revision),
        code('REVISION_CONFLICT'),
      );
      final fenced = repair();
      final other = DocumentRepository.open(
        '${dir.path}/db',
        changed.namespace,
      );
      other.acquireWriter(
        changed.projectId,
        'other',
        expectedEpoch: other.writerEpoch(changed.projectId),
      );
      other.close();
      await expectLater(fenced, code('WRITER_FENCED'));
      w.close();
      w = open();
      w.openDemo();
      raw.writeAsBytesSync([1, 2, 3], flush: true);
      map.writeAsBytesSync([4, 5, 6], flush: true);
      final rawStage = store.newProxyStage()
        ..writeAsBytesSync(rawBytes, flush: true);
      final mapStage = File(
        '${store.directory.path}/.restore-019a0000-0000-7000-8000-000000000001',
      )..writeAsBytesSync(mapBytes, flush: true);
      final input = File('${dir.path}/worker.json')
        ..writeAsStringSync(
          jsonEncode({
            'db': '${dir.path}/db',
            'media': '${dir.path}/media',
            'ns': w.current.namespace.toJson(),
            'project': w.projectId,
            'source': asset['originalBlobHash'],
            'roles': {
              ref['blobHash']: 'proxy',
              ref['ptsMapBlobHash']: 'ptsMap',
            },
            'stages': {
              ref['blobHash']: rawStage.path,
              ref['ptsMapBlobHash']: mapStage.path,
            },
          }),
        );
      child = await Process.start(Platform.resolvedExecutable, [
        'run',
        'packages/studio_sdk/tool/repair_interrupt_worker.dart',
        input.path,
      ]);
      final errors = child.stderr.transform(utf8.decoder).join();
      try {
        await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .firstWhere((line) => line == 'FIRST_OBJECT_DURABLE')
            .timeout(const Duration(seconds: 20));
      } catch (error) {
        throw StateError(
          'interrupt fixture exited ${await child.exitCode}: ${await errors}; $error',
        );
      }
      expect(child.kill(ProcessSignal.sigkill), true);
      expect(await child.exitCode, isNot(0));
      await errors;
      child = null;
      expect(rawBytesHash(raw.readAsBytesSync()), ref['blobHash']);
      expect(rawBytesHash(map.readAsBytesSync()), isNot(ref['ptsMapBlobHash']));
      final interrupted = store.directory
          .listSync()
          .where((f) => f.path.contains('.repair-v1-'))
          .map((f) => jsonDecode(File(f.path).readAsStringSync()) as Map)
          .toList();
      expect(interrupted.any((a) => a['state'] == 'prepared'), true);
      w.close();
      w = open();
      expect(w.openDemo().hash, changed.hash);
      final result = await repair();
      expect(result['replaced'], 1);
      expect(w.current.hash, changed.hash);
      expect((await w.buildTimelinePreviewProxies())['built'], 0);
      await w.collectLocalGarbage();
      expect(raw.readAsBytesSync(), rawBytes);
      expect(map.readAsBytesSync(), mapBytes);
      await w.saveArchive(File('${dir.path}/good.zip'));
      await w.exportVideo(File('${dir.path}/export.mp4'));
      final saved = w.current.hash;
      w.close();
      w = open();
      expect(w.openDemo().hash, saved);
      await w.restoreArchive(
        LocalFileGrant.fromUserSelection(File('${dir.path}/good.zip')),
      );
      expect((await w.buildTimelinePreviewProxies())['built'], 0);
      // Fork creates another project's pin. Even identical-hash shared repair is refused.
      final forkAsset = w.current.toJson()['assets'][0];
      raw.writeAsBytesSync([9], flush: true);
      await expectLater(
        w.repairTimelinePreviewProxies(
          assetId: forkAsset['id'],
          expectedRevision: w.current.revision,
          confirmed: true,
        ),
        code('PROXY_REPAIR_SHARED_OBJECT'),
      );
      expect(raw.readAsBytesSync(), [9]);
    } finally {
      if (child != null) {
        child.kill(ProcessSignal.sigkill);
        await child.exitCode;
      }
      w.close();
      dir.deleteSync(recursive: true);
    }
  });

  test('REAL SQLite retained original-role collision refuses before any CAS publication', () async {
    final dir = Directory.systemTemp.createTempSync('repair-protected-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'protected',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    try {
      w.openDemo();
      await w.importVideo(
        LocalFileGrant.fromUserSelection(
          File(Platform.environment['STUDIO_TEST_VIDEO']!),
        ),
        expectedRevision: w.current.revision,
      );
      final old = w.current.toJson();
      await w.buildTimelinePreviewProxies();
      final a = w.current.toJson()['assets'][0], ref = a['proxyRefs'][0];
      final store = BlobStore(
            Directory('${dir.path}/media'),
            w.current.namespace,
          ),
          raw = await store.resolve(ref['blobHash']);
      final b = (w.current.toJson()['blobs'] as List).singleWhere(
        (b) => b['hash'] == ref['blobHash'],
      );
      old['blobs'].add({
        ...Map<String, dynamic>.from(b),
        'role': 'original',
        'packagePath': 'originals/${(b['hash'] as String).substring(7)}',
      });
      final protected = ProjectDocument.fromJson(old);
      // Isolated adversarial SQLite fixture, not an App import/acceptance shortcut.
      final db = sqlite3.open('${dir.path}/db');
      db.execute('INSERT INTO snapshots(ns,hash,json) VALUES(?,?,?)', [
        protected.namespace.key,
        protected.hash,
        protected.canonicalJson,
      ]);
      db.dispose();
      raw.writeAsBytesSync([7], flush: true);
      await expectLater(
        w.repairTimelinePreviewProxies(
          assetId: a['id'],
          expectedRevision: w.current.revision,
          confirmed: true,
        ),
        code('PROXY_REPAIR_PROTECTED_ROLE'),
      );
      expect(raw.readAsBytesSync(), [7]);
      expect(
        store.directory.listSync().where((f) => f.path.contains('.repair-v1-')),
        isEmpty,
      );
    } finally {
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
  test('REAL legacy namespace, cross-database usage and symlink targets cannot gain repair authority', () async {
    final dir = Directory.systemTemp.createTempSync('repair-storage-');
    StudioWorkspace open(String name, String db) => StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/$db',
      tenantId: 'local',
      workspaceId: name,
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    final legacy = BlobStore(
      Directory('${dir.path}/media'),
      Namespace('studio', 'local', 'legacy'),
    );
    final unknown = File('${legacy.directory.path}/unknown-preexisting')
      ..writeAsStringSync('not owned');
    var w = open('legacy', 'legacy.db');
    try {
      w.openDemo();
      await w.importVideo(
        LocalFileGrant.fromUserSelection(
          File(Platform.environment['STUDIO_TEST_VIDEO']!),
        ),
        expectedRevision: w.current.revision,
      );
      await w.buildTimelinePreviewProxies();
      await expectLater(
        w.repairTimelinePreviewProxies(
          assetId: w.current.toJson()['assets'][0]['id'],
          expectedRevision: w.current.revision,
          confirmed: true,
        ),
        code('PROXY_REPAIR_STORAGE_OWNER_UNVERIFIED'),
      );
      expect(unknown.readAsStringSync(), 'not owned');
      w.close();
      w = open('fresh', 'fresh.db');
      w.openDemo();
      await w.importVideo(
        LocalFileGrant.fromUserSelection(
          File(Platform.environment['STUDIO_TEST_VIDEO']!),
        ),
        expectedRevision: w.current.revision,
      );
      await w.buildTimelinePreviewProxies();
      final a = w.current.toJson()['assets'][0], ref = a['proxyRefs'][0];
      final store = BlobStore(
            Directory('${dir.path}/media'),
            w.current.namespace,
          ),
          raw = await store.resolve(ref['blobHash']);
      final bytes = await raw.readAsBytes(),
          outside = File('${dir.path}/outside')
            ..writeAsBytesSync(bytes, flush: true);
      raw.deleteSync();
      Link(raw.path).createSync(outside.path);
      await expectLater(
        w.repairTimelinePreviewProxies(
          assetId: a['id'],
          expectedRevision: w.current.revision,
          confirmed: true,
        ),
        code('PROXY_REPAIR_UNSAFE_TARGET'),
      );
      expect(outside.readAsBytesSync(), bytes);
      Link(raw.path).deleteSync();
      raw.writeAsBytesSync(bytes, flush: true);
      final other = open('fresh', 'other.db');
      try {
        other.openDemo();
        await expectLater(
          w.repairTimelinePreviewProxies(
            assetId: a['id'],
            expectedRevision: w.current.revision,
            confirmed: true,
          ),
          code('PROXY_REPAIR_STORAGE_SHARED'),
        );
      } finally {
        other.close();
      }
      expect(raw.readAsBytesSync(), bytes);
    } finally {
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
}
