part of 'studio_store.dart';

void _peerHash(String value) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const StudioException('PEER_FINGERPRINT_INVALID');
  }
}

Map<String, dynamic> _peerDeviceJson(VerifiedDevice d) => {
  'id': d.id,
  'platform': d.platform,
  'runtimeHash': d.runtimeHash,
  'capabilities': d.capabilities.toList()..sort(),
  'modelHashes': d.modelHashes.toList()..sort(),
  'sessionIds': d.sessionIds.toList()..sort(),
  'freeMemoryBytes': d.freeMemoryBytes,
  'load': d.load,
  'foreground': d.foreground,
};
VerifiedDevice _peerDevice(Map<String, dynamic> d, int epoch) => VerifiedDevice(
  id: d['id'] as String,
  platform: d['platform'] as String,
  runtimeHash: d['runtimeHash'] as String,
  capabilities: Set<String>.from(d['capabilities'] as List),
  modelHashes: Set<String>.from(d['modelHashes'] as List),
  sessionIds: Set<String>.from(d['sessionIds'] as List),
  freeMemoryBytes: d['freeMemoryBytes'] as int,
  load: (d['load'] as num).toDouble(),
  permissionEpoch: epoch,
  foreground: d['foreground'] as bool,
);

/// Local administrative APIs only: pairing confirmation/revocation and trusted
/// qualification NEVER have HTTP routes. Certificates are public; keys are not
/// stored here. A fingerprint is an ACL lookup, NOT proof of possession: callers
/// of executePeerRequest MUST obtain it from a successfully verified mTLS socket.
extension PeerAuthority on DocumentRepository {
  void _peerClock(int nowMs) {
    if (nowMs < 0 || nowMs > 9007199254740991) {
      throw const StudioException('PEER_CLOCK_RANGE');
    }
    final rows = _db.select('SELECT last_ms FROM peer_clock WHERE ns=?', [_ns]);
    if (rows.isNotEmpty && nowMs < (rows.single['last_ms'] as int)) {
      throw const StudioException('PEER_CLOCK_ROLLBACK');
    }
    _db.execute(
      'INSERT INTO peer_clock VALUES(?,?) ON CONFLICT(ns) DO UPDATE SET last_ms=excluded.last_ms',
      [_ns, nowMs],
    );
  }

  /// An offline, one-time offer is created locally AFTER certificate fingerprint
  /// exchange and runtime qualification. It expires within five minutes. Local
  /// UI/operator must compare the full certificate SHA256 out of band on both
  /// devices. No TOFU, short-code crypto, default grant or remote auto-enrolment.
  String createPeerOffer(
    SessionRef session,
    String planHash, {
    required String certificateFingerprint,
    required VerifiedDevice device,
    required Set<String> nodeIds,
    required int nowMs,
    required int offerExpiresMs,
    required int grantExpiresMs,
    Map<String, int> allowedBlobs = const {},
  }) => _transaction(() {
    _peerClock(nowMs);
    _peerHash(certificateFingerprint);
    final row = _planRow(session, planHash),
        plan = HarnessPlan(
          jsonDecode(row['json'] as String) as Map<String, dynamic>,
        );
    if (device.revoked ||
        !device.sessionIds.contains(session.id) ||
        nodeIds.isEmpty ||
        nodeIds.length > 64 ||
        offerExpiresMs <= nowMs ||
        offerExpiresMs > nowMs + 300000 ||
        grantExpiresMs <= offerExpiresMs ||
        grantExpiresMs > nowMs + 86400000) {
      throw const StudioException('PAIRING_SCOPE_INVALID');
    }
    for (final node in nodeIds) {
      plan.node(node);
    }
    if (allowedBlobs.length > 2) throw const StudioException('PEER_BLOB_QUOTA');
    for (final entry in allowedBlobs.entries) {
      _peerHash(entry.key);
      if (entry.value < 0 || entry.value > 16 * 1024 * 1024) {
        throw const StudioException('PEER_BLOB_QUOTA');
      }
    }
    final id = const Uuid().v4(),
        value = {
          'schemaVersion': '1.0.0',
          'fingerprint': certificateFingerprint,
          'sessionId': session.id,
          'planHash': planHash,
          'device': _peerDeviceJson(device),
          'nodeIds': nodeIds.toList()..sort(),
          'expiresMs': grantExpiresMs,
          'allowedBlobs': Map<String, int>.from(allowedBlobs),
        };
    _db.execute('INSERT INTO peer_offers VALUES(?,?,?,?,0)', [
      _ns,
      id,
      jsonEncode(value),
      offerExpiresMs,
    ]);
    return id;
  });

