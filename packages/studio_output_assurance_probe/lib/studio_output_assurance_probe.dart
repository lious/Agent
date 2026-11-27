import 'package:studio_contracts/studio_contracts.dart';

/// Public output assurances, not license grants or execution decisions.
enum OutputAssurance { notGuaranteed, guaranteed }

final class OutputAssuranceRequest {
  const OutputAssuranceRequest({
    required this.kind,
    required this.exclusivity,
    required this.copyrightability,
    required this.nonInfringement,
  });
  final String kind;
  final OutputAssurance exclusivity;
  final OutputAssurance copyrightability;
  final OutputAssurance nonInfringement;
}

/// A validated disclosure. No license, runtime, or release decision is made.
final class OutputAssuranceDisclosure {
  const OutputAssuranceDisclosure._();
  String get text => '输出不保证独占、可版权或不侵权。';
}

/// DEV-PURE s1a output-assurance validation only.
final class OutputAssuranceAdmission {
  const OutputAssuranceAdmission();

  OutputAssuranceDisclosure admit(OutputAssuranceRequest request) {
    if (request.kind != 'outputAssurance') {
      throw const StudioException('OUTPUT_ASSURANCE_KIND_UNKNOWN', 'validator');
    }
    if (request.exclusivity == OutputAssurance.guaranteed) {
      throw const StudioException(
        'OUTPUT_EXCLUSIVITY_NOT_GUARANTEED',
        'validator',
      );
    }
    if (request.copyrightability == OutputAssurance.guaranteed) {
      throw const StudioException(
        'OUTPUT_COPYRIGHTABILITY_NOT_GUARANTEED',
        'validator',
      );
    }
    if (request.nonInfringement == OutputAssurance.guaranteed) {
      throw const StudioException(
        'OUTPUT_NONINFRINGEMENT_NOT_GUARANTEED',
        'validator',
      );
    }
    return const OutputAssuranceDisclosure._();
  }
}
