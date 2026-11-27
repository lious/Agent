import 'package:studio_contracts/studio_contracts.dart';

import 'voice_codes.dart';

final class VoiceConsent {
  VoiceConsent({
    required this.consentId,
    required this.subjectPersonId,
    required this.voiceProfileId,
    required Set<String> uses,
    required this.grantedAt,
    this.revokedAt,
  }) : uses = Set.unmodifiable(uses) {
    requireId(consentId);
    requireId(subjectPersonId);
    requireId(voiceProfileId);
  }

  final String consentId, subjectPersonId, voiceProfileId;
  final Set<String> uses;
  final DateTime grantedAt;
  DateTime? revokedAt;

  bool get revoked => revokedAt != null;

  bool allows(String use) => !revoked && uses.contains(use);
}

/// Consent and revocation ledger for real-person clone and voice pins.
/// No consent, or a revoked consent, yields new executions = 0.
/// Impersonation of a third party without their consent is refused;
/// real-person clone is not blanket-banned.
final class VoiceConsentLedger {
  final Map<String, VoiceConsent> _byProfile = {};
  final Map<String, int> newExecutions = {};

  VoiceConsent grant(VoiceConsent consent) {
    _byProfile[consent.voiceProfileId] = consent;
    newExecutions.putIfAbsent(consent.voiceProfileId, () => 0);
    return consent;
  }

  void revoke(String voiceProfileId, {required DateTime at}) {
    final row = _byProfile[voiceProfileId];
    if (row == null) {
      throw StudioException(voiceProfileMissing, voiceProfileId);
    }
    row.revokedAt = at.toUtc();
  }

  bool isRevoked(String voiceProfileId) {
    final row = _byProfile[voiceProfileId];
    return row == null || row.revoked;
  }

  VoiceConsent require(String voiceProfileId, String use) {
    final row = _byProfile[voiceProfileId];
    if (row == null) {
      throw StudioException(consentRequired, voiceProfileId);
    }
    if (row.revoked) {
      throw StudioException(consentRevoked, voiceProfileId);
    }
    if (!row.uses.contains(use)) {
      throw StudioException(consentRequired, use);
    }
    return row;
  }

  void recordExecution(String voiceProfileId) {
    require(voiceProfileId, 'voiceClone');
    newExecutions[voiceProfileId] = (newExecutions[voiceProfileId] ?? 0) + 1;
  }

  int executionCount(String voiceProfileId) =>
      newExecutions[voiceProfileId] ?? 0;
}
