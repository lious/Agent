import 'dart:io';

import 'package:studio_store/blob_store.dart';
import 'package:studio_contracts/studio_contracts.dart';

Future<void> main(List<String> args) async {
  final store = BlobStore(
    Directory(args[0]),
    Namespace('studio', 'local', 'budget'),
  );
  await store.withNamespaceDiskReservation(32768, () async {
    final stage = File(
      '${store.directory.path}/.restore-019a0000-0000-7000-8000-000000000002',
    );
    stage.writeAsBytesSync(List.filled(16384, 1), flush: true);
    File('/dev/stdout')
        .writeAsStringSync('RESERVED_AND_WRITTEN\n', mode: FileMode.writeOnly);
    stdin.readByteSync(); // fixture parent kills real holder of stable OS lease
  });
}
