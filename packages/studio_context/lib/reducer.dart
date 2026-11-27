import 'package:studio_contracts/studio_contracts.dart';

import 'context_codes.dart';
import 'hashing.dart';

enum IntentStatus {
  proposed,
  active,
  superseded,
  retracted,
  conflicted,
  purged,
}

enum ScopeKind { project, scene, shot, selection }

final class IntentScope {
  IntentScope(this.kind, this.ids);
  final ScopeKind kind;
  final List<String> ids;

  String get key => '$kind:${ids.join(',')}';
}

enum BodyState { live, trashed, purged }

final class InputBody {
  InputBody({required this.id, required this.text, this.state = BodyState.live});
  final String id;
  String? text;
  BodyState state;
}

final class IntentRecord {
  IntentRecord({
    required this.id,
    required this.branchId,
    required this.scope,
    required this.fieldPath,
    required this.version,
    required this.status,
    required this.declaredAtSeq,
    this.valueRef,
    this.sourceTurnIds = const [],
    this.replacesId,
    this.retiredAtSeq,
  });

  final String id, branchId, fieldPath;
  final IntentScope scope;
  int version;
  IntentStatus status;
  String? valueRef;
  final List<String> sourceTurnIds;
  final String? replacesId;
  final int declaredAtSeq;
  int? retiredAtSeq;

  String? get valueId => valueRef;
}

sealed class IntentCommand {
  IntentCommand({
    required this.idempotencyKey,
    required this.expectedHeadSeq,
  });
  final String idempotencyKey;
  final int expectedHeadSeq;
}

final class DeclareIntent extends IntentCommand {
  DeclareIntent({
    required this.newId,
    required this.scope,
    required this.key,
    required this.valueRef,
    required this.sourceTurnIds,
    required super.idempotencyKey,
    required super.expectedHeadSeq,
  });
  final String newId, key, valueRef;
  final IntentScope scope;
  final List<String> sourceTurnIds;
}

final class SupersedeIntent extends IntentCommand {
  SupersedeIntent({
    required this.oldId,
    required this.oldVersion,
    required this.newId,
    required this.newValueRef,
    required this.sourceTurnIds,
    required super.idempotencyKey,
    required super.expectedHeadSeq,
  });
  final String oldId, newId, newValueRef;
  final int oldVersion;
  final List<String> sourceTurnIds;
}

final class RetractIntent extends IntentCommand {
  RetractIntent({
    required this.targetId,
    required this.targetVersion,
    required super.idempotencyKey,
    required super.expectedHeadSeq,
    this.reasonRef,
  });
  final String targetId;
  final int targetVersion;
  final String? reasonRef;
}

final class RestoreIntentAsNew extends IntentCommand {
  RestoreIntentAsNew({
    required this.newId,
    required this.sourceId,
    required this.valueRef,
    required this.sourceTurnIds,
    required super.idempotencyKey,
    required super.expectedHeadSeq,
  });
  final String newId, sourceId, valueRef;
  final List<String> sourceTurnIds;
}

final class IntentDelta {
  IntentDelta({
    required this.headSeq,
    required this.activated,
    required this.retired,
  });
  final int headSeq;
  final List<String> activated;
  final List<String> retired;
}

/// Deterministic event reducer for current effective intent. A chat
/// summary is not a source of truth and is never applied here.
final class EffectiveIntentReducer {
  EffectiveIntentReducer({required this.branchId});

  final String branchId;
  var headSeq = 0;
  var privacyEpoch = 1;
  final bodies = <String, InputBody>{};
  final intents = <String, IntentRecord>{};
  final _idempotent = <String, IntentDelta>{};

  void putBody(InputBody body) => bodies[body.id] = body;

  InputBody requireBody(String id) {
    final body = bodies[id];
    if (body == null) throw StudioException('BODY_NOT_FOUND', id);
    if (body.state == BodyState.purged) {
      throw StudioException(purgedBodyUnrecoverable, id);
    }
    return body;
  }

  IntentDelta apply(IntentCommand command) {
    final prior = _idempotent[command.idempotencyKey];
    if (prior != null) return prior;
    if (command.expectedHeadSeq != headSeq) {
      throw StudioException(intentHeadConflict, '${command.expectedHeadSeq}');
    }
    final beforeHead = headSeq;
    final beforeEpoch = privacyEpoch;
    final snapshot = {
      for (final e in intents.entries) e.key: _copy(e.value),
    };
    try {
      final delta = switch (command) {
        DeclareIntent() => _declare(command),
        SupersedeIntent() => _supersede(command),
        RetractIntent() => _retract(command),
        RestoreIntentAsNew() => _restore(command),
      };
      _idempotent[command.idempotencyKey] = delta;
      return delta;
    } catch (_) {
      headSeq = beforeHead;
      privacyEpoch = beforeEpoch;
      intents
        ..clear()
        ..addAll(snapshot);
      rethrow;
    }
  }

