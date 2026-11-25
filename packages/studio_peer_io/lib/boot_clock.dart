import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:studio_contracts/studio_contracts.dart';

final class _Timespec extends Struct {
  @Int64()
  external int seconds;
  @Int64()
  external int nanoseconds;
}

/// Linux kernel CLOCK_BOOTTIME includes suspend and is continuous across app
/// processes within ONE OS boot. Not peer time, user wall time or guessed uptime.
final class LinuxBootClock {
  static Map<String, Object>? anchor() {
    if (!Platform.isLinux || sizeOf<IntPtr>() != 8) return null;
    final boot = File('/proc/sys/kernel/random/boot_id')
        .readAsStringSync()
        .trim();
    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(boot)) {
      throw const StudioException('KERNEL_CLOCK_UNAVAILABLE');
    }
    return {
      'schemaVersion': 'linux-boottime-1',
      'bootId': boot,
      'tickMs': ticksMs(),
    };
  }

  static int ticksMs() {
    if (!Platform.isLinux || sizeOf<IntPtr>() != 8) {
      throw const StudioException('KERNEL_CLOCK_UNAVAILABLE');
    }
    final now = calloc<_Timespec>();
    try {
      final call = DynamicLibrary.process()
          .lookupFunction<
            Int32 Function(Int32, Pointer<_Timespec>),
            int Function(int, Pointer<_Timespec>)
          >('clock_gettime');
      if (call(7, now) != 0 ||
          now.ref.seconds < 0 ||
          now.ref.nanoseconds < 0 ||
          now.ref.nanoseconds >= 1000000000) {
        throw const StudioException('KERNEL_CLOCK_UNAVAILABLE');
      }
      return now.ref.seconds * 1000 + now.ref.nanoseconds ~/ 1000000;
    } finally {
      calloc.free(now);
    }
  }
}
