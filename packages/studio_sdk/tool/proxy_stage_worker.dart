import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:studio_store/blob_store.dart';
import 'package:studio_contracts/studio_contracts.dart';

Future<void> main(List<String> args) async {
  final n = jsonDecode(args[1]);
  final store = BlobStore(
    Directory(args[0]),
    Namespace(n['appId'], n['tenantId'], n['workspaceId']),
  );
  await store.withMaintenanceLease(() async {
    final stage = store.newProxyStage();
    stage.writeAsBytesSync(List.filled(1024, 7), flush: true);
    final id = stage.uri.pathSegments.last
        .substring('.proxy-v1-'.length)
        .replaceAll('.rgba', '');
    File('${store.directory.path}/.import-$id')
        .writeAsStringSync('partial-copy', flush: true);
    File('${store.directory.path}/.restore-$id')
        .writeAsStringSync('partial-map', flush: true);
    // An uncompleted Future alone does NOT keep a Dart VM alive.
    Timer.periodic(const Duration(seconds: 1), (_) {});
    stdout.writeln('ready');
    await stdout.flush();
    await Completer<void>().future;
  });
}
