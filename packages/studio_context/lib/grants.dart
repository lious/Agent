import 'package:studio_contracts/studio_contracts.dart';

import 'context_codes.dart';

enum GrantState { active, revoked }

/// read, analyze, and uploadSubset do not imply one another. Analyze
/// permission is not consent to upload to a third party.
final class SourceUseGrant {
  SourceUseGrant({
    required this.id,
    required this.sourceId,
    required Set<String> permitted,
    this.epoch = 1,
    this.state = GrantState.active,
    this.expiresAt,
  }) : permitted = Set.unmodifiable(permitted) {
    requireId(id);
    requireId(sourceId);
  }

  final String id, sourceId;
  final Set<String> permitted;
  final int epoch;
  GrantState state;
  final DateTime? expiresAt;

  bool get revoked => state == GrantState.revoked;

  void requireActive(String use, {required DateTime now}) {
    if (revoked) throw StudioException(grantRevoked, id);
    if (expiresAt != null && !expiresAt!.isAfter(now)) {
      throw StudioException(grantRevoked, 'expired');
    }
    if (!permitted.contains(use)) {
      if (use == 'uploadSubset') {
        throw StudioException(uploadConsentRequired, id);
      }
      throw StudioException(grantRequired, use);
    }
  }
}
