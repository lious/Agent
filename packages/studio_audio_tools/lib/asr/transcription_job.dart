import 'package:studio_contracts/studio_contracts.dart';

/// Official s8r window: 16 kHz mono, 30 s window, 29 s hop.
const asrSampleRate = 16000;
const asrWindowSamples = 30 * asrSampleRate;
const asrHopSamples = 29 * asrSampleRate;

enum AsrWindowKind { speech, silence, music, noAudio }

/// DEV-PURE I-046 window observation. This is not a Whisper result and
/// not on-device inference.
final class AsrWindow {
  AsrWindow({
    required this.startSample,
    required this.endSample,
    required this.kind,
    this.text = '',
    this.lowConfidence = false,
    this.repetitive = false,
  }) {
    if (startSample < 0 || endSample <= startSample) {
      throw const StudioException('PARAMETER_RANGE', 'window');
    }
  }

  final int startSample, endSample;
  final AsrWindowKind kind;
  final String text;
  final bool lowConfidence, repetitive;

  bool get suspectedHallucination =>
      kind == AsrWindowKind.silence ||
      kind == AsrWindowKind.music ||
      (text.isNotEmpty && (kind != AsrWindowKind.speech || repetitive));
}

final class LockedCue {
  LockedCue({
    required this.id,
    required this.text,
    required this.startSample,
    required this.endSample,
    this.handEdited = true,
  }) {
    requireId(id);
  }

  final String id, text;
  final int startSample, endSample;
  final bool handEdited;
}

/// Official s8r CaptionProposal. transcribe does not UPDATE the caption table.
final class CaptionProposalCue {
  CaptionProposalCue({
    required this.id,
    required this.startSample,
    required this.endSample,
    required this.text,
    this.speakerId,
    this.suspectedHallucination = false,
    this.conflictWithId,
  });

  final String id, text;
  final int startSample, endSample;
  final String? speakerId, conflictWithId;
  final bool suspectedHallucination;
}

final class CaptionProposal {
  CaptionProposal({
    required this.hash,
    required this.cues,
    this.autoAccepted = false,
    this.sourceDeleted = false,
    this.cancelled = false,
  });

  final String hash;
  final List<CaptionProposalCue> cues;
  final bool autoAccepted, sourceDeleted, cancelled;

  bool get realInferenceClaimed => false;
  bool get diarizationEnabled => false;
  bool get cloudAsrStarted => false;
  bool get submitted => false;
  int get documentWrites => 0;
  int get hungCues => 0;
}

final class AsrSpec {
  AsrSpec({
    required this.sourceRef,
    this.windows = const [],
    this.lockedCues = const [],
    this.noAudio = false,
    this.requestDiarization = false,
    this.requestCloudAsr = false,
    this.sourceDeleted = false,
    this.cancelled = false,
    this.expectedRevision = 1,
  }) {
    requireId(sourceRef);
  }

  final String sourceRef;
  final List<AsrWindow> windows;
  final List<LockedCue> lockedCues;
  final bool noAudio,
      requestDiarization,
      requestCloudAsr,
      sourceDeleted,
      cancelled;
  final int expectedRevision;
}

/// DEV-PURE I-046 SubtitleService. This is not a real ASR engine, not
/// V-009 qualification, and not an I-010 caption-table rewrite.
final class TranscriptionJob {
  int documentWrites = 0;
  var lateResultAttached = false;
  int? plannedRevision;

