// Native DEVELOPMENT command runner. PEM identity keys here are generated test
// fixtures only, not production OS identity storage. Never accepts shell/model
// payloads, auto-pairs, trusts a first peer or silently uploads local files.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:studio_peer_io/studio_peer_io.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/builtin_compute.dart';

Future<void> main(List<String> args) async {
  if (args.length != 9) {
    stderr.writeln(
      'Expected endpoint CA cert key serverFingerprint session plan node grantEpoch',
    );
    exitCode = 64;
    return;
  }
  PeerTlsClient? client;
  try {
    final context = SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificates(args[1])
      ..useCertificateChain(args[2])
      ..usePrivateKey(args[3]);
    client = PeerTlsClient(
      context: context,
      endpoint: Uri.parse(args[0]),
      serverFingerprint: args[4],
    );
    Map<String, dynamic> request(String op, Map<String, dynamic> payload) => {
      'schemaVersion': '1.0.0',
      'id': 'native-${args[7]}-$op',
      'sessionId': args[5],
      'planHash': args[6],
      'nodeId': args[7],
      'epoch': args[8],
      'operation': op,
      'payload': payload,
    };
    final timer = Stopwatch()..start();
    final claim = await client.send(request('claim', {'leaseMs': 1000}));
    if (harnessHash(claim['input']) != claim['contentHash']) {
      throw const FormatException('Input hash');
    }
    final input = claim['input'],
        pin = claim['handlerPin'] as Map<String, dynamic>;
    final remaining = claim['remainingMs'] as int;
    final result = await Isolate.run(() => BuiltinCompute.execute(pin, input));
    if (timer.elapsedMilliseconds >= remaining) {
      throw const FormatException('Lease expired locally');
    }
    final response = await client.send(
      request('finish', {
        'lease': claim['lease'],
        'result': result,
        'resultHash': harnessHash(result),
      }),
    );
    stdout.writeln(jsonEncode(response));
  } catch (_) {
    stderr.writeln(
      'PEER_WORKER_FAILED: no automatic retry, relay or authority escalation',
    );
    exitCode = 1;
  } finally {
    client?.close();
  }
}
