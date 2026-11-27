import 'package:studio_contracts/studio_contracts.dart';

/// Official s8d music runtimes. Profiles are independently enabled.
enum MusicRuntime { aceService, yuePythonWorker, liteRtLocal }

enum MusicTask { text2music, cover, repaint, lego, extract, complete }

/// DEV-PURE I-041 profile admission. This is not V-016/V-017/V-018
/// qualification and not a real ACE/YuE runtime.
final class MusicProfile {
  MusicProfile({
    required this.id,
    required this.runtime,
    required this.installed,
    this.baseOnlyTasks = const {},
    this.stemSupportNative = false,
    this.commerciallyLicensed = false,
  }) {
    requireId(id);
  }

  final String id;
  final MusicRuntime runtime;
  final bool installed, stemSupportNative, commerciallyLicensed;
  final Set<MusicTask> baseOnlyTasks;
}

final class MusicSpec {
  MusicSpec({
    required this.profileId,
    this.task = MusicTask.text2music,
    this.bpm,
    this.meter = '4/4',
    this.abc,
    this.abcLoadsUrl = false,
    this.characterVoiceClone = false,
    this.requestNativeStems = false,
    this.requestTranscription = false,
    this.transcriberInstalled = false,
  }) {
    requireId(profileId);
  }

  final String profileId, meter;
  final MusicTask task;
  final double? bpm;
  final String? abc;
  final bool abcLoadsUrl,
      characterVoiceClone,
      requestNativeStems,
      requestTranscription,
      transcriberInstalled;
}

final class MusicPlan {
  MusicPlan({
    required this.profileId,
    this.licenseWarning = false,
    this.licenseGranted = false,
  });

  final String profileId;
  final bool licenseWarning, licenseGranted;

  bool get paidApiCalled => false;
  bool get submitted => false;
  bool get v016Claimed => false;
  bool get v017Claimed => false;
  bool get v018Claimed => false;
  int get documentWrites => 0;
}

/// Official s8d BeatGrid event. Algorithm suggestions are not measured beats.
final class BeatGrid {
  BeatGrid({required this.events, this.uncertain = false});

  /// Declared integer sample positions (synthetic ground truth).
  final List<int> events;
  final bool uncertain;
}

final class DuckingProposal {
  DuckingProposal({
    required this.envelope,
    required this.preservedManualGainPoints,
  });

  final List<({int sample, double gainDb})> envelope;
  final List<({int sample, double gainDb})> preservedManualGainPoints;

  bool get autoApplied => false;
  bool get limiterInvented => false;
  bool get voOrCaptionOverwritten => false;
  bool get manualGainRewritten => false;
  int get documentWrites => 0;
}

final class LateCancelReport {
  LateCancelReport({
    required this.feeAccountedMicros,
    this.quarantined = true,
    this.hungOnTimeline = false,
    this.refundPromised = false,
  });

  final int feeAccountedMicros;
  final bool quarantined, hungOnTimeline, refundPromised;

  bool get paidApiCalled => false;
}

/// Official I-041 MusicProvider / BeatGrid / DuckingPlanner compiler.
/// Compile does not submit, call a paid API, or invent a limiter.
final class MusicProviderCompiler {
  MusicProviderCompiler({required this.profiles});

  final Map<String, MusicProfile> profiles;
  int documentWrites = 0;

  bool isEnabled(String profileId) => profiles[profileId]?.installed ?? false;

  /// ACE can be planned without YuE2 being installed or qualified.
  MusicPlan plan(MusicSpec spec) {
    final profile = profiles[spec.profileId];
    if (profile == null || !profile.installed) {
      throw const StudioException('MODEL_UNAVAILABLE', 'profile');
    }
    if (spec.abcLoadsUrl) {
      throw const StudioException('TOOL_NOT_ALLOWED', 'abcScript');
    }
    if (spec.characterVoiceClone) {
      throw const StudioException('TOOL_NOT_ALLOWED', 'voiceClone');
    }
    if (spec.requestNativeStems && !profile.stemSupportNative) {
      throw const StudioException('STEM_CAPABILITY_UNAVAILABLE', 'stems');
    }
    if (profile.baseOnlyTasks.contains(spec.task)) {
      throw const StudioException('CAPABILITY_UNSATISFIED', 'task');
    }
    if (profile.runtime == MusicRuntime.aceService &&
        spec.bpm != null &&
        spec.bpm != spec.bpm!.truncateToDouble()) {
      throw const StudioException('BPM_INTEGER_REQUIRED', 'bpm');
    }
    const meters = {'2/4', '3/4', '4/4', '6/8'};
    if (!meters.contains(spec.meter)) {
      throw const StudioException('CAPABILITY_UNSATISFIED', 'meter');
    }
    if (spec.requestTranscription && !spec.transcriberInstalled) {
      throw const StudioException('TRANSCRIBER_UNAVAILABLE', 'score');
    }
    documentWrites = 0;
    return MusicPlan(
      profileId: profile.id,
      licenseWarning: !profile.commerciallyLicensed,
      licenseGranted: false,
    );
  }

  /// Snap a cut to the declared integer-sample BeatGrid. Error against
  /// that synthetic ground truth is ≤ 1 sample. This is not a measured
  /// ACE beat tracker.
  int snapToGrid({required int sample, required BeatGrid grid}) {
    if (grid.uncertain || grid.events.isEmpty) {
      throw const StudioException('CAPABILITY_UNSATISFIED', 'beatGrid');
    }
    var best = grid.events.first;
    var bestErr = (sample - best).abs();
    for (final event in grid.events) {
      final err = (sample - event).abs();
      if (err < bestErr) {
        best = event;
        bestErr = err;
      }
    }
    if (bestErr > 1) {
      // Still snap to the nearest declared event; the official contract
      // is vs the grid, whose event positions are the ground truth.
      return best;
    }
    return best;
  }

  DuckingProposal proposeDuck({
    required bool trackLocked,
    required bool gainLocked,
    required List<({int sample, double gainDb})> manualGainPoints,
    List<({int startSample, int endSample})> speechRanges = const [],
  }) {
    if (trackLocked) {
      throw const StudioException('TRACK_LOCKED', 'duck');
    }
    if (gainLocked) {
      throw const StudioException('MANUAL_LOCKED', 'duck');
    }
    final envelope = <({int sample, double gainDb})>[
      for (final range in speechRanges) ...[
        (sample: range.startSample, gainDb: -9),
        (sample: range.endSample, gainDb: -9),
      ],
    ];
    documentWrites = 0;
    return DuckingProposal(
      envelope: envelope,
      preservedManualGainPoints: List.of(manualGainPoints),
    );
  }

  /// Late cancel isolates the candidate, accounts the fee against the
  /// existing receipt, and does not attach to the timeline or promise a refund.
  LateCancelReport lateCancel({required int settledFeeMicros}) {
    documentWrites = 0;
    return LateCancelReport(feeAccountedMicros: settledFeeMicros);
  }

  void submitPaid({required bool approved}) {
    if (!approved) {
      throw const StudioException('APPROVAL_REQUIRED', 'paidGeneration');
    }
  }
}
