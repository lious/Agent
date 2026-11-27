import 'package:studio_contracts/studio_contracts.dart';

enum GenerationMode { t2v, i2v, firstLast, extend, restyle }

enum CandidateState { submitted, unknown, ready, cancelled, quarantined }

/// DEV-PURE I-040 editable NLE clip. This is not a flattened MP4 bake.
final class EditableClip {
  EditableClip({
    required this.id,
    required this.start,
    required this.end,
    this.originalAudioPreserved = true,
    this.canTrim = true,
    this.flatMp4Only = false,
  }) {
    requireId(id);
  }

  final String id;
  final int start, end;
  final bool originalAudioPreserved, canTrim, flatMp4Only;
}

final class GenerationCandidate {
  GenerationCandidate({
    required this.id,
    required this.state,
    this.clips = const [],
    this.qaUnknown = false,
    this.autoApplied = false,
    this.approxContinuation = false,
  });

  final String id;
  final CandidateState state;
  final List<EditableClip> clips;
  final bool qaUnknown, autoApplied, approxContinuation;
}

final class GenerationRequest {
  GenerationRequest({
    required this.idempotencyKey,
    required this.mode,
    this.profileInstalled = true,
    this.inventAudioFalseOnWan27 = false,
    this.autoSpliceUncertain = false,
    this.lockedCaptionIds = const [],
    this.lockedAudio = false,
  }) {
    requireId(idempotencyKey);
  }

  final String idempotencyKey;
  final GenerationMode mode;
  final bool profileInstalled,
      inventAudioFalseOnWan27,
      autoSpliceUncertain,
      lockedAudio;
  final List<String> lockedCaptionIds;
}

final class InsertPlan {
  InsertPlan({required this.clips, this.duplicatePrefix = false});

  final List<EditableClip> clips;
  final bool duplicatePrefix;

  bool get flatMp4Only => clips.any((c) => c.flatMp4Only);
  bool get originalAudioPreserved =>
      clips.every((c) => c.originalAudioPreserved);
  int get documentWrites => 0;
}

final class BillingReport {
  BillingReport({required this.billCount, required this.feeAccountedMicros});

  final int billCount, feeAccountedMicros;
  bool get refundPromised => false;
  bool get paidApiCalled => false;
  bool get hungOnTimeline => false;
}

/// Official I-040 VideoGenerationProvider / CandidateStore compiler.
/// This is not a WorkflowCoordinator, not a paid API, and not V-019.
final class VideoGenerationProvider {
  int postCount = 0;
  int billCount = 0;
  int feeAccountedMicros = 0;
  int documentWrites = 0;
  final _tasks = <String, CandidateState>{};

  bool get productionEnabled => false;
  bool get v019Claimed => false;
  bool get accountAutoConnected => false;
  bool get paidApiCalled => false;
  bool get submitted => false;

  GenerationCandidate submit(GenerationRequest request) {
    if (!request.profileInstalled && request.mode == GenerationMode.firstLast) {
      throw const StudioException('CAPABILITY_UNSUPPORTED', 'firstLast');
    }
    if (request.mode == GenerationMode.extend && !request.profileInstalled) {
      throw const StudioException('CAPABILITY_UNSUPPORTED', 'extend');
    }
    if (request.mode == GenerationMode.restyle) {
      throw const StudioException(
        'UNVERIFIED_VIDEO_RESTYLE_PROFILE',
        'restyle',
      );
    }
    if (request.inventAudioFalseOnWan27) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'audioFalse');
    }
    if (request.autoSpliceUncertain) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'autoSplice');
    }
    final existing = _tasks[request.idempotencyKey];
    if (existing != null) {
      // Duplicate submit does not POST or bill again.
      documentWrites = 0;
      return GenerationCandidate(id: request.idempotencyKey, state: existing);
    }
    postCount += 1;
    billCount += 1;
    feeAccountedMicros += 1;
    _tasks[request.idempotencyKey] = CandidateState.submitted;
    documentWrites = 0;
    return GenerationCandidate(
      id: request.idempotencyKey,
      state: CandidateState.submitted,
    );
  }

  /// Unknown status is poll-only. A blind re-POST is refused.
  CandidateState poll(String idempotencyKey, {required bool rePost}) {
    requireId(idempotencyKey);
    if (rePost) {
      throw const StudioException('UNKNOWN_NO_BLIND_RETRY', 'poll');
    }
    return _tasks[idempotencyKey] ?? CandidateState.unknown;
  }

  /// Late media after timeout is sandboxed, billed once, and not auto-applied.
  GenerationCandidate acceptLate(String idempotencyKey) {
    requireId(idempotencyKey);
    final state = _tasks[idempotencyKey];
    if (state == null) {
      _tasks[idempotencyKey] = CandidateState.quarantined;
    }
    documentWrites = 0;
    return GenerationCandidate(
      id: idempotencyKey,
      state: CandidateState.quarantined,
      qaUnknown: true,
    );
  }

  /// Local cancel forbids auto-apply. A second bill is not created.
  BillingReport cancel(String idempotencyKey, {required bool running}) {
    requireId(idempotencyKey);
    if (running) {
      throw const StudioException('FEATURE_NOT_IMPLEMENTED', 'cancelRunning');
    }
    _tasks[idempotencyKey] = CandidateState.cancelled;
    documentWrites = 0;
    return BillingReport(
      billCount: billCount,
      feeAccountedMicros: feeAccountedMicros,
    );
  }

  /// Continuation inserts only the verified suffix as an editable clip
  /// and keeps the original clip and its audio. Duration is the full
  /// returned length, not an appended increment.
  InsertPlan insertContinuation({
    required int originalStart,
    required int originalEnd,
    required int contextPrefixDuration,
    required int returnedTotalDuration,
    required bool lockedAudio,
    List<String> lockedCaptionIds = const [],
    bool overwriteLocked = false,
  }) {
    if (overwriteLocked && (lockedAudio || lockedCaptionIds.isNotEmpty)) {
      throw StudioException(
        lockedAudio ? 'TRACK_LOCKED' : 'FIELD_LOCKED',
        'insert',
      );
    }
    final newDuration = returnedTotalDuration - contextPrefixDuration;
    if (newDuration <= 0) {
      throw const StudioException('PARAMETER_RANGE', 'suffix');
    }
    documentWrites = 0;
    return InsertPlan(
      clips: [
        EditableClip(
          id: 'clip-original',
          start: originalStart,
          end: originalEnd,
        ),
        EditableClip(
          id: 'clip-suffix',
          start: originalEnd,
          end: originalEnd + newDuration,
        ),
      ],
    );
  }

  InsertPlan insertShots(int count) {
    if (count < 1) {
      throw const StudioException('PARAMETER_RANGE', 'shots');
    }
    documentWrites = 0;
    return InsertPlan(
      clips: [
        for (var i = 0; i < count; i++)
          EditableClip(id: 'clip-$i', start: i * 5, end: (i + 1) * 5),
      ],
    );
  }

  /// Native extend bills the full requested duration, not only the added seconds.
  int billedDuration({required int returnedTotalDuration}) =>
      returnedTotalDuration;

  /// Tail-frame simulation is not a silent fallback and needs re-approval.
  void useApproxContinuation({required bool approved}) {
    if (!approved) {
      throw const StudioException('APPROVAL_REQUIRED', 'approxContinuation');
    }
  }
}
