import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:studio_peer_io/compute_session.dart';

import 'package:crypto/crypto.dart';
import 'package:studio_document/studio_document.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:studio_harness/builtin_compute.dart';
import 'package:studio_harness/testing_fixtures.dart';
import 'package:studio_store/studio_store.dart';
import 'package:studio_peer_io/studio_peer_io.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));
final ns = Namespace('studio', 'local', 'tls-devices');
final session = SessionRef(namespace: ns, id: 'session');
late Directory certificates;
Future<void> openssl(List<String> args) async {
  final result = await Process.run(
    'openssl',
    args,
    workingDirectory: certificates.path,
  );
  if (result.exitCode != 0) {
    throw StateError('OpenSSL fixture generation failed: ${result.stderr}');
  }
}

String certPath(String name) => '${certificates.path}/$name.pem';
String fingerprint(String name) {
  final pem = File(certPath(name))
      .readAsLinesSync()
      .where((l) => !l.startsWith('-----'))
      .join();
  return sha256.convert(base64.decode(pem)).toString();
}

SecurityContext clientContext(String? name, {bool trust = true}) {
  final c = SecurityContext(withTrustedRoots: false);
  if (trust) {
    c.setTrustedCertificates(certPath('ca'));
  }
  if (name != null) {
    c.useCertificateChain(certPath(name));
    c.usePrivateKey('${certificates.path}/$name.key');
  }
  return c;
}

Future<void> makeCertificates() async {
  certificates = Directory.systemTemp.createTempSync('studio-tls-');
  await Process.run('chmod', ['700', certificates.path]);
  await openssl([
    'req',
    '-x509',
    '-newkey',
    'rsa:2048',
    '-nodes',
    '-keyout',
    'ca.key',
    '-out',
    'ca.pem',
    '-subj',
    '/CN=EphemeralTestCA',
    '-days',
    '1',
  ]);
  for (final name in ['server', 'alpha', 'beta', 'stranger']) {
    await openssl([
      'req',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-keyout',
      '$name.key',
      '-out',
      '$name.csr',
      '-subj',
      '/CN=$name',
    ]);
    File('${certificates.path}/$name.ext').writeAsStringSync(
      'basicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth,clientAuth\nsubjectAltName=IP:127.0.0.1,DNS:localhost\n',
    );
    await openssl([
      'x509',
      '-req',
      '-in',
      '$name.csr',
      '-CA',
      'ca.pem',
      '-CAkey',
      'ca.key',
      '-CAcreateserial',
      '-out',
      '$name.pem',
      '-days',
      '1',
      '-extfile',
      '$name.ext',
    ]);
    await Process.run('chmod', ['600', '${certificates.path}/$name.key']);
  }
  await Process.run('chmod', ['600', '${certificates.path}/ca.key']);
}

class Rig {
  Rig() {
    directory = Directory.systemTemp.createTempSync('studio-peer-db-');
    repository = DocumentRepository.open('${directory.path}/db', ns);
    repository.create(
      ProjectDocument.empty(namespace: ns, projectId: 'p', title: 'local'),
    );
    final raw = planFixture(ns);
    for (final node in raw['nodes']) {
      final input = node['id'] == 'b'
          ? <String, Object?>{
              'samples': [0.0, 0.5, -0.5, 1.0],
            }
          : <String, Object?>{
              'payload': {'unicode': '字幕', 'node': node['id']},
            };
      node['handlerPin'] = BuiltinCompute.pin(
        node['id'] == 'b' ? 'core.pcm-rms' : 'core.digest-json',
      );
      node['outputSchemaHash'] = BuiltinCompute.outputSchemaHash(
        node['handlerPin']['id'] as String,
      );
      node['inputRef']['hash'] = harnessHash(input);
      inputs[harnessHash(input)] = input;
    }
    plan = HarnessPlan(raw);
    repository.registerHarnessPlan(
      session,
      'p',
      plan,
      coordinatorBoot: 'boot',
      nowMs: 0,
    );
  }
  late Directory directory;
  late DocumentRepository repository;
  late HarnessPlan plan;
  final Map<String, Object?> inputs = {};
  PeerTlsServer? server;
  final clients = <PeerTlsClient>[];
  int now = 0;
  Stopwatch? realTime;
  int wall = DateTime.now().millisecondsSinceEpoch;
  int pair(
    String name,
    Set<String> nodes, {
    String? deviceId,
    Map<String, int> allowedBlobs = const {},
  }) {
    final offer = repository.createPeerOffer(
      session,
      plan.hash,
      certificateFingerprint: fingerprint(name),
      device: deviceFixture(deviceId ?? name, {
        'compute.digest',
        'compute.audio',
        'compute.reduce',
      }),
      nodeIds: nodes,
      nowMs: wall,
      offerExpiresMs: wall + 10000,
      grantExpiresMs: wall + 60000,
      allowedBlobs: allowedBlobs,
    );
    return repository.confirmPeerOffer(offer, fingerprint(name), nowMs: wall);
  }

