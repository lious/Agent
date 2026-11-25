part of 'studio_store.dart';

/// Trusted coordinator only. No remote endpoint bypasses pairing/ACL through this
/// API. Dispatch is currently free pure/localCandidate work, NEVER paid submission
/// or direct project writes. Results are candidates bound to a frozen plan.
extension HarnessPersistence on DocumentRepository {
  void registerHarnessPlan(
    SessionRef session,
    String projectId,
    HarnessPlan plan, {
    required String coordinatorBoot,
    required int nowMs,
  }) => _transaction(() {
    session.requireScope(namespace);
    requireId(coordinatorBoot);
    if (nowMs < 0) throw const StudioException('LEASE_CLOCK_RANGE');
    final p = plan.toJson();
    if (p['ns'] != harnessNamespace(namespace)) {
      throw const StudioException('NAMESPACE_MISMATCH');
    }
    final project = read(projectId);
    if (project == null) throw const StudioException('PROJECT_NOT_FOUND');
    if (project.revision != u63(p['baseRevision'])) {
      throw const StudioException('REVISION_CONFLICT');
    }
    final existing = _db.select(
      'SELECT json,project_id FROM harness_plans WHERE ns=? AND session_id=? AND plan_hash=?',
      [_ns, session.id, plan.hash],
    );
    if (existing.isNotEmpty) {
      if (existing.single['json'] != jsonEncode(p) ||
          existing.single['project_id'] != projectId) {
        throw const StudioException('IDEMPOTENCY_CONFLICT');
      }
      return;
    }
    _db.execute('INSERT INTO harness_plans VALUES(?,?,?,?,?,?,?,?)', [
      _ns,
      session.id,
      plan.hash,
      projectId,
      jsonEncode(p),
      nowMs,
      nowMs,
      coordinatorBoot,
    ]);
  });
  Map<String, dynamic> _planRow(SessionRef session, String hash) {
    session.requireScope(namespace);
    final rows = _db.select(
      'SELECT * FROM harness_plans WHERE ns=? AND session_id=? AND plan_hash=?',
      [_ns, session.id, hash],
    );
    if (rows.length != 1) throw const StudioException('PLAN_NOT_FOUND');
    return Map.from(rows.single);
  }

  void _observeHarnessClock(
    SessionRef session,
    Map<String, dynamic> row,
    int nowMs,
    String boot,
  ) {
    if (row['boot'] != boot) throw const StudioException('COORDINATOR_FENCED');
    if (nowMs < (row['last_ms'] as int) || nowMs > 9007198650000000) {
      throw const StudioException('LEASE_CLOCK_RANGE');
    }
    _db.execute(
      'UPDATE harness_plans SET last_ms=? WHERE ns=? AND session_id=? AND plan_hash=?',
      [nowMs, _ns, session.id, row['plan_hash']],
    );
  }

  LeaseState? harnessStep(SessionRef session, String planHash, String nodeId) {
    session.requireScope(namespace);
    final rows = _db.select(
      'SELECT state_json FROM harness_steps WHERE ns=? AND session_id=? AND plan_hash=? AND node_id=?',
      [_ns, session.id, planHash, nodeId],
    );
    return rows.isEmpty
        ? null
        : leaseStateFromJson(
            jsonDecode(rows.single['state_json'] as String)
                as Map<String, dynamic>,
          );
  }

  void _putHarness(
    SessionRef session,
    String planHash,
    String nodeId,
    LeaseState state,
    int attempt,
  ) {
    _db.execute(
      'INSERT INTO harness_steps VALUES(?,?,?,?,?,?) ON CONFLICT(ns,session_id,plan_hash,node_id) DO UPDATE SET state_json=excluded.state_json,attempt=excluded.attempt',
      [_ns, session.id, planHash, nodeId, attempt, jsonEncode(state.toJson())],
    );
  }

