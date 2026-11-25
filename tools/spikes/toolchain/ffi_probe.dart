import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef OpenNative = Uint64 Function(Pointer<Utf8>);
typedef OpenDart = int Function(Pointer<Utf8>);
typedef CheckNative = Int32 Function(Uint64, Pointer<Utf8>);
typedef CheckDart = int Function(int, Pointer<Utf8>);
void main(List<String> args) {
  if (args.length != 1) throw ArgumentError('Expected compiled probe library');
  final lib = DynamicLibrary.open(args.single);
  final version = lib.lookupFunction<Uint32 Function(), int Function()>(
    'studio_probe_abi_version',
  );
  final echo = lib.lookupFunction<Int64 Function(Int64), int Function(int)>(
    'studio_probe_echo_i64',
  );
  final open = lib.lookupFunction<OpenNative, OpenDart>('studio_probe_open');
  final check = lib.lookupFunction<CheckNative, CheckDart>(
    'studio_probe_check',
  );
  final close = lib.lookupFunction<Int32 Function(Uint64), int Function(int)>(
    'studio_probe_close',
  );
  final time = lib
      .lookupFunction<Int32 Function(Int64, Uint32), int Function(int, int)>(
        'studio_probe_time',
      );
  void expect(bool value) {
    if (!value) throw StateError('C ABI probe assertion');
  }

  final a = '["studio","local","w"]'.toNativeUtf8();
  final b = '["image","local","w"]'.toNativeUtf8();
  try {
    expect(version() == 1);
    expect(echo(9223372036854775807) == 9223372036854775807);
    expect(echo(-9223372036854775808) == -9223372036854775808);
    final ha = open(a), hb = open(b);
    expect(ha != 0 && hb != 0 && ha != hb);
    expect(check(ha, a) == 0 && check(hb, b) == 0);
    expect(check(ha, b) == -2 && check(hb, a) == -2);
    expect(time(9223372036854775807, 1) == 0);
    expect(time(-9223372036854775808, 1000000000) == 0);
    expect(time(1, 0) == -3 && time(1, 1000000001) == -3);
    expect(close(ha) == 0 && check(ha, a) == -1 && close(ha) == -1);
    expect(check(hb, b) == 0 && close(hb) == 0);
    stdout.writeln('C_ABI_PROBE_OK abi=1 namespaceIsolation=true');
  } finally {
    malloc.free(a);
    malloc.free(b);
  }
}