  Future<void> start({String boot = 'boot'}) async {
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChain(certPath('server'))
      ..usePrivateKey('${certificates.path}/server.key')
      ..setTrustedCertificates(certPath('ca'))
      ..setClientAuthorities(certPath('ca'));
    server = await PeerTlsServer.bind(
      repository: repository,
      context: context,
      coordinatorBoot: boot,
      monotonicMs: () => realTime?.elapsedMilliseconds ?? now,
      wallMs: () => wall,
      inputsByHash: inputs,
    );
  }

  PeerTlsClient client(
    String? name, {
    String? pin,
    bool trust = true,
    int? port,
  }) {
    final c = PeerTlsClient(
      context: clientContext(name, trust: trust),
      endpoint: Uri.parse(
        'https://127.0.0.1:${port ?? server!.port}/studio/peer/v1',
      ),
      serverFingerprint: pin ?? fingerprint('server'),
    );
    clients.add(c);
    return c;
  }

  Map<String, dynamic> message(
    String id,
    String node,
    String op,
    Map<String, dynamic> payload, {
    int epoch = 1,
  }) => {
    'schemaVersion': '1.0.0',
    'id': id,
    'sessionId': 'session',
    'planHash': plan.hash,
    'epoch': '$epoch',
    'operation': op,
    'nodeId': node,
    'payload': payload,
  };
  Future<void> dispose() async {
    for (final c in clients) {
      c.close();
    }
    await server?.close();
    repository.close();
    directory.deleteSync(recursive: true);
  }
}

