import 'portrait_rights.dart';

/// Official 8E rights gate.
///
/// [evaluate] consults live authority/epoch. A project pin freezes the
/// pack content only; it never freezes permission. Real-person new cloud
/// generation requires a fresh [FreshOnlineRightsCheck] when the offline
/// lease is missing or expired. The port is injectable and is not a paid
/// commercial rights API.
final class PortraitRightsGate {
  const PortraitRightsGate();

  RightsDecision evaluate({
    required Map<String, Object?> asset,
    required Map<String, Object?> rightsRecord,
    required Map<String, Object?>? live,
    required String operation,
    required String provider,
    required String region,
    required DateTime now,
    DispatchContext context = const DispatchContext(),
  }) {
    final rightsId = asset['portraitRightsId'] as String;
    final epoch = live?['epoch'] as String? ?? '0';
    final policy = rightsRecord['existingOutputsPolicy'] as String?;
    RightsDecision deny(String code) => RightsDecision.deny(
      code,
      rightsId: rightsId,
      epoch: epoch,
      existingOutputsPolicy: policy,
    );

    if (live == null || live['state'] == 'unknown') {
      return deny('RIGHTS_REQUIRED');
    }
    if (live['state'] == 'revoked') {
      return deny('RIGHTS_REVOKED');
    }
    if (live['state'] == 'expired') {
      return deny('RIGHTS_EXPIRED');
    }
    final expiresAt = rightsRecord['expiresAt'] as String?;
    final utcNow = now.toUtc();
    if (expiresAt != null && DateTime.parse(expiresAt).isBefore(utcNow)) {
      return deny('RIGHTS_EXPIRED');
    }

    final kind = asset['kind'] as String?;
    final subjectKind = rightsRecord['subjectKind'] as String?;
    final realPerson = kind == 'realPerson' || subjectKind == 'realPerson';
    final cloudDispatch =
        context.cloud && characterDispatchOperations.contains(operation);
    DateTime? acceptedLease;
    DateTime? acceptedCheckedAt;
    if (realPerson && cloudDispatch) {
      final leaseUntilRaw = live['lease_until'] as String?;
      final leaseValid =
          leaseUntilRaw != null &&
          DateTime.parse(leaseUntilRaw).toUtc().isAfter(utcNow);
      if (!leaseValid) {
        if (context.offline || context.onlineCheck == null) {
          return deny('FRESH_ONLINE_CHECK_REQUIRED');
        }
        final inspected = context.onlineCheck!.inspect(
          rightsId: rightsId,
          epoch: epoch,
          now: utcNow,
        );
        // A stub cannot override a known revocation; that state was already
        // denied above. A non-fresh result, or one that reports revoked,
        // still fails closed.
        if (!inspected.fresh || inspected.state == 'revoked') {
          return deny('FRESH_ONLINE_CHECK_REQUIRED');
        }
        acceptedLease = inspected.leaseUntil?.toUtc();
        acceptedCheckedAt = inspected.checkedAt?.toUtc() ?? utcNow;
        if (acceptedLease == null || !acceptedLease.isAfter(utcNow)) {
          return deny('FRESH_ONLINE_CHECK_REQUIRED');
        }
      }
    }

    final uses = (rightsRecord['allowedUses'] as List).cast<String>();
    if (!uses.contains(operation)) {
      return deny('RIGHTS_REQUIRED');
    }
    final providers = (rightsRecord['allowedProviderIds'] as List)
        .cast<String>();
    if (providers.isNotEmpty && !providers.contains(provider)) {
      return deny('RIGHTS_REQUIRED');
    }
    final territories = (rightsRecord['territories'] as List).cast<String>();
    if (territories.isNotEmpty && !territories.contains(region)) {
      return deny('RIGHTS_REQUIRED');
    }
    return RightsDecision.allow(
      rightsId: rightsId,
      epoch: epoch,
      existingOutputsPolicy: policy,
      leaseUntil: acceptedLease?.toIso8601String(),
      checkedAt: acceptedCheckedAt?.toIso8601String(),
    );
  }
}
