// Synthetic no-clobber race qualification, isolated fixtures only.
import 'dart:io';

import 'package:studio_store/atomic_file.dart';
import 'package:studio_contracts/studio_contracts.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('fixture directory and worker index');
  }
  final root = Directory(args[0]).resolveSymbolicLinksSync();
  if (!root.startsWith(
    '${Directory.systemTemp.resolveSymbolicLinksSync()}/resource-preservation-',
  )) {
    throw ArgumentError('isolated resource-preservation fixture only');
  }
  final target = File('$root/process-race.json'),
      publisher = AtomicFilePublisher();
  final stage = publisher.stagingFor(target);
  try {
    stage.createSync(exclusive: true);
    stage.writeAsStringSync('{"winner":${args[1]}}', flush: true);
    stdout.writeln('READY');
    await stdout.flush();
    final signal = await stdin.first;
    if (signal.length != 1 || signal.single != 1) {
      throw StateError('one-byte prepared-publish barrier required');
    }
    try {
      publisher.publishNew(stage, target);
    } on StudioException catch (e) {
      if (!{'OUTPUT_ALREADY_EXISTS', 'OUTPUT_NOT_PUBLISHED'}.contains(e.code)) {
        rethrow;
      }
      exitCode = 7;
    }
  } finally {
    if (stage.existsSync()) {
      stage.deleteSync();
    }
  }
}