  int confirmPeerOffer(
    String offerId,
    String confirmedFingerprint, {
    required int nowMs,
  }) => _transaction(() {
    _peerClock(nowMs);
    _peerHash(confirmedFingerprint);
    final rows = _db.select('SELECT * FROM peer_offers WHERE ns=? AND id=?', [
      _ns,
      offerId,
    ]);
    if (rows.length != 1 ||
        rows.single['used'] != 0 ||
        nowMs >= (rows.single['expires_ms'] as int)) {
      throw const StudioException('PAIRING_OFFER_EXPIRED_OR_USED');
    }
    final data =
        jsonDecode(rows.single['json'] as String) as Map<String, dynamic>;
    if (data['fingerprint'] != confirmedFingerprint) {
      throw const StudioException('PAIRING_CONFIRMATION_MISMATCH');
    }
    final previous = _db.select(
      'SELECT epoch FROM peer_grants WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=?',
      [_ns, confirmedFingerprint, data['sessionId'], data['planHash']],
    );
    final epoch = previous.isEmpty ? 1 : (previous.single['epoch'] as int) + 1;
    if (epoch > 9007199254740991) {
      throw const StudioException('PEER_EPOCH_EXHAUSTED');
    }
    _db.execute(
      'INSERT INTO peer_grants VALUES(?,?,?,?,?,?,0) ON CONFLICT(ns,fingerprint,session_id,plan_hash) DO UPDATE SET epoch=excluded.epoch,json=excluded.json,revoked=0',
      [
        _ns,
        confirmedFingerprint,
        data['sessionId'],
        data['planHash'],
        epoch,
        jsonEncode(data),
      ],
    );
    _db.execute('UPDATE peer_offers SET used=1 WHERE ns=? AND id=?', [
      _ns,
      offerId,
    ]);
    return epoch;
  });

  void revokePeer(
    String fingerprint,
    SessionRef session,
    String planHash, {
    required int nowMs,
  }) => _transaction(() {
    _peerClock(nowMs);
    session.requireScope(namespace);
    _db.execute(
      'UPDATE peer_grants SET revoked=1,epoch=epoch+1 WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND revoked=0',
      [_ns, fingerprint, session.id, planHash],
    );
    final bound = _db.select(
      'SELECT DISTINCT node_id FROM peer_task_bindings WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=?',
      [_ns, fingerprint, session.id, planHash],
    );
    for (final row in bound) {
      final node = row['node_id'] as String,
          state = harnessStep(session, planHash, node);
      if (state != null &&
          state.status == 'running' &&
          state.lease.deviceId ==
              _peerGrantedDeviceId(fingerprint, session, planHash)) {
        // Revoke authorization immediately, but retain the occupied slot until
        // lease expiry. Do not pretend a disconnected worker has stopped.
        _harnessOutbox(session, state.lease, 'device.revoked', {
          'fingerprint': fingerprint,
        });
      }
    }
  });
  String? _peerGrantedDeviceId(
    String fingerprint,
    SessionRef session,
    String planHash,
  ) {
    final rows = _db.select(
      'SELECT json FROM peer_grants WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=?',
      [_ns, fingerprint, session.id, planHash],
    );
    return rows.isEmpty
        ? null
        : (jsonDecode(rows.single['json'] as String)['device']['id'] as String);
  }

  Map<String, dynamic> _peerGrant(
    String fingerprint,
    SessionRef session,
    String planHash,
    int epoch,
    int wallMs,
  ) {
    session.requireScope(namespace);
    _peerHash(fingerprint);
    _peerClock(wallMs);
    final rows = _db.select(
      'SELECT * FROM peer_grants WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=?',
      [_ns, fingerprint, session.id, planHash],
    );
    if (rows.length != 1 ||
        rows.single['revoked'] != 0 ||
        rows.single['epoch'] != epoch) {
      throw const StudioException('PEER_NOT_AUTHORIZED');
    }
    final grant =
        jsonDecode(rows.single['json'] as String) as Map<String, dynamic>;
    if (wallMs >= (grant['expiresMs'] as int)) {
      throw const StudioException('PEER_GRANT_EXPIRED');
    }
    return grant;
  }