void main() {
  setUpAll(makeCertificates);
  tearDownAll(() => certificates.deleteSync(recursive: true));
  test('real mTLS two-worker same session CPU compute, heartbeat, candidate receipts, replay and reopen', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.pair('alpha', {'a'});
    r.pair('beta', {'b'});
    await r.start();
    final alpha = r.client('alpha'), beta = r.client('beta');
    final claims = await Future.wait([
      alpha.send(r.message('claim-a', 'a', 'claim', {'leaseMs': 500})),
      beta.send(r.message('claim-b', 'b', 'claim', {'leaseMs': 500})),
    ]);
    expect(r.repository.read('p')!.revision, BigInt.zero);
    r.now = 100;
    final heartbeat = await alpha.send(
      r.message('beat-a', 'a', 'heartbeat', {
        'lease': claims[0]['lease'],
        'progress': 0.5,
        'extendMs': 500,
      }),
    );
    final results = [
      for (final claim in claims)
        BuiltinCompute.execute(
          claim['handlerPin'] as Map<String, dynamic>,
          claim['input'],
        ),
    ];
    final finishA = r.message('finish-a', 'a', 'finish', {
      'lease': heartbeat['lease'],
      'result': results[0],
      'resultHash': harnessHash(results[0]),
    });
    final completed = await Future.wait([
      alpha.send(finishA),
      beta.send(
        r.message('finish-b', 'b', 'finish', {
          'lease': claims[1]['lease'],
          'result': results[1],
          'resultHash': harnessHash(results[1]),
        }),
      ),
    ]);
    expect(completed[0]['certificateFingerprint'], fingerprint('alpha'));
    expect(completed[1]['deviceId'], 'beta');
    expect(await alpha.send(finishA), completed[0]);
    expect(
      r.repository
          .harnessOutbox(session)
          .where((e) => e['kind'] == 'candidate.ready'),
      hasLength(2),
    );
    alpha.close();
    beta.close();
    await r.server!.close();
    r.repository.close();
    r.repository = DocumentRepository.open('${r.directory.path}/db', ns);
    await r.start();
    expect(await r.client('alpha').send(finishA), completed[0]);
  });
  test('offline one-time confirmation, TTL, wrong fingerprint, deny unpaired/no cert/wrong scope', () async {
    final r = Rig();
    addTearDown(r.dispose);
    final offer = r.repository.createPeerOffer(
      session,
      r.plan.hash,
      certificateFingerprint: fingerprint('alpha'),
      device: deviceFixture('alpha', {'compute.digest'}),
      nodeIds: {'a'},
      nowMs: r.wall,
      offerExpiresMs: r.wall + 100,
      grantExpiresMs: r.wall + 1000,
    );
    expect(
      () => r.repository.confirmPeerOffer(
        offer,
        fingerprint('beta'),
        nowMs: r.wall,
      ),
      code('PAIRING_CONFIRMATION_MISMATCH'),
    );
    expect(
      r.repository.confirmPeerOffer(offer, fingerprint('alpha'), nowMs: r.wall),
      1,
    );
    expect(
      () => r.repository.confirmPeerOffer(
        offer,
        fingerprint('alpha'),
        nowMs: r.wall,
      ),
      code('PAIRING_OFFER_EXPIRED_OR_USED'),
    );
    final expires = r.repository.createPeerOffer(
      session,
      r.plan.hash,
      certificateFingerprint: fingerprint('beta'),
      device: deviceFixture('beta', {'compute.audio'}),
      nodeIds: {'b'},
      nowMs: r.wall,
      offerExpiresMs: r.wall + 100,
      grantExpiresMs: r.wall + 1000,
    );
    expect(
      () => r.repository.confirmPeerOffer(
        expires,
        fingerprint('beta'),
        nowMs: r.wall + 100,
      ),
      code('PAIRING_OFFER_EXPIRED_OR_USED'),
    );
    await r.start();
    await expectLater(
      r.client('stranger').send(r.message('x', 'a', 'claim', {'leaseMs': 500})),
      code('PEER_NOT_AUTHORIZED'),
    );
    await expectLater(
      r.client(null).send(r.message('x', 'a', 'claim', {'leaseMs': 500})),
      code('PEER_CERTIFICATE_REQUIRED'),
    );
    await expectLater(
      r.client('alpha').send(r.message('x', 'b', 'claim', {'leaseMs': 500})),
      code('PEER_NOT_AUTHORIZED'),
    );
    await expectLater(
      r
          .client('alpha')
          .send(r.message('x', 'a', 'claim', {'leaseMs': 500}, epoch: 2)),
      code('PEER_NOT_AUTHORIZED'),
    );
  });
  test('revocation rechecks existing TLS connection and persisted replay; expired grant and clock rollback fail closed', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.pair('alpha', {'a'});
    await r.start();
    final c = r.client('alpha'),
        request = r.message('a', 'a', 'claim', {'leaseMs': 500});
    await c.send(request);
    r.repository.revokePeer(
      fingerprint('alpha'),
      session,
      r.plan.hash,
      nowMs: r.wall,
    );
    await expectLater(c.send(request), code('PEER_NOT_AUTHORIZED'));
    expect(
      r.repository.harnessStep(session, r.plan.hash, 'a')!.status,
      'running',
    ); // no false stop acknowledgment
    final epoch = r.pair('alpha', {'a'});
    expect(epoch, 3);
    await expectLater(c.send(request), code('PEER_NOT_AUTHORIZED'));
    r.wall += 60000;
    await expectLater(
      c.send(
        r.message('expired', 'a', 'claim', {'leaseMs': 500}, epoch: epoch),
      ),
      code('PEER_GRANT_EXPIRED'),
    );
    r.wall -= 60001;
    await expectLater(
      c.send(r.message('clock', 'a', 'claim', {'leaseMs': 500}, epoch: epoch)),
      code('PEER_CLOCK_ROLLBACK'),
    );
  });
  test('actual SQLite receipt insertion failure rolls back nested dispatch/outbox/binding and safe retry', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.pair('alpha', {'a'});
    await r.start();
    final injection = sqlite3.open('${r.directory.path}/db');
    addTearDown(injection.dispose);
    injection.execute(
      "CREATE TRIGGER fail_peer BEFORE INSERT ON peer_requests BEGIN SELECT RAISE(ABORT,'injected'); END",
    );
    final c = r.client('alpha'),
        req = r.message('claim', 'a', 'claim', {'leaseMs': 500});
    await expectLater(c.send(req), code('PEER_INVALID_REQUEST'));
    expect(r.repository.harnessStep(session, r.plan.hash, 'a'), isNull);
    expect(r.repository.harnessOutbox(session), isEmpty);
    expect(injection.select('SELECT * FROM peer_task_bindings'), isEmpty);
    injection.execute('DROP TRIGGER fail_peer');
    final claim = await c.send(req);
    expect(claim['lease']['fence'], '1');
    expect(await c.send(req), claim);
    await expectLater(
      c.send({
        ...req,
        'payload': {'leaseMs': 400},
      }),
      code('IDEMPOTENCY_CONFLICT'),
    );
  });
  test('trusted CA is insufficient: exact server pin, TLS validation and no certificate bypass; unreachable explicit', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.pair('alpha', {'a'});
    await r.start();
    final req = r.message('a', 'a', 'claim', {'leaseMs': 500});
    await expectLater(
      r.client('alpha', pin: fingerprint('beta')).send(req),
      code('PEER_SERVER_PIN_MISMATCH'),
    );
    await expectLater(
      r.client('alpha', trust: false).send(req),
      code('PEER_TLS_REJECTED'),
    );
    expect(r.repository.harnessStep(session, r.plan.hash, 'a'), isNull);
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
        port = socket.port;
    await socket.close();
    await expectLater(
      r.client('alpha', port: port).send(req),
      code('DIRECT_UNREACHABLE'),
    );
  });
  test('one heavy slot per authenticated device; expiry redispatch fences old results and source/hash checks reject forgery', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.pair('alpha', {'a', 'b'});
    r.pair('beta', {'a', 'b'});
    await r.start();
    final a = r.client('alpha'), b = r.client('beta');
    final first = await a.send(r.message('a', 'a', 'claim', {'leaseMs': 500}));
    await expectLater(
      a.send(r.message('b', 'b', 'claim', {'leaseMs': 500})),
      code('DEVICE_RESOURCE_BUSY'),
    );
    final result = BuiltinCompute.execute(
      first['handlerPin'] as Map<String, dynamic>,
      first['input'],
    );
    final finish = r.message('finish', 'a', 'finish', {
      'lease': first['lease'],
      'result': result,
      'resultHash': harnessHash(result),
    });
    await expectLater(b.send(finish), code('PEER_RESULT_SOURCE'));
    await expectLater(
      a.send({
        ...finish,
        'payload': {
          ...finish['payload'] as Map<String, dynamic>,
          'resultHash': '0' * 64,
        },
      }),
      code('COMPUTE_RESULT_HASH'),
    );
    r.now = 500;
    final retry = await b.send(
      r.message('retry', 'a', 'claim', {'leaseMs': 500}),
    );
    expect(retry['lease']['fence'], '2');
    await expectLater(a.send(finish), code('LEASE_FENCED'));
    final second = await a.send(r.message('b', 'b', 'claim', {'leaseMs': 500}));
    expect(second['lease']['deviceId'], 'alpha');
  });
  test('two actual native child processes compute via authenticated HTTPS in one persisted session; same host only', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.pair('alpha', {'a'});
    r.pair('beta', {'b'});
    r.realTime = Stopwatch()..start();
    await r.start();
    Future<ProcessResult> worker(String name, String node) =>
        Process.run(Platform.resolvedExecutable, [
          'run',
          'packages/studio_peer_io/tool/peer_worker.dart',
          'https://127.0.0.1:${r.server!.port}/studio/peer/v1',
          certPath('ca'),
          certPath(name),
          '${certificates.path}/$name.key',
          fingerprint('server'),
          'session',
          r.plan.hash,
          node,
          '1',
        ]);
    final results = await Future.wait([
      worker('alpha', 'a'),
      worker('beta', 'b'),
    ]);
    for (final result in results) {
      expect(result.exitCode, 0, reason: result.stderr as String);
      expect(jsonDecode(result.stdout as String)['disposition'], 'candidate');
    }
    expect(
      r.repository.harnessStep(session, r.plan.hash, 'a')!.status,
      'committed',
    );
    expect(
      r.repository.harnessStep(session, r.plan.hash, 'b')!.status,
      'committed',
    );
    expect(r.repository.read('p')!.revision, BigInt.zero);
  });
  test('closed result schema, payload bounds and lost-claim replay cannot extend a lease', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.pair('alpha', {'a'});
    await r.start();
    final c = r.client('alpha');
    final request = r.message('claim', 'a', 'claim', {'leaseMs': 500}),
        claim = await c.send(request);
    r.now = 100;
    final replay = await c.send(request);
    expect(replay['remainingMs'], 400);
    await expectLater(
      c.send(
        r.message('malformed', 'a', 'finish', {
          'lease': claim['lease'],
          'result': {'untrusted': 'object'},
          'resultHash': harnessHash({'untrusted': 'object'}),
        }),
      ),
      code('COMPUTE_RESULT_SCHEMA'),
    );
    Object deep = 0;
    for (var i = 0; i < 34; i++) {
      deep = [deep];
    }
    await expectLater(
      c.send({
        ...request,
        'payload': {'nested': deep},
      }),
      code('PEER_INPUT_LIMIT'),
    );
    await expectLater(
      c.send({
        ...request,
        'payload': {'huge': 'x' * (1024 * 1024 + 1)},
      }),
      code('PEER_INPUT_LIMIT'),
    );
    r.now = 500;
    await expectLater(c.send(request), code('LEASE_FENCED'));
  });
  test('authenticated network endpoints are fenced by local-owner takeover; new boot retries without resetting authority', () async {
    final r = Rig();
    addTearDown(r.dispose);
    r.pair('alpha', {'a'});
    r.pair('beta', {'a'});
    await r.start();
    final alpha = r.client('alpha'),
        first = await alpha.send(
          r.message('claim', 'a', 'claim', {'leaseMs': 500}),
        );
    r.repository.takeoverHarnessPlan(
      session,
      r.plan.hash,
      expectedBoot: 'boot',
      newBoot: 'new',
      operationId: 'local-owner',
      unobservedElapsedUpperBoundMs: 100,
    );
    await expectLater(
      alpha.send(
        r.message('beat', 'a', 'heartbeat', {
          'lease': first['lease'],
          'progress': 0.5,
          'extendMs': 100,
        }),
      ),
      code('COORDINATOR_FENCED'),
    );
    await r.server!.close();
    await r.start(boot: 'new');
    final newAlpha = r.client('alpha'),
        result = BuiltinCompute.execute(
          first['handlerPin'] as Map<String, dynamic>,
          first['input'],
        );
    await expectLater(
      newAlpha.send(
        r.message('late', 'a', 'finish', {
          'lease': first['lease'],
          'result': result,
          'resultHash': harnessHash(result),
        }),
      ),
      code('LEASE_FENCED'),
    );
    final retry = await r
        .client('beta')
        .send(r.message('retry', 'a', 'claim', {'leaseMs': 500}));
    expect(retry['lease']['fence'], '2');
    expect(retry['lease']['coordinatorBoot'], 'new');
  });
  test('real TLS hash-whitelisted chunk resume survives receiver reopen, final hash and duplicate commit', () async {
    final r = Rig();
    addTearDown(r.dispose);
    final bytes = Uint8List.fromList(
          List.generate(131085, (i) => (i * 17) % 251),
        ),
        hash = rawBytesHash(
          Uint8List.fromList(List.generate(131085, (i) => (i * 17) % 251)),
        ).substring(7);
    r.pair('alpha', {'a'}, allowedBlobs: {hash: bytes.length});
    await r.start();
    final c = r.client('alpha');
    await c.send(r.message('begin', 'a', 'blob.begin', {'blobHash': hash}));
    final part = Uint8List.sublistView(bytes, 0, 65536);
    await c.send(
      r.message('part0', 'a', 'blob.chunk', {
        'blobHash': hash,
        'index': 0,
        'base64': base64.encode(part),
        'chunkHash': rawBytesHash(part).substring(7),
      }),
    );
    final alternateEncoding = base64Url.encode(part);
    expect(alternateEncoding, isNot(base64.encode(part)));
    await c.send(
      r.message('same-bytes-alternate-base64', 'a', 'blob.chunk', {
        'blobHash': hash,
        'index': 0,
        'base64': alternateEncoding,
        'chunkHash': rawBytesHash(part).substring(7),
      }),
    );
    await r.server!.close();
    r.repository.close();
    r.repository = DocumentRepository.open('${r.directory.path}/db', ns);
    await r.start();
    final fresh = r.client('alpha'),
        invite = <String, dynamic>{
          'schemaVersion': '1.0.0',
          'sessionId': 'session',
          'planHash': r.plan.hash,
          'nodeIds': ['a'],
          'epoch': '1',
          'allowedBlobs': {hash: bytes.length},
        };
    final status = await fresh.send(
      r.message('status', 'a', 'blob.status', {'blobHash': hash}),
    );
    expect(status['received'], [0]);
    final finished = await uploadPeerBlob(
      fresh,
      invite,
      'a',
      bytes,
      operationId: 'resume',
    );
    expect(finished['committed'], isTrue);
    expect(r.repository.receivedPeerBlob(hash), orderedEquals(bytes));
    await fresh.send(
      r.message('again', 'a', 'blob.finish', {'blobHash': hash}),
    );
    expect(
      r.repository
          .harnessOutbox(session)
          .where((e) => e['kind'] == 'peer.blob.ready'),
      hasLength(1),
    );
    expect(r.repository.read('p')!.revision, BigInt.zero);
  });
  test('real TLS blob rejects missing consent, bad chunk/hash/conflicts and revoked replays; final outbox failure rolls back object', () async {
    final r = Rig();
    addTearDown(r.dispose);
    final bytes = Uint8List.fromList([1, 2, 3, 4]),
        hash = rawBytesHash(Uint8List.fromList([1, 2, 3, 4])).substring(7);
    r.pair('alpha', {'a'}, allowedBlobs: {hash: 4});
    r.pair('beta', {'a'});
    await r.start();
    final c = r.client('alpha');
    final begin = r.message('begin', 'a', 'blob.begin', {'blobHash': hash});
    await expectLater(
      r.client('beta').send(begin),
      code('PEER_BLOB_NOT_GRANTED'),
    );
    await c.send(begin);
    await expectLater(
      c.send(r.message('early', 'a', 'blob.finish', {'blobHash': hash})),
      code('PEER_BLOB_INCOMPLETE'),
    );
    await expectLater(
      c.send(
        r.message('bad', 'a', 'blob.chunk', {
          'blobHash': hash,
          'index': 0,
          'base64': base64.encode(bytes),
          'chunkHash': '0' * 64,
        }),
      ),
      code('PEER_BLOB_CHUNK_HASH'),
    );
    await c.send(
      r.message('chunk', 'a', 'blob.chunk', {
        'blobHash': hash,
        'index': 0,
        'base64': base64.encode(bytes),
        'chunkHash': rawBytesHash(bytes).substring(7),
      }),
    );
    final changed = Uint8List.fromList([4, 3, 2, 1]);
    await expectLater(
      c.send(
        r.message('changed', 'a', 'blob.chunk', {
          'blobHash': hash,
          'index': 0,
          'base64': base64.encode(changed),
          'chunkHash': rawBytesHash(changed).substring(7),
        }),
      ),
      code('PEER_BLOB_CHUNK_CONFLICT'),
    );
    final injection = sqlite3.open('${r.directory.path}/db');
    injection.execute(
      "CREATE TRIGGER fail_blob BEFORE INSERT ON harness_outbox WHEN NEW.kind='peer.blob.ready' BEGIN SELECT RAISE(ABORT,'injected'); END",
    );
    final finish = r.message('finish', 'a', 'blob.finish', {'blobHash': hash});
    await expectLater(c.send(finish), code('PEER_INVALID_REQUEST'));
    expect(r.repository.receivedPeerBlob(hash), isNull);
    injection.execute('DROP TRIGGER fail_blob');
    injection.dispose();
    expect((await c.send(finish))['committed'], isTrue);
    r.repository.revokePeer(
      fingerprint('alpha'),
      session,
      r.plan.hash,
      nowMs: r.wall,
    );
    await expectLater(c.send(finish), code('PEER_NOT_AUTHORIZED'));
  });
}