  CaptionProposal transcribe(AsrSpec spec) {
    if (spec.requestCloudAsr) {
      throw const StudioException('TOOL_NOT_ALLOWED', 'cloudAsr');
    }
    if (spec.requestDiarization) {
      throw const StudioException('UNSUPPORTED_EDIT_TECHNIQUE', 'diarization');
    }
    if (spec.noAudio) {
      documentWrites = 0;
      return CaptionProposal(hash: 'proposal-no-audio', cues: const []);
    }
    if (spec.sourceDeleted || spec.cancelled) {
      documentWrites = 0;
      lateResultAttached = false;
      return CaptionProposal(
        hash: spec.sourceDeleted ? 'proposal-deleted' : 'proposal-cancelled',
        cues: const [],
        sourceDeleted: spec.sourceDeleted,
        cancelled: spec.cancelled,
      );
    }

    final cues = <CaptionProposalCue>[];
    final kept = <CaptionProposalCue>[];
    var n = 0;
    for (final window in spec.windows) {
      if (window.kind == AsrWindowKind.noAudio) continue;
      final hallucinated =
          window.suspectedHallucination ||
          window.kind != AsrWindowKind.speech ||
          window.text.isEmpty;
      n += 1;
      final cue = CaptionProposalCue(
        id: 'cue-$n',
        startSample: window.startSample,
        endSample: window.endSample,
        text: hallucinated ? '' : window.text,
        speakerId: null,
        suspectedHallucination: hallucinated,
      );
      if (_overlapsLocked(cue, spec.lockedCues)) {
        // Locked or hand-edited cues are not overwritten.
        continue;
      }
      final duplicate = _identicalOverlap(cue, kept);
      if (duplicate != null) {
        continue;
      }
      final conflict = _approximateOverlap(cue, kept);
      if (conflict != null) {
        cues.add(
          CaptionProposalCue(
            id: cue.id,
            startSample: cue.startSample,
            endSample: cue.endSample,
            text: cue.text,
            speakerId: null,
            suspectedHallucination: cue.suspectedHallucination,
            conflictWithId: conflict.id,
          ),
        );
        kept.add(cue);
        continue;
      }
      cues.add(cue);
      kept.add(cue);
    }
    documentWrites = 0;
    return CaptionProposal(hash: 'proposal-$n', cues: cues);
  }

  /// Accept is a planned receipt, not a caption-table write. A locked
  /// cue in the write set is refused. Hallucinations are not auto-accepted.
  void accept({
    required CaptionProposal proposal,
    required int expectedRevision,
    List<String> lockedCueIds = const [],
    bool autoAcceptHallucinations = false,
  }) {
    if (proposal.sourceDeleted) {
      lateResultAttached = false;
      throw const StudioException('SOURCE_DELETED', 'accept');
    }
    if (proposal.cancelled) {
      lateResultAttached = false;
      throw const StudioException('PROPOSAL_CANCELLED', 'accept');
    }
    if (proposal.cues.any((c) => lockedCueIds.contains(c.id))) {
      throw const StudioException('FIELD_LOCKED', 'lockedCue');
    }
    if (autoAcceptHallucinations &&
        proposal.cues.any((c) => c.suspectedHallucination)) {
      throw const StudioException('HALLUCINATION_NOT_AUTO_ACCEPTED', 'accept');
    }
    if (proposal.autoAccepted) {
      throw const StudioException(
        'HALLUCINATION_NOT_AUTO_ACCEPTED',
        'autoAccepted',
      );
    }
    plannedRevision = expectedRevision + 1;
    documentWrites = 0;
  }

  /// A late result after delete or cancel does not hang a cue.
  void attachLate(CaptionProposal proposal) {
    if (proposal.sourceDeleted || proposal.cancelled) {
      lateResultAttached = false;
      return;
    }
    lateResultAttached = true;
  }

  bool _overlapsLocked(CaptionProposalCue cue, List<LockedCue> locked) {
    for (final item in locked) {
      if (cue.startSample < item.endSample &&
          item.startSample < cue.endSample) {
        return true;
      }
    }
    return false;
  }

  CaptionProposalCue? _identicalOverlap(
    CaptionProposalCue cue,
    List<CaptionProposalCue> kept,
  ) {
    for (final other in kept) {
      if (cue.startSample < other.endSample &&
          other.startSample < cue.endSample &&
          cue.text == other.text &&
          cue.text.isNotEmpty) {
        return other;
      }
    }
    return null;
  }

  CaptionProposalCue? _approximateOverlap(
    CaptionProposalCue cue,
    List<CaptionProposalCue> kept,
  ) {
    for (final other in kept) {
      if (cue.startSample < other.endSample &&
          other.startSample < cue.endSample &&
          cue.text != other.text &&
          cue.text.isNotEmpty &&
          other.text.isNotEmpty) {
        return other;
      }
    }
    return null;
  }
}