  /// HTTPS adapter supplies authenticated fingerprint and coordinator clocks.
  /// Idempotency receipt, lease, binding and outbox commit in ONE SQL transaction.
  /// Replays recheck the current grant BEFORE returning any cached response.
  Map<String, dynamic> executePeerRequest(
    String fingerprint,
    Map<String, dynamic> request, {
    required String coordinatorBoot,
    required int nowMs,
    required int wallMs,
    required Map<String, Object?> inputsByHash,
  }) {
    // Persist the trusted wall-clock high-water even when authorization fails.
    // An observed expired grant must not resurrect after a clock rollback.
    _transaction(() => _peerClock(wallMs));
    return _transaction(() {
      const keys = [
        'schemaVersion',
        'id',
        'sessionId',
        'planHash',
        'epoch',
        'operation',
        'nodeId',
        'payload',
      ];
      if (request.length != keys.length ||
          !keys.every(request.containsKey) ||
          request['schemaVersion'] != '1.0.0') {
        throw const StudioException('PEER_PROTOCOL_VERSION');
      }
      final id = request['id'] as String,
          session = SessionRef(
            namespace: namespace,
            id: request['sessionId'] as String,
          ),
          planHash = request['planHash'] as String,
          nodeId = request['nodeId'] as String;
      requireId(id);
      requireId(nodeId);
      _peerHash(planHash);
      final epochBig = u63(request['epoch']);
      if (epochBig > BigInt.from(9007199254740991)) {
        throw const StudioException('PEER_NOT_AUTHORIZED');
      }
      final epoch = epochBig.toInt(),
          grant = _peerGrant(fingerprint, session, planHash, epoch, wallMs);
      if (!(grant['nodeIds'] as List).contains(nodeId)) {
        throw const StudioException('PEER_NOT_AUTHORIZED');
      }
      final row = _planRow(session, planHash),
          plan = HarnessPlan(
            jsonDecode(row['json'] as String) as Map<String, dynamic>,
          ),
          node = plan.node(nodeId);
      _observeHarnessClock(session, row, nowMs, coordinatorBoot);
      if (read(row['project_id'] as String)!.revision !=
          u63(plan.toJson()['baseRevision'])) {
        throw const StudioException('REVISION_CONFLICT');
      }
      final hash = harnessHash(request),
          previous = _db.select(
            'SELECT * FROM peer_requests WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=? AND id=?',
            [_ns, fingerprint, session.id, planHash, epoch, id],
          );
      if (previous.isNotEmpty) {
        if (previous.single['input_hash'] != hash) {
          throw const StudioException('IDEMPOTENCY_CONFLICT');
        }
        final cached = jsonDecode(
          previous.single['response_json'] as String,
        ) as Map<String, dynamic>;
        if (request['operation'] == 'claim') {
          final current = harnessStep(session, planHash, nodeId);
          final original = taskLeaseFromJson(
            cached['lease'] as Map<String, dynamic>,
          );
          if (current == null ||
              current.status != 'running' ||
              current.lease.coordinatorBoot != coordinatorBoot ||
              current.lease.fence != original.fence ||
              current.lease.deviceId != original.deviceId ||
              current.lease.untilMs <= nowMs) {
            throw const StudioException('LEASE_FENCED');
          }
          cached['lease'] = current.lease.toJson();
          cached['remainingMs'] = current.lease.untilMs - nowMs;
        }
        return cached;
      }
      final count =
          _db.select(
                'SELECT count(*) AS n FROM peer_requests WHERE ns=? AND fingerprint=? AND session_id=? AND plan_hash=? AND epoch=?',
                [_ns, fingerprint, session.id, planHash, epoch],
              ).single['n']
              as int;
      if (count >= 10000) throw const StudioException('PEER_REQUEST_QUOTA');
      final payload = request['payload'] as Map<String, dynamic>,
          op = request['operation'];
      Map<String, dynamic> response;
      if (op is String && op.startsWith('blob.')) {
        response = _peerBlobOperation(
          fingerprint,
          session,
          planHash,
          nodeId,
          epoch,
          grant,
          op,
          payload,
        );
      } else if (op == 'claim') {
        if (payload.length != 1 || payload['leaseMs'] is! int) {
          throw const StudioException('PEER_SCHEMA');
        }
        final handlerId = node['handlerPin']['id'] as String;
        if (node['outputSchemaHash'] !=
            BuiltinCompute.outputSchemaHash(handlerId)) {
          throw const StudioException('COMPUTE_OUTPUT_SCHEMA_PIN');
        }
        final inputHash = node['inputRef']['hash'] as String;
        if (!inputsByHash.containsKey(inputHash) ||
            harnessHash(inputsByHash[inputHash]) != inputHash) {
          throw const StudioException('COMPUTE_INPUT_HASH');
        }
        // Only installed, free pinned builtins. No models/shell/provider execution.
        final pin = node['handlerPin'] as Map<String, dynamic>;
        if (harnessHash(pin) !=
            harnessHash(BuiltinCompute.pin(pin['id'] as String))) {
          throw const StudioException('HANDLER_PIN_MISMATCH');
        }
        final device = _peerDevice(
          grant['device'] as Map<String, dynamic>,
          epoch,
        );
        final lease = claimHarnessTask(
          session,
          planHash,
          nodeId,
          device,
          PlacementRequirement(),
          coordinatorBoot: coordinatorBoot,
          nowMs: nowMs,
          leaseMs: payload['leaseMs'] as int,
        );
        _db.execute('INSERT INTO peer_task_bindings VALUES(?,?,?,?,?,?,?)', [
          _ns,
          session.id,
          planHash,
          nodeId,
          lease.fence.toString(),
          fingerprint,
          epoch,
        ]);
        response = {
          'lease': lease.toJson(),
          'handlerPin': pin,
          'input': inputsByHash[inputHash],
          'contentHash': inputHash,
          'remainingMs': lease.untilMs - nowMs,
        };
      } else if (op == 'heartbeat' || op == 'finish') {
        final expected = op == 'finish'
            ? ['lease', 'result', 'resultHash']
            : ['lease', 'progress', 'extendMs'];
        if (payload.length != expected.length ||
            !expected.every(payload.containsKey)) {
          throw const StudioException('PEER_SCHEMA');
        }
        final token = taskLeaseFromJson(
          payload['lease'] as Map<String, dynamic>,
        );
        if (token.sessionId != session.id ||
            token.planHash != planHash ||
            token.nodeId != nodeId) {
          throw const StudioException('LEASE_FENCED');
        }
        final bindings = _db.select(
          'SELECT * FROM peer_task_bindings WHERE ns=? AND session_id=? AND plan_hash=? AND node_id=? AND fence=? AND fingerprint=? AND epoch=?',
          [
            _ns,
            session.id,
            planHash,
            nodeId,
            token.fence.toString(),
            fingerprint,
            epoch,
          ],
        );
        if (bindings.length != 1 ||
            token.deviceId != (grant['device'] as Map)['id']) {
          throw const StudioException('PEER_RESULT_SOURCE');
        }
        if (op == 'heartbeat') {
          heartbeatHarness(
            session,
            token,
            coordinatorBoot: coordinatorBoot,
            nowMs: nowMs,
            progress: (payload['progress'] as num).toDouble(),
            extendMs: payload['extendMs'] as int,
          );
          response = {
            'lease': harnessStep(session, planHash, nodeId)!.lease.toJson(),
          };
        } else {
          if (harnessHash(payload['result']) != payload['resultHash']) {
            throw const StudioException('COMPUTE_RESULT_HASH');
          }
          BuiltinCompute.validateResult(
            node['handlerPin']['id'] as String,
            payload['result'],
          );
          final resultHash = finishHarnessTask(
            session,
            token,
            payload['result'],
            coordinatorBoot: coordinatorBoot,
            nowMs: nowMs,
          );
          response = {
            'resultHash': resultHash,
            'disposition': 'candidate',
            'deviceId': token.deviceId,
            'certificateFingerprint': fingerprint,
          };
        }
      } else {
        throw const StudioException('PEER_OPERATION_NOT_ALLOWED');
      }
      _db.execute('INSERT INTO peer_requests VALUES(?,?,?,?,?,?,?,?)', [
        _ns,
        fingerprint,
        session.id,
        planHash,
        epoch,
        id,
        hash,
        jsonEncode(response),
      ]);
      return response;
    });
  }
}
