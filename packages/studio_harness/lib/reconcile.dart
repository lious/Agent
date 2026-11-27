import 'package:studio_contracts/studio_contracts.dart';

import 'approval.dart';
import 'budget.dart';

const unknownNoBlindRetry = 'UNKNOWN_NO_BLIND_RETRY';
const lateCancelSettleOnly = 'LATE_CANCEL_SETTLE_ONLY';
const consentRequired = 'CONSENT_REQUIRED';
const warningDoesNotExempt = 'WARNING_DOES_NOT_EXEMPT';
const timelineAttachForbidden = 'TIMELINE_ATTACH_FORBIDDEN';

enum SubmissionState { posted, unknown, settled, cancelled }

final class ConsentSet {
  const ConsentSet({
    required this.fee,
    required this.upload,
    required this.portrait,
  });

  final bool fee, upload, portrait;

  void requireAll({bool licenseWarning = false}) {
    if (fee && upload && portrait) return;
    if (licenseWarning) {
      throw const StudioException(warningDoesNotExempt, 'consent');
    }
    throw const StudioException(consentRequired);
  }
}

/// Synthetic provider used by official DEV tests. It never calls a paid API.
final class FakeBillingProvider {
  int postCount = 0;
  String nextStatus = 'ok';
  final Map<String, String> statuses = {};

  String post(String idempotencyKey) {
    postCount++;
    statuses[idempotencyKey] = nextStatus;
    return nextStatus;
  }

  String statusOf(String idempotencyKey) =>
      statuses[idempotencyKey] ?? 'missing';

  void resolve(String idempotencyKey, String status) {
    statuses[idempotencyKey] = status;
  }
}

final class Receipt {
  Receipt({
    required this.id,
    required this.idempotencyKey,
    required this.approvalId,
    required this.reservationId,
    required this.state,
  });

  final String id, idempotencyKey, approvalId, reservationId;
  SubmissionState state;
}

/// Single-submit reconciler with an outbox of receipts. The same
/// idempotency key causes at most one provider POST. This is not a
/// permission grant.
final class SubmissionReconciler {
  SubmissionReconciler({
    required this.approvals,
    required this.ledger,
    FakeBillingProvider? provider,
  }) : provider = provider ?? FakeBillingProvider();

  final ApprovalService approvals;
  final BudgetLedger ledger;
  final FakeBillingProvider provider;
  final Map<String, Receipt> receipts = {};
  final List<String> timeline = [];
  int _n = 0;

  Receipt submit({
    required String idempotencyKey,
    required String approvalId,
    required ApprovalBinding binding,
    required String reservationId,
    required ConsentSet consents,
    bool licenseWarning = false,
  }) {
    requireId(idempotencyKey);
    consents.requireAll(licenseWarning: licenseWarning);
    final existing = receipts[idempotencyKey];
    if (existing != null) {
      // At most one POST. An unknown receipt is not blindly retried.
      if (existing.state == SubmissionState.unknown) {
        throw StudioException(unknownNoBlindRetry, idempotencyKey);
      }
      return existing;
    }
    approvals.requireFresh(approvalId, binding);
    final reservation = ledger.reservations[reservationId];
    if (reservation == null) {
      throw StudioException(reservationNotFound, reservationId);
    }
    if (reservation.state != ReservationState.reserved) {
      throw StudioException(reservationClosed, reservationId);
    }
    if (reservation.resourceId != binding.resourceId ||
        reservation.revision != binding.revision) {
      throw StudioException(approvalStale, 'reservation-binding');
    }
    final status = provider.post(idempotencyKey);
    _n++;
    final receipt = Receipt(
      id: 'rcpt-$_n',
      idempotencyKey: idempotencyKey,
      approvalId: approvalId,
      reservationId: reservationId,
      state: status == 'unknown' ? SubmissionState.unknown : SubmissionState.posted,
    );
    receipts[idempotencyKey] = receipt;
    if (receipt.state == SubmissionState.posted) {
      ledger.settle(reservationId, actual: reservation.amount);
      receipt.state = SubmissionState.settled;
      timeline.add(receipt.id);
    }
    return receipt;
  }

  /// Poll an unknown submission. This does not issue another POST.
  Receipt poll(String idempotencyKey) {
    final receipt = receipts[idempotencyKey];
    if (receipt == null) throw StudioException('INVALID_ID', idempotencyKey);
    if (receipt.state != SubmissionState.unknown) return receipt;
    final status = provider.statusOf(idempotencyKey);
    if (status == 'unknown') return receipt;
    if (status == 'ok') {
      final reservation = ledger.reservations[receipt.reservationId]!;
      if (reservation.state == ReservationState.reserved) {
        ledger.settle(receipt.reservationId, actual: reservation.amount);
      }
      receipt.state = SubmissionState.settled;
      if (!timeline.contains(receipt.id)) timeline.add(receipt.id);
    }
    return receipt;
  }

  /// A late cancel after a post only settles leftover reservation and
  /// never attaches a new timeline event.
  Receipt cancelLate(String idempotencyKey) {
    final receipt = receipts[idempotencyKey];
    if (receipt == null) throw StudioException('INVALID_ID', idempotencyKey);
    final reservation = ledger.reservations[receipt.reservationId]!;
    if (receipt.state == SubmissionState.unknown &&
        reservation.state == ReservationState.reserved) {
      ledger.release(receipt.reservationId);
      receipt.state = SubmissionState.cancelled;
    }
    // Already-settled posts stay settled. A late cancel never appends.
    return receipt;
  }

  void forbidTimelineAttach(String receiptId) {
    if (timeline.contains(receiptId)) {
      // Already attached from a successful settle; late cancel must not add again.
      return;
    }
    throw const StudioException(timelineAttachForbidden);
  }
}
