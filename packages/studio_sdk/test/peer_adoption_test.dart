import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_peer_io/studio_peer_io.dart';
import 'package:studio_store/blob_store.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

Matcher code(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
String fp(File cert) => rawBytesHash(
  base64.decode(
    cert.readAsLinesSync().where((l) => !l.startsWith('-----')).join(),
  ),
).substring(7);
void main() {
  test(
    'queued import/adoption cannot cross a same-project writer ABA while awaiting CAS lease',
    () async {
      final root = Directory.systemTemp.createTempSync('peer-import-aba-');
      final ns = Namespace('studio', 'local', 'aba');
      final w = StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'aba',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${root.path}/media',
      );
      final entered = Completer<void>(), release = Completer<void>();
      final store = BlobStore(Directory('${root.path}/media'), ns);
      try {
        w.openDemo();
        final held = store.withMaintenanceLease(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final imported = w.importVideo(
          LocalFileGrant.fromUserSelection(
            File(Platform.environment['STUDIO_TEST_VIDEO']!),
          ),
          expectedRevision: BigInt.zero,
        );
        final adopted = w.adoptPeerVideo(
          'a' * 64,
          commandId: 'queued-adoption',
          expectedRevision: BigInt.zero,
        );
        final importAssertion = expectLater(imported, code('PROJECT_CHANGED'));
        final adoptionAssertion = expectLater(adopted, code('PROJECT_CHANGED'));
        w.openDemo(); // same project ID, a NEW writer/fence; no revision change
        release.complete();
        await held;
        await importAssertion;
        await adoptionAssertion;
        expect(w.current.revision, BigInt.zero);
        expect(w.current.toJson()['assets'], isEmpty);
        expect(store.directory.listSync(), isEmpty);
      } finally {
        if (!release.isCompleted) release.complete();
        w.close();
        root.deleteSync(recursive: true);
      }
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
            Platform.environment['STUDIO_TEST_VIDEO'] == null
        ? 'Requires actual native FFmpeg + synthetic fixture'
        : false,
  );
  test(
    'real mTLS received video -> explicit CAS adoption rollback/retry/dedup -> archive/reopen/export -> safe inbox and historical-pin GC',
    () async {
      final root = Directory.systemTemp.createTempSync('real-peer-adopt-');
      await Process.run('chmod', ['700', root.path]);
      for (final name in ['host', 'worker']) {
        final r = await Process.run('openssl', [
          'req',
          '-x509',
          '-newkey',
          'ec',
          '-pkeyopt',
          'ec_paramgen_curve:P-256',
          '-nodes',
          '-keyout',
          '${root.path}/$name.key',
          '-out',
          '${root.path}/$name.pem',
          '-subj',
          '/CN=$name',
          '-days',
          '1',
          '-addext',
          'subjectAltName=IP:127.0.0.1',
          '-addext',
          'extendedKeyUsage=serverAuth,clientAuth',
        ]);
        expect(r.exitCode, 0);
        await Process.run('chmod', ['600', '${root.path}/$name.key']);
      }
      final source = File(Platform.environment['STUDIO_TEST_VIDEO']!),
          bytes = source.readAsBytesSync(),
          raw = rawBytesHash(source.readAsBytesSync()).substring(7);
      final ns = Namespace('studio', 'local', 'adoption');
      StudioWorkspace open() => StudioWorkspace.open(
        profile: AppProfile(
          appId: 'studio',
          region: 'local',
          features: {'project.metadata', 'media.local'},
        ),
        databasePath: '${root.path}/db',
        tenantId: 'local',
        workspaceId: 'adoption',
        mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
        mediaRootPath: '${root.path}/media',
      );
      var w = open();
      w.openDemo();
      final coordinator = w.createMetadataComputeSession('receive');
      final hostFile = File('${root.path}/host.pem'),
          workerFile = File('${root.path}/worker.pem');
      coordinator.enableRecovery(fp(hostFile));
      coordinator.grant(
        fingerprint: fp(workerFile),
        deviceId: 'worker',
        nodes: {'digest-0'},
        allowedBlobs: {raw: bytes.length},
      );
      SecurityContext context(String local, String remote) =>
          SecurityContext(withTrustedRoots: false)
            ..useCertificateChain('${root.path}/$local.pem')
            ..usePrivateKey('${root.path}/$local.key')
            ..setTrustedCertificates('${root.path}/$remote.pem');
      final port = await coordinator.listen(
        context('host', 'worker'),
        InternetAddress.loopbackIPv4,
      );
      final endpoint = Uri.parse('https://127.0.0.1:$port/studio/peer/v1');
      final invite = Map<String, dynamic>.from(
        coordinator.invitation(
          endpoint: endpoint.toString(),
          certificatePem: hostFile.readAsStringSync(),
          nodes: {'digest-0'},
        ),
      );
      final client = PeerTlsClient(
        context: context('worker', 'host'),
        endpoint: endpoint,
        serverFingerprint: fp(hostFile),
      );
      await uploadPeerBlob(
        client,
        invite,
        'digest-0',
        bytes,
        operationId: 'transfer',
      );
      expect(w.receivedPeerBlob(raw), orderedEquals(bytes));
      final recovered = w.recoverMetadataSession(
        coordinator.id,
        coordinator.plan.hash,
        fp(hostFile),
      );
      expect(recovered.id, coordinator.id);
      expect(recovered.peerFingerprint, isNull);
      await expectLater(
        uploadPeerBlob(
          client,
          invite,
          'digest-0',
          bytes,
          operationId: 'transfer',
        ),
        code('PEER_NOT_AUTHORIZED'),
      );

      final injection = sqlite3.open('${root.path}/db');
      injection.execute(
        "CREATE TRIGGER fail_inbox_gc BEFORE DELETE ON peer_blob_objects BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      await expectLater(w.collectLocalGarbage(), throwsA(anything));
      expect(w.receivedPeerBlob(raw), orderedEquals(bytes));
      expect(
        injection
            .select('SELECT count(*) AS n FROM peer_blob_stages')
            .single['n'],
        greaterThan(0),
      );
      injection.execute('DROP TRIGGER fail_inbox_gc');

      injection.execute(
        "CREATE TRIGGER fail_adoption BEFORE INSERT ON peer_adoptions BEGIN SELECT RAISE(ABORT,'injected'); END",
      );
      await expectLater(
        w.adoptPeerVideo(
          raw,
          commandId: 'adopt-1',
          expectedRevision: BigInt.zero,
        ),
        throwsA(anything),
      );
      expect(w.current.revision, BigInt.zero);
      expect(w.current.toJson()['assets'], isEmpty);
      injection.execute('DROP TRIGGER fail_adoption');
      injection.dispose();
      final adoption = w.adoptPeerVideo(
        raw,
        commandId: 'adopt-1',
        expectedRevision: BigInt.zero,
      );
      final overlappingGc = w.collectLocalGarbage();
      await adoption;
      expect((await overlappingGc)['objects'], 1);
      expect(w.current.toJson()['assets'], hasLength(1));
      expect(w.current.revision, BigInt.one);
      await w.adoptPeerVideo(
        raw,
        commandId: 'adopt-1',
        expectedRevision: BigInt.zero,
      );
      expect(w.current.toJson()['assets'], hasLength(1));
      await expectLater(
        w.adoptPeerVideo(
          raw,
          commandId: 'adopt-1',
          expectedRevision: BigInt.one,
        ),
        code('IDEMPOTENCY_CONFLICT'),
      );
      final archive = File('${root.path}/saved.studioproj');
      await w.saveArchive(archive);
      await coordinator.close();
      client.close();
      final store = BlobStore(Directory('${root.path}/media'), ns),
          orphan = Uint8List.fromList([9, 8, 7, 6]);
      await store.withMaintenanceLease(
        () => store.putVerifiedBytes(rawBytesHash(orphan), orphan),
      );
      final gc = await w.collectLocalGarbage();
      expect(gc['casFiles'], 1);
      expect(gc['objects'], 0);
      expect(w.receivedPeerBlob(raw), isNull);
      await store.resolve('sha256:$raw');
      final saved = w.current.hash;
      w.close();
      w = open();
      expect(w.openDemo().hash, saved);
      final output = File('${root.path}/result.mp4');
      final result = await w.exportVideo(output);
      expect(result['frames'], 90);
      expect(output.lengthSync(), greaterThan(0));
      w.undo(expectedRevision: w.current.revision);
      await w.collectLocalGarbage();
      await store.resolve('sha256:$raw');
      w.close();
      root.deleteSync(recursive: true);
    },
    skip:
        Platform.environment['STUDIO_MEDIA_LIBRARY'] == null ||
            Platform.environment['STUDIO_TEST_VIDEO'] == null
        ? 'Real compiled adapter and video fixture required; not counted without them'
        : false,
  );
}
