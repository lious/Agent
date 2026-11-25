import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart' show Uuid;
import 'package:studio_contracts/studio_contracts.dart';

/// POSIX same-directory publication: flush staging bytes, rename, fsync directory.
/// No copy fallback masquerades as atomic replacement. Other providers need ports.
final class AtomicFilePublisher {
  File stagingFor(File destination) {
    if (!Platform.isLinux) {
      throw const StudioException('ATOMIC_STORAGE_PLATFORM_UNVALIDATED');
    }
    final parent = destination.absolute.parent;
    if (!parent.existsSync() ||
        p.normalize(parent.resolveSymbolicLinksSync()) !=
            p.normalize(parent.path)) {
      throw const StudioException('UNSAFE_OUTPUT_DIRECTORY');
    }
    final type = FileSystemEntity.typeSync(
      destination.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.file) {
      throw const StudioException('UNSAFE_OUTPUT_TARGET');
    }
    return File(p.join(parent.path, '.studio-${const Uuid().v7()}.pending'));
  }

  void publish(File stage, File destination) {
    if (stage.absolute.parent.path != destination.absolute.parent.path) {
      throw const StudioException('ATOMIC_RENAME_REQUIRES_SIBLING');
    }
    final check = stagingFor(
      destination,
    ); // Re-check authority/path before the side effect; no file is created.
    if (check.parent.path != stage.parent.path) {
      throw const StudioException('UNSAFE_OUTPUT_DIRECTORY');
    }
    if (FileSystemEntity.typeSync(stage.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const StudioException('INVALID_STAGING_FILE');
    }
    final handle = stage.openSync(mode: FileMode.append);
    try {
      handle.flushSync();
    } finally {
      handle.closeSync();
    }
    stage.renameSync(destination.absolute.path);
    _syncParent(destination);
  }

  void syncPublished(File destination) {
    stagingFor(destination);
    final handle = destination.openSync(mode: FileMode.append);
    try {
      handle.flushSync();
    } finally {
      handle.closeSync();
    }
    _syncParent(destination);
  }

  void _syncParent(File destination) {
    final lib = DynamicLibrary.process();
    final open = lib
        .lookupFunction<
          Int32 Function(Pointer<Utf8>, Int32),
          int Function(Pointer<Utf8>, int)
        >('open');
    final sync = lib.lookupFunction<Int32 Function(Int32), int Function(int)>(
      'fsync',
    );
    final close = lib.lookupFunction<Int32 Function(Int32), int Function(int)>(
      'close',
    );
    final dir = destination.absolute.parent.path.toNativeUtf8();
    try {
      final fd = open(dir, 0x10000); // Linux O_DIRECTORY | O_RDONLY
      if (fd < 0) throw const StudioException('PUBLISH_DURABILITY_UNKNOWN');
      try {
        if (sync(fd) != 0) {
          throw const StudioException('PUBLISH_DURABILITY_UNKNOWN');
        }
      } finally {
        close(fd);
      }
    } finally {
      malloc.free(dir);
    }
  }

  void write(File destination, List<int> bytes) {
    final stage = stagingFor(destination);
    try {
      stage.createSync(exclusive: true);
      stage.writeAsBytesSync(bytes, flush: true);
      publish(stage, destination);
    } finally {
      if (stage.existsSync()) stage.deleteSync();
    }
  }
}
