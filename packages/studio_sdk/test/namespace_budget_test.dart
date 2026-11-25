import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:studio_sdk/studio_sdk.dart';
import 'package:studio_store/blob_store.dart';

Matcher budgetCode(String c) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', c));
void main() {
  test('REAL namespace byte policy gates import/native staging, survives failure/cancel/archive/reopen and preserves originals/history', () async {
    final dir = Directory.systemTemp.createTempSync('namespace-budget-');
    StudioWorkspace open() => StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'budget',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    var w = open();
    try {
      w.openDemo();
      final store = BlobStore(
        Directory('${dir.path}/media'),
        w.current.namespace,
      );
      expect(
        w.namespaceStorageInventory()['policy']['retention'],
        'preserveAll',
      );
      await expectLater(
        w.configureNamespaceDiskBudget('20000', confirmed: false),
        budgetCode('STORAGE_POLICY_CONFIRMATION_REQUIRED'),
      );
      await w.configureNamespaceDiskBudget('20000', confirmed: true);
      final source = File(Platform.environment['STUDIO_TEST_VIDEO']!);
      await expectLater(
        w.importVideo(
          LocalFileGrant.fromUserSelection(source),
          expectedRevision: w.current.revision,
        ),
        budgetCode('NAMESPACE_DISK_BUDGET_EXCEEDED'),
      );
      expect(w.current.revision, BigInt.zero);
      expect(
        store.directory.listSync().any(
          (f) => f.uri.pathSegments.last.startsWith('.import-'),
        ),
        false,
      );
      await w.configureNamespaceDiskBudget('1048576', confirmed: true);
      await w.importVideo(
        LocalFileGrant.fromUserSelection(source),
        expectedRevision: w.current.revision,
      );
      final imported = w.current;
      await expectLater(
        w.buildTimelinePreviewProxies(),
        budgetCode('NAMESPACE_DISK_BUDGET_EXCEEDED'),
      );
      expect(w.current.hash, imported.hash);
      expect(
        store.directory.listSync().any(
          (f) => f.uri.pathSegments.last.startsWith('.proxy-v1-'),
        ),
        false,
      );
      await w.configureNamespaceDiskBudget('536870912', confirmed: true);
      expect((await w.buildTimelinePreviewProxies())['built'], 1);
      final project = w.current,
          original = await store.resolve(
            project.toJson()['assets'][0]['originalBlobHash'],
          );
      final originalBytes = await original.readAsBytes();
      final record = File(
        '${store.directory.path}/.storage-reservation-v1.json',
      );
      expect(jsonDecode(record.readAsStringSync())['state'], 'released');
      await expectLater(
        store.withNamespaceDiskReservation(4096, () async {
          throw StateError('injected caller failure');
        }),
        throwsStateError,
      );
      expect(jsonDecode(record.readAsStringSync())['state'], 'failed');
      final pending = w.buildTimelinePreviewProxies();
      w.cancelPreviewProxyBuild();
      await expectLater(pending, budgetCode('CANCELED'));
      expect(jsonDecode(record.readAsStringSync())['state'], 'failed');
      await w.saveArchive(File('${dir.path}/project.zip'));
      await w.restoreArchive(
        LocalFileGrant.fromUserSelection(File('${dir.path}/project.zip')),
      );
      final saved = w.current.hash;
      w.close();
      w = open();
      expect(w.openDemo().hash, saved);
      expect(
        w.namespaceStorageInventory()['policy']['casFileByteLimit'],
        '536870912',
      );
      expect(
        BigInt.parse(w.namespaceStorageInventory()['fileBytes']),
        lessThan(BigInt.from(536870912)),
      );
      expect(await original.readAsBytes(), originalBytes);
      await expectLater(
        w.configureNamespaceDiskBudget('1', confirmed: true),
        budgetCode('NAMESPACE_DISK_BUDGET_EXCEEDED'),
      );
      expect(
        w.namespaceStorageInventory()['policy']['casFileByteLimit'],
        '536870912',
      );
      await w.configureNamespaceDiskBudget(null, confirmed: true);
      expect(
        w.namespaceStorageInventory()['policy']['retention'],
        'preserveAll',
      );
    } finally {
      w.close();
      dir.deleteSync(recursive: true);
    }
  });

  test('REAL SIGKILL reservation credits reclaimed only under OS lease; staged bytes remain inventoried, concurrent writes cannot overbook', () async {
    final dir = Directory.systemTemp.createTempSync('budget-lock-');
    Process? child;
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'budget',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    try {
      w.openDemo();
      await w.configureNamespaceDiskBudget('1048576', confirmed: true);
      final store = BlobStore(
        Directory('${dir.path}/media'),
        w.current.namespace,
      );
      child = await Process.start(Platform.resolvedExecutable, [
        'run',
        'packages/studio_sdk/tool/disk_reservation_worker.dart',
        '${dir.path}/media',
      ]);
      final err = child.stderr.transform(utf8.decoder).join();
      await child.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .firstWhere((v) => v == 'RESERVED_AND_WRITTEN')
          .timeout(const Duration(seconds: 20));
      var acquired = false;
      final waiting = store.withNamespaceDiskReservation(1024, () async {
        acquired = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(acquired, false);
      child.kill(ProcessSignal.sigkill);
      await child.exitCode;
      await err;
      child = null;
      await waiting;
      final receipt = jsonDecode(
        File('${store.directory.path}/.storage-reservation-v1.json')
            .readAsStringSync(),
      );
      expect(receipt['reclaimedAbandonedAccounting'], true);
      expect(receipt['state'], 'released');
      final stage = File(
        '${store.directory.path}/.restore-019a0000-0000-7000-8000-000000000002',
      );
      expect(stage.lengthSync(), 16384);
      expect(
        BigInt.parse(store.namespaceInventory()['fileBytes']),
        greaterThan(BigInt.from(16384)),
      );
      final limit =
          BigInt.parse(store.namespaceInventory()['fileBytes']) +
          BigInt.from(8192 + 8192);
      await w.configureNamespaceDiskBudget(limit.toString(), confirmed: true);
      final one = List.filled(6000, 2), two = List.filled(6000, 3);
      final results = await Future.wait([
        store
            .putVerifiedBytes(rawBytesHash(one), one)
            .then((_) => true, onError: (_) => false),
        store
            .putVerifiedBytes(rawBytesHash(two), two)
            .then((_) => true, onError: (_) => false),
      ]);
      expect(results.where((v) => v).length, 1);
      final growing = File('${dir.path}/growing.dat')
        ..writeAsBytesSync(List.filled(256, 1), flush: true);
      final entered = Completer<void>(), release = Completer<void>();
      final held = store.withMaintenanceLease(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final importing = store.importFile(
        LocalFileGrant.fromUserSelection(growing),
      );
      growing.writeAsBytesSync(List.filled(8192, 1), flush: true);
      release.complete();
      await held;
      await expectLater(importing, budgetCode('SOURCE_CHANGED_DURING_IMPORT'));

      expect(
        stage.existsSync(),
        true,
      ); // no automatic deletion to admit another write
    } finally {
      if (child != null) {
        child.kill(ProcessSignal.sigkill);
        await child.exitCode;
      }
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
  test('REAL policy invalid/future/unsafe inputs and unreserved native writes fail closed without deletion', () async {
    final dir = Directory.systemTemp.createTempSync('budget-policy-boundary-');
    final w = StudioWorkspace.open(
      profile: AppProfile(
        appId: 'studio',
        region: 'local',
        features: {'project.metadata', 'media.local'},
      ),
      databasePath: '${dir.path}/db',
      tenantId: 'local',
      workspaceId: 'budget',
      mediaLibraryPath: Platform.environment['STUDIO_MEDIA_LIBRARY'],
      mediaRootPath: '${dir.path}/media',
    );
    try {
      w.openDemo();
      final store = BlobStore(
        Directory('${dir.path}/media'),
        w.current.namespace,
      );
      for (final invalid in ['0', '-1', '01', '9223372036854775808', '1.0']) {
        await expectLater(
          w.configureNamespaceDiskBudget(invalid, confirmed: true),
          budgetCode('STORAGE_POLICY_INVALID'),
        );
      }
      await w.configureNamespaceDiskBudget('1048576', confirmed: true);
      expect(
        () => store.newProxyStage(),
        budgetCode('NAMESPACE_DISK_RESERVATION_REQUIRED'),
      );
      final outside = File('${dir.path}/outside')
        ..writeAsStringSync('must stay');
      final link = Link('${store.directory.path}/unknown-link')
        ..createSync(outside.path);
      expect(
        (store.namespaceInventory()['unsafeEntries'] as List),
        contains('unknown-link'),
      );
      await expectLater(
        store.putVerifiedBytes(rawBytesHash([1]), [1]),
        budgetCode('STORAGE_INVENTORY_UNSAFE'),
      );
      expect(outside.readAsStringSync(), 'must stay');
      link.deleteSync();
      final policy = File('${store.directory.path}/.storage-policy-v1.json'),
          good = policy.readAsBytesSync();
      for (final body in [
        jsonEncode({
          'version': 2,
          'casFileByteLimit': null,
          'retention': 'preserveAll',
        }),
        jsonEncode({
          'version': 1,
          'casFileByteLimit': null,
          'retention': 'deleteOld',
        }),
        'not json',
      ]) {
        policy.writeAsStringSync(body, flush: true);
        await expectLater(
          store.putVerifiedBytes(rawBytesHash([1]), [1]),
          throwsA(isA<StudioException>()),
        );
      }
      policy.writeAsBytesSync(good, flush: true);
      expect(store.namespaceStoragePolicy()['retention'], 'preserveAll');
      expect(w.current.revision, BigInt.zero);
      expect(outside.readAsStringSync(), 'must stay');
    } finally {
      w.close();
      dir.deleteSync(recursive: true);
    }
  });
}
