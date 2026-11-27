import 'package:studio_contracts/studio_contracts.dart';

final class DownmixRequest {
  const DownmixRequest({
    required this.downmix,
    this.matrix,
    this.implicitDownmix = false,
  });

  final bool downmix, implicitDownmix;
  final List<List<double>>? matrix;
}

final class DownmixReceipt {
  const DownmixReceipt({required this.explicitMatrix});

  final bool explicitMatrix;
}

/// DEV-PURE I-023 / s4 admission: input-layout downmix uses an explicit
/// matrix. This is not a channel-mixer or limiter runtime, not I-007
/// PCM remapping, and not a re-qualification of I-009 mix, Increment
/// 2.83 varispeed-and-pitch, or Increment 2.85 recording-drift.
final class DownmixAdmission {
  bool mixerRuntimeInvented = false;
  bool limiterInvented = false;
  bool i007PcmRemapStarted = false;
  bool i009Requalified = false;
  bool varispeedRequalified = false;
  bool driftRequalified = false;
  bool timeStretchInvented = false;
  bool av20msClaimed = false;
  bool underrunResolved = false;
  bool paidApiCalled = false;

  DownmixReceipt admit(DownmixRequest request) {
    if (!request.downmix) {
      return const DownmixReceipt(explicitMatrix: false);
    }
    if (request.implicitDownmix || request.matrix == null) {
      throw const StudioException('DOWNMIX_MATRIX_REQUIRED', 'downmix');
    }
    final matrix = request.matrix!;
    if (matrix.isEmpty ||
        matrix.any((row) => row.isEmpty) ||
        matrix.any((row) => row.length != matrix.first.length) ||
        matrix.any((row) => row.any((value) => !value.isFinite))) {
      throw const StudioException('DOWNMIX_MATRIX_INVALID', 'downmix');
    }
    return const DownmixReceipt(explicitMatrix: true);
  }
}
