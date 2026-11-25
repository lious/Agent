// Caller-owned isolated SQL crash qualification fixture ONLY.
import 'dart:io';

import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';

void main(List<String> args) {
  if (args.length != 1) throw ArgumentError('fixture DB required');
  final path = File(args.single).parent.resolveSymbolicLinksSync();
  if (!path.startsWith(
    '${Directory.systemTemp.resolveSymbolicLinksSync()}/import-map-',
  )) {
    throw ArgumentError('isolated fixture only');
  }
  final ns = Namespace('test', 'local', 'imports'),
      repo = DocumentRepository.open(
        args.single,
        Namespace('test', 'local', 'imports'),
      );
  try {
    final writer = repo.acquireWriter(
      'current',
      'crash-worker',
      expectedEpoch: repo.writerEpoch('current'),
    );
    var i = 0;
    repo.createResourceFork(
      source: ProjectDocument.empty(
        namespace: ns,
        projectId: 'source',
        title: 'source',
      ),
      activeWriter: writer,
      expectedActiveHash: repo.read('current')!.hash,
      newId: () {
        if (repo.importMap('crash-fork') != null) {
          File('/dev/stdout').writeAsStringSync(
            'IMPORTED_UNCOMMITTED\n',
            mode: FileMode.writeOnly,
            flush: false,
          );
          if (stdin.readByteSync() < 0) {
            throw StateError('barrier closed before SIGKILL');
          }
        }
        return i++ == 0 ? 'crash-fork' : 'crash-$i';
      },
    );
  } finally {
    repo.close();
  }
}
