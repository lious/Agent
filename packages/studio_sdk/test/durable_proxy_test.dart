import 'dart:io';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/blob_store.dart';
import 'package:studio_store/project_archive.dart';
import 'package:studio_store/proxy_resources.dart';

void main() {
  test('REAL durable SchemaProxy archive/fork/reopen reuse, exact map, historical pins and corrupt closure refuse', () async {
    final root = Directory.systemTemp.createTempSync('durable-proxy-');
    StudioWorkspace open() => StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 'local',
      workspaceId: 'durable',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${root.path}/media',
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
      final before = w.current;
      final result = await w.buildTimelinePreviewProxies();
      expect(result['persistent'], isTrue);
      expect(result['built'], 1);
      expect(w.current.revision, before.revision + BigInt.one);
      var a = w.current.toJson()['assets'][0], p = a['proxyRefs'][0];
      expect(p['sourceVersion'], a['version']);
      expect(
        w.current
            .toJson()['sequences'][0]['tracks'][0]['items'][0]['source']['version'],
        a['version'],
      );
      final store = BlobStore(
        Directory('${root.path}/media'),
        w.current.namespace,
      );
      final raw = await store.resolve(p['blobHash']),
          map = await store.resolve(p['ptsMapBlobHash']);
      final mapBytes = await map.readAsBytes(),
          rawBytes = await raw.readAsBytes();
      final facts = validateProxyResourceBytes(a, p, mapBytes, rawBytes);
      expect((facts['frames'] as List).length, 90);
      for (final kind in [
        'pts',
        'duration',
        'frameHash',
        'extra',
        'overflow',
      ]) {
        final bad = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(mapBytes)) as Map,
        );
        if (kind == 'pts') {
          bad['facts']['frames'][1]['pts'] = bad['facts']['frames'][0]['pts'];
        }
        if (kind == 'duration') bad['facts']['frames'][0]['duration'] = '0';
        if (kind == 'frameHash') bad['frameHashes'][0] = '0' * 64;
        if (kind == 'extra') bad['facts']['filePath'] = '../outside';
        if (kind == 'overflow') {
          bad['facts']['frames'][1]['pts'] = '9223372036854775808';
        }
        final bytes = utf8.encode(jsonEncode(bad)),
            forged = {
              ...Map<String, dynamic>.from(p),
              'ptsMapBlobHash': rawBytesHash(utf8.encode(jsonEncode(bad))),
            };
        expect(
          () => validateProxyResourceBytes(a, forged, bytes, rawBytes),
          throwsA(isA<StudioException>()),
          reason: kind,
        );
      }
      final unsafePath = w.current.toJson();
      (unsafePath['blobs'] as List).singleWhere(
        (b) => b['role'] == 'proxy',
      )['packagePath'] = 'proxies/../outside';
      expect(
        () => requireLocalEditingWritable(ProjectDocument.fromJson(unsafePath)),
        throwsA(isA<StudioException>()),
      );
      final cycle = w.current.toJson();
      cycle['assets'][0]['proxyRefs'][0]['blobHash'] =
          cycle['assets'][0]['originalBlobHash'];
      expect(
        () => requireLocalEditingWritable(ProjectDocument.fromJson(cycle)),
        throwsA(isA<StudioException>()),
      );
      // Self-consistent hashes are NOT proof that pixels came from the source.
      // Format verification may accept this archive; the native admission boundary must not.
      final forgedRaw = List<int>.from(rawBytes);
      forgedRaw[0] ^= 1;
      final forgedHash = rawBytesHash(forgedRaw);
      final forgedMap = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(mapBytes)) as Map,
      );
      forgedMap['rgbaHash'] = forgedHash;
      forgedMap['frameHashes'][0] = rawBytesHash(
        forgedRaw.sublist(0, p['width'] * p['height'] * 4 as int),
      ).substring(7);
      final forgedMapBytes = utf8.encode(jsonEncode(forgedMap)),
          forgedMapHash = rawBytesHash(utf8.encode(jsonEncode(forgedMap)));
      final forgedRoot = w.current.toJson();
      forgedRoot['assets'][0]['proxyRefs'][0]['blobHash'] = forgedHash;
      forgedRoot['assets'][0]['proxyRefs'][0]['ptsMapBlobHash'] = forgedMapHash;
      for (final b in forgedRoot['blobs']) {
        if (b['role'] == 'proxy') {
          b['hash'] = forgedHash;
          b['packagePath'] = 'proxies/${forgedHash.substring(7)}.rgba';
        }
        if (b['role'] == 'ptsMap') {
          b['hash'] = forgedMapHash;
          b['bytes'] = forgedMapBytes.length.toString();
          b['packagePath'] = 'proxies/${forgedMapHash.substring(7)}.pts.json';
        }
      }
      final forgedZip = File('${root.path}/forged.zip');
      await store.withMaintenanceLease(() async {
        await store.putVerifiedBytes(forgedHash, forgedRaw);
        await store.putVerifiedBytes(forgedMapHash, forgedMapBytes);
        await ProjectArchive().save(
          ProjectDocument.fromJson(forgedRoot),
          store,
          forgedZip,
        );
      });
      final unchanged = w.current.hash;
      await expectLater(
        w.restoreArchive(LocalFileGrant.fromUserSelection(forgedZip)),
        throwsA(
          isA<StudioException>().having(
            (e) => e.code,
            'code',
            'PROXY_DERIVATION_MISMATCH',
          ),
        ),
      );
      expect(w.current.hash, unchanged);
      final hash = w.current.hash;
      expect((await w.buildTimelinePreviewProxies())['built'], 0);
      expect(w.current.hash, hash);
      final archive = File('${root.path}/project.zip');
      await ProjectArchive().save(w.current, store, archive);
      final verified = ProjectArchive().open(archive);
      expect(verified.originals.length, 3);
      final foreign = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/foreign-db',
        tenantId: 'local',
        workspaceId: 'foreign',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${root.path}/foreign-media',
      );
      try {
        foreign.openDemo();
        await foreign.restoreArchive(LocalFileGrant.fromUserSelection(archive));
        expect((await foreign.buildTimelinePreviewProxies())['built'], 0);
      } finally {
        foreign.close();
      }
      w.undo(expectedRevision: w.current.revision);
      expect(w.current.toJson()['assets'][0]['proxyRefs'], isEmpty);
      await w.collectLocalGarbage();
      expect(raw.existsSync(), isTrue);
      expect(map.existsSync(), isTrue); // old revision pins
      w.close();
      w = open();
      w.openDemo();
      await w.restoreArchive(LocalFileGrant.fromUserSelection(archive));
      final fork = w.current;
      expect(fork.projectId, isNot(before.projectId));
      expect((await w.buildTimelinePreviewProxies())['built'], 0);
      expect(w.current.hash, fork.hash);
      w.close();
      w = open();
      w.openDemo();
      expect((await w.buildTimelinePreviewProxies())['built'], 0);
      expect(w.current.hash, fork.hash);
      final out = File('${root.path}/out.mp4');
      await w.exportVideo(out);
      expect(out.lengthSync(), greaterThan(0));
      a = w.current.toJson()['assets'][0];
      p = a['proxyRefs'][0];
      final bad = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(mapBytes)) as Map,
      );
      bad['sourceHash'] = 'sha256:${'0' * 64}';
      final wrong = utf8.encode(jsonEncode(bad));
      final forged = {
        ...Map<String, dynamic>.from(p),
        'ptsMapBlobHash': rawBytesHash(wrong),
      };
      expect(
        () => validateProxyResourceBytes(a, forged, wrong, rawBytes),
        throwsA(isA<StudioException>()),
      );
      final missing = w.current.toJson();
      (missing['blobs'] as List).removeWhere(
        (b) => b['hash'] == p['ptsMapBlobHash'],
      );
      expect(
        () => ProjectDocument.fromJson(missing),
        throwsA(isA<StudioException>()),
      );
      w.clearPreviewProxies();
      final corrupt = List<int>.from(rawBytes)..[0] ^= 1;
      raw.writeAsBytesSync(corrupt);
      await expectLater(
        w.buildTimelinePreviewProxies(),
        throwsA(isA<StudioException>()),
      );
      raw.writeAsBytesSync(rawBytes);
      expect((await w.buildTimelinePreviewProxies())['built'], 0);
    } finally {
      w.close();
      root.deleteSync(recursive: true);
    }
  });
  test('REAL concurrent revision invalidates pending native proxy adoption without losing originals', () async {
    final root = Directory.systemTemp.createTempSync('proxy-conflict-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${root.path}/db',
      tenantId: 'local',
      workspaceId: 'conflict',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${root.path}/media',
    );
    try {
      w.openDemo();
      final video = File('${root.path}/long.mp4');
      expect(
        Process.runSync('ffmpeg', [
          '-v',
          'error',
          '-stream_loop',
          '10',
          '-i',
          Platform.environment['STUDIO_TEST_VIDEO']!,
          '-t',
          '33',
          '-c',
          'copy',
          video.path,
        ]).exitCode,
        0,
      );
      await w.importVideo(
        LocalFileGrant.fromUserSelection(video),
        expectedRevision: w.current.revision,
      );
      final store = BlobStore(
            Directory('${root.path}/media'),
            w.current.namespace,
          ),
          original =
              w.current.toJson()['assets'][0]['originalBlobHash'] as String;
      final pending = w.buildTimelinePreviewProxies();
      pending.catchError(
        (Object e) => <String, dynamic>{'earlyError': e.toString()},
      );
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (!store.directory
          .listSync(followLinks: false)
          .any(
            (e) =>
                e is File &&
                e.path.contains('.proxy-v1-') &&
                e.lengthSync() > 0,
          )) {
        if (DateTime.now().isAfter(deadline)) {
          fail('native output phase was not observed');
        }
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      w.rename('concurrent writer', expectedRevision: w.current.revision);
      await expectLater(
        pending,
        throwsA(
          isA<StudioException>().having((e) => e.code, 'code', 'CANCELED'),
        ),
      );
      expect(w.current.title, 'concurrent writer');
      expect(w.current.toJson()['assets'][0]['proxyRefs'], isEmpty);
      await w.collectLocalGarbage();
      expect((await store.resolve(original)).existsSync(), isTrue);
      expect(
        store.directory.listSync().where((e) => e.path.contains('.proxy-v1-')),
        isEmpty,
      );
    } finally {
      w.close();
      root.deleteSync(recursive: true);
    }
  });
  test('REAL killed stage owner releases lock; GC reclaims only owned orphan and rejects symlink', () async {
    final root = Directory.systemTemp.createTempSync('proxy-orphans-'),
        ns = Namespace('studio', 'local', 'stages');
    final store = BlobStore(root, ns);
    Process? child;
    try {
      child = await Process.start('dart', [
        'run',
        'packages/studio_sdk/tool/proxy_stage_worker.dart',
        root.path,
        jsonEncode(ns.toJson()),
      ]);
      expect(
        await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 20)),
        'ready',
      );
      final owned = store.directory
          .listSync(followLinks: false)
          .where((e) => e.path.contains('.proxy-v1-'))
          .single;
      var acquired = false;
      final recovery = store.withMaintenanceLease(() async {
        acquired = true;
        return store.collectProxyOrphans();
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(acquired, isFalse);
      child.kill(ProcessSignal.sigkill);
      expect(await child.exitCode, isNot(0));
      expect((await recovery)['files'], 3);
      expect(File(owned.path).existsSync(), isFalse);
      final outside = File('${root.path}/untouched')
        ..writeAsStringSync('private');
      final unsafe = store.newProxyStage();
      final link = Link(unsafe.path)..createSync(outside.path);
      await expectLater(
        store.withMaintenanceLease(() async => store.collectProxyOrphans()),
        throwsA(isA<StudioException>()),
      );
      expect(outside.readAsStringSync(), 'private');
      link.deleteSync();
      // The failed scan may already have removed the regular orphan; regenerate
      // one to assert deterministic count without relying on directory order.
      await store.withMaintenanceLease(() async {
        store.collectProxyOrphans();
        store.newProxyStage().writeAsStringSync('owned');
        expect(store.collectProxyOrphans()['files'], 1);
      });
      expect(outside.readAsStringSync(), 'private');
    } finally {
      if (child != null) child.kill(ProcessSignal.sigkill);
      root.deleteSync(recursive: true);
    }
  });
}