  List<IntentRecord> active({String? fieldPath}) {
    return [
      for (final i in intents.values)
        if (i.status == IntentStatus.active &&
            (fieldPath == null || i.fieldPath == fieldPath))
          i,
    ];
  }

  IntentRecord? current(String fieldPath, IntentScope scope) {
    final matches = [
      for (final i in intents.values)
        if (i.status == IntentStatus.active &&
            i.fieldPath == fieldPath &&
            i.scope.key == scope.key)
          i,
    ];
    return matches.isEmpty ? null : matches.single;
  }

  String intentDigest() {
    final rows = [
      for (final i in active())
        {
          'id': i.id,
          'fieldPath': i.fieldPath,
          'scope': i.scope.key,
          'valueRef': i.valueRef,
          'version': i.version,
        },
    ]..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
    return fingerprintJson({'head': headSeq, 'rows': rows});
  }

  IntentDelta _declare(DeclareIntent command) {
    requireId(command.newId);
    requireBody(command.valueRef);
    final existing = current(command.key, command.scope);
    if (existing != null) {
      throw StudioException(intentConflict, existing.id);
    }
    headSeq += 1;
    intents[command.newId] = IntentRecord(
      id: command.newId,
      branchId: branchId,
      scope: command.scope,
      fieldPath: command.key,
      version: 1,
      status: IntentStatus.active,
      declaredAtSeq: headSeq,
      valueRef: command.valueRef,
      sourceTurnIds: List.of(command.sourceTurnIds),
    );
    return IntentDelta(
      headSeq: headSeq,
      activated: [command.newId],
      retired: const [],
    );
  }

  IntentDelta _supersede(SupersedeIntent command) {
    requireId(command.newId);
    requireBody(command.newValueRef);
    final old = intents[command.oldId];
    if (old == null ||
        old.status != IntentStatus.active ||
        old.version != command.oldVersion) {
      throw StudioException(intentVersionConflict, command.oldId);
    }
    headSeq += 1;
    old.status = IntentStatus.superseded;
    old.retiredAtSeq = headSeq;
    intents[command.newId] = IntentRecord(
      id: command.newId,
      branchId: branchId,
      scope: old.scope,
      fieldPath: old.fieldPath,
      version: 1,
      status: IntentStatus.active,
      declaredAtSeq: headSeq,
      valueRef: command.newValueRef,
      sourceTurnIds: List.of(command.sourceTurnIds),
      replacesId: old.id,
    );
    return IntentDelta(
      headSeq: headSeq,
      activated: [command.newId],
      retired: [old.id],
    );
  }

  IntentDelta _retract(RetractIntent command) {
    final target = intents[command.targetId];
    if (target == null ||
        target.status != IntentStatus.active ||
        target.version != command.targetVersion) {
      throw StudioException(intentVersionConflict, command.targetId);
    }
    headSeq += 1;
    target.status = IntentStatus.retracted;
    target.retiredAtSeq = headSeq;
    // Retract does not revive an earlier superseded record.
    return IntentDelta(
      headSeq: headSeq,
      activated: const [],
      retired: [target.id],
    );
  }

  IntentDelta _restore(RestoreIntentAsNew command) {
    requireId(command.newId);
    final source = intents[command.sourceId];
    if (source == null) {
      throw StudioException('INTENT_NOT_FOUND', command.sourceId);
    }
    if (source.status == IntentStatus.purged ||
        (source.valueRef != null &&
            bodies[source.valueRef]?.state == BodyState.purged)) {
      throw StudioException(purgedBodyUnrecoverable, command.sourceId);
    }
    requireBody(command.valueRef);
    final existing = current(source.fieldPath, source.scope);
    if (existing != null) {
      existing.status = IntentStatus.superseded;
      existing.retiredAtSeq = headSeq + 1;
    }
    headSeq += 1;
    intents[command.newId] = IntentRecord(
      id: command.newId,
      branchId: branchId,
      scope: source.scope,
      fieldPath: source.fieldPath,
      version: 1,
      status: IntentStatus.active,
      declaredAtSeq: headSeq,
      valueRef: command.valueRef,
      sourceTurnIds: List.of(command.sourceTurnIds),
      replacesId: source.id,
    );
    return IntentDelta(
      headSeq: headSeq,
      activated: [command.newId],
      retired: [if (existing != null) existing.id],
    );
  }

  IntentRecord _copy(IntentRecord i) => IntentRecord(
    id: i.id,
    branchId: i.branchId,
    scope: i.scope,
    fieldPath: i.fieldPath,
    version: i.version,
    status: i.status,
    declaredAtSeq: i.declaredAtSeq,
    valueRef: i.valueRef,
    sourceTurnIds: List.of(i.sourceTurnIds),
    replacesId: i.replacesId,
    retiredAtSeq: i.retiredAtSeq,
  );
}