  void _harnessOutbox(
    SessionRef session,
    TaskLease lease,
    String kind,
    Object? payload,
  ) {
    final id = harnessHash({
      'session': session.id,
      'plan': lease.planHash,
      'node': lease.nodeId,
      'fence': lease.fence.toString(),
      'kind': kind,
    });
    _db.execute('INSERT OR IGNORE INTO harness_outbox VALUES(?,?,?,?,?,?,?)', [
      _ns,
      id,
      session.id,
      lease.planHash,
      lease.nodeId,
      kind,
      jsonEncode(payload),
    ]);
  }

  TaskLease claimHarnessTask(
    SessionRef session,
    String planHash,
    String nodeId,
    VerifiedDevice device,
    PlacementRequirement need, {
    required String coordinatorBoot,
    required int nowMs,
    required int leaseMs,
  }) => _transaction(() {
    final row = _planRow(session, planHash),
        plan = HarnessPlan(
          jsonDecode(row['json'] as String) as Map<String, dynamic>,
        ),
        node = plan.node(nodeId);
    _observeHarnessClock(session, row, nowMs, coordinatorBoot);
    if (nowMs < 0 || leaseMs < 1 || leaseMs > u63(node['timeoutMs']).toInt()) {
      throw const StudioException('LEASE_CLOCK_RANGE');
    }
    if (placeTask(session, plan, nodeId, [device], need) == null) {
      throw const StudioException('DEVICE_NOT_ELIGIBLE');
    }
    if (row['boot'] != coordinatorBoot) {
      throw const StudioException('COORDINATOR_FENCED');
    }
    final wall = u63(plan.toJson()['limits']['maxWallMs']).toInt();
    final remaining = wall - (nowMs - (row['started_ms'] as int));
    if (remaining <= 0) {
      throw const StudioException('PLAN_WALL_BUDGET_EXHAUSTED');
    }
    for (final dep in node['deps']) {
      if (harnessStep(session, planHash, dep as String)?.status !=
          'committed') {
        throw const StudioException('PLAN_DEPENDENCY_PENDING');
      }
    }
    final state = harnessStep(session, planHash, nodeId),
        counts = _db.select(
          'SELECT attempt FROM harness_steps WHERE ns=? AND session_id=? AND plan_hash=? AND node_id=?',
          [_ns, session.id, planHash, nodeId],
        );
    if (state != null) {
      if (state.status == 'committed') {
        throw const StudioException('ALREADY_COMMITTED');
      }
      if (state.status == 'cancelled') {
        throw const StudioException('TASK_CANCELLED');
      }
      if (state.lease.coordinatorBoot == coordinatorBoot &&
          nowMs < state.lease.untilMs) {
        throw const StudioException('LEASE_BUSY');
      }
    }
    final attempt = counts.isEmpty ? 1 : (counts.single['attempt'] as int) + 1;
    if (attempt > (node['maxAttempts'] as int)) {
      throw const StudioException('TASK_ATTEMPTS_EXHAUSTED');
    }
    final lease = TaskLease(
      sessionId: session.id,
      nodeId: nodeId,
      deviceId: device.id,
      planHash: planHash,
      inputHash: harnessHash(node['inputRef']),
      coordinatorBoot: coordinatorBoot,
      fence: (state?.lease.fence ?? BigInt.zero) + BigInt.one,
      cancelEpoch: state?.lease.cancelEpoch ?? BigInt.zero,
      untilMs: nowMs + (leaseMs < remaining ? leaseMs : remaining),
    );
    _putHarness(session, planHash, nodeId, LeaseState(lease: lease), attempt);
    _harnessOutbox(session, lease, 'dispatch', lease.toJson());
    return lease;
  });
  void heartbeatHarness(
    SessionRef session,
    TaskLease token, {
    required String coordinatorBoot,
    required int nowMs,
    required double progress,
    required int extendMs,
  }) => _transaction(() {
    final row = _planRow(session, token.planHash),
        plan = HarnessPlan(
          jsonDecode(row['json'] as String) as Map<String, dynamic>,
        );
    if (row['boot'] != coordinatorBoot || token.sessionId != session.id) {
      throw const StudioException('LEASE_FENCED');
    }
    _observeHarnessClock(session, row, nowMs, coordinatorBoot);
    final state = harnessStep(session, token.planHash, token.nodeId);
    if (state == null) throw const StudioException('LEASE_FENCED');
    final budget =
        u63(plan.toJson()['limits']['maxWallMs']).toInt() -
        (nowMs - (row['started_ms'] as int));
    final timeout = u63(plan.node(token.nodeId)['timeoutMs']).toInt();
    if (extendMs > timeout || extendMs > budget) {
      throw const StudioException('PLAN_WALL_BUDGET_EXHAUSTED');
    }
    final next = state.heartbeat(
      token,
      nowMs,
      coordinatorBoot,
      progress,
      extendMs,
    );
    _db.execute(
      'UPDATE harness_steps SET state_json=? WHERE ns=? AND session_id=? AND plan_hash=? AND node_id=?',
      [
        jsonEncode(next.toJson()),
        _ns,
        session.id,
        token.planHash,
        token.nodeId,
      ],
    );
  });
  String finishHarnessTask(
    SessionRef session,
    TaskLease token,
    Object? result, {
    required String coordinatorBoot,
    required int nowMs,
  }) => _transaction(() {
    final row = _planRow(session, token.planHash);
    if (row['boot'] != coordinatorBoot || token.sessionId != session.id) {
      throw const StudioException('LEASE_FENCED');
    }
    _observeHarnessClock(session, row, nowMs, coordinatorBoot);
    final state = harnessStep(session, token.planHash, token.nodeId);
    if (state == null) throw const StudioException('LEASE_FENCED');
    if (jsonEncode(result).length > 4 * 1024 * 1024) {
      throw const StudioException('COMPUTE_RESULT_LIMIT');
    }
    final hash = harnessHash(result);
    if (state.status == 'committed') {
      if (state.lease.cancelEpoch != token.cancelEpoch ||
          state.lease.nodeId != token.nodeId ||
          state.lease.planHash != token.planHash ||
          state.lease.fence != token.fence ||
          state.lease.inputHash != token.inputHash ||
          state.lease.deviceId != token.deviceId ||
          state.lease.coordinatorBoot != token.coordinatorBoot ||
          state.resultHash != hash) {
        throw const StudioException('IDEMPOTENCY_CONFLICT');
      }
      return hash;
    }
    final next = state.finish(token, nowMs, coordinatorBoot, result);
    _db.execute(
      'UPDATE harness_steps SET state_json=? WHERE ns=? AND session_id=? AND plan_hash=? AND node_id=?',
      [
        jsonEncode(next.toJson()),
        _ns,
        session.id,
        token.planHash,
        token.nodeId,
      ],
    );
    _harnessOutbox(session, token, 'candidate.ready', {
      'resultHash': hash,
      'result': result,
      'deviceId': token.deviceId,
      'inputHash': token.inputHash,
      'planHash': token.planHash,
    });
    return hash;
  });
  void cancelHarnessTask(SessionRef session, String planHash, String nodeId) =>
      _transaction(() {
        _planRow(session, planHash);
        final old = harnessStep(session, planHash, nodeId);
        if (old == null) throw const StudioException('PLAN_NODE_NOT_RUNNING');
        final next = old.cancel();
        _db.execute(
          'UPDATE harness_steps SET state_json=? WHERE ns=? AND session_id=? AND plan_hash=? AND node_id=?',
          [jsonEncode(next.toJson()), _ns, session.id, planHash, nodeId],
        );
        if (old.status != 'committed') {
          _harnessOutbox(session, next.lease, 'cancel', next.toJson());
        }
      });
  List<Map<String, dynamic>> harnessOutbox(SessionRef session) {
    session.requireScope(namespace);
    return _db
        .select(
          'SELECT id,kind,payload_json FROM harness_outbox WHERE ns=? AND session_id=? ORDER BY rowid',
          [_ns, session.id],
        )
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}
