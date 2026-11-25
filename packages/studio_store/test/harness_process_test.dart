import 'dart:convert';
import 'dart:io';

import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/builtin_compute.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_document/studio_document.dart';
import 'package:test/test.dart';

import 'package:studio_harness/testing_fixtures.dart';

void main() {
  test('two REAL Linux child workers execute free CPU tasks in one persisted session; NOT physical-device/network qualification', () async {
    final dir = Directory.systemTemp.createTempSync('compute-process-'),
        ns = Namespace('studio', 'local', 'devices'),
        session = SessionRef(
          namespace: Namespace('studio', 'local', 'devices'),
          id: 'session',
        ),
        data = planFixture(Namespace('studio', 'local', 'devices'));
    final inputs = <String, Object?>{
      'a': {
        'payload': {'title': 'same session 🙂'},
      },
      'b': {
        'samples': [0.5, -0.5, 0.5, -0.5],
      },
    };
    data['limits']['maxWallMs'] = '30000';
    for (final node in data['nodes']) {
      node['timeoutMs'] = '10000';
      if (node['id'] == 'c') continue;
      node['handlerPin'] = BuiltinCompute.pin(
        node['id'] == 'a' ? 'core.digest-json' : 'core.pcm-rms',
      );
      node['inputRef']['hash'] = harnessHash(inputs[node['id']]);
    }
    final clock = Stopwatch()..start();
    final plan = HarnessPlan(data),
        repo = DocumentRepository.open('${dir.path}/db', ns);
    try {
      repo.create(
        ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'p'),
      );
      repo.registerHarnessPlan(
        session,
        'p',
        plan,
        coordinatorBoot: 'boot',
        nowMs: 0,
      );
      Future<Map<String, dynamic>> execute(String id) async {
        final node = plan.node(id),
            lease = repo.claimHarnessTask(
              session,
              plan.hash,
              id,
              deviceFixture('worker-$id', {
                id == 'a' ? 'compute.digest' : 'compute.audio',
              }),
              PlacementRequirement(),
              coordinatorBoot: 'boot',
              nowMs: 0,
              leaseMs: 10000,
            );
        final worker = await Process.start(Platform.resolvedExecutable, [
          'run',
          'packages/studio_harness/tool/compute_worker.dart',
        ]);
        worker.stdin.writeln(
          jsonEncode({
            'lease': lease.toJson(),
            'handlerPin': node['handlerPin'],
            'inputRef': node['inputRef'],
            'input': inputs[id],
          }),
        );
        await worker.stdin.close();
        final output = await worker.stdout.transform(utf8.decoder).join(),
            errors = await worker.stderr.transform(utf8.decoder).join();
        expect(await worker.exitCode, 0, reason: errors);
        final reply = jsonDecode(output) as Map<String, dynamic>;
        expect(reply['resultHash'], harnessHash(reply['result']));
        expect(reply['nodeId'], id);
        expect(reply['deviceId'], lease.deviceId);
        repo.finishHarnessTask(
          session,
          lease,
          reply['result'],
          coordinatorBoot: 'boot',
          nowMs: clock.elapsedMilliseconds,
        );
        return reply;
      }

      final results = await Future.wait([execute('a'), execute('b')]);
      expect(results.map((r) => r['workerPid']).toSet(), hasLength(2));
      expect(results[1]['result']['rms'], 0.5);
      expect(
        repo
            .harnessOutbox(session)
            .where((r) => r['kind'] == 'candidate.ready'),
        hasLength(2),
      );
      expect(repo.read('p')!.revision, BigInt.zero);
    } finally {
      repo.close();
      dir.deleteSync(recursive: true);
    }
  });
}
