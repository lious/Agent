import 'dart:convert';
import 'dart:io';

import 'package:studio_harness/device_scheduler.dart';
import 'package:studio_harness/builtin_compute.dart';

Future<void> main() async {
  // STDIO is a local test/development adapter, not authenticated device transport.
  final line = await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .first;
  if (line.length > 4 * 1024 * 1024) throw StateError('COMPUTE_INPUT_LIMIT');
  final request = jsonDecode(line) as Map<String, dynamic>,
      lease = taskLeaseFromJson(request['lease'] as Map<String, dynamic>),
      ref = request['inputRef'] as Map<String, dynamic>;
  if (harnessHash(ref) != lease.inputHash ||
      harnessHash(request['input']) != ref['hash']) {
    throw StateError('COMPUTE_INPUT_HASH_MISMATCH');
  }
  final result = BuiltinCompute.execute(
    request['handlerPin'] as Map<String, dynamic>,
    request['input'],
  );
  stdout.writeln(
    jsonEncode({
      'result': result,
      'resultHash': harnessHash(result),
      'nodeId': lease.nodeId,
      'deviceId': lease.deviceId,
      'workerPid': pid,
    }),
  );
}
