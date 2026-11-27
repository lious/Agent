import 'package:studio_contracts/studio_contracts.dart';
import 'package:studio_harness/studio_harness.dart';
import 'package:test/test.dart';

Matcher code(String value) =>
    throwsA(isA<StudioException>().having((e) => e.code, 'code', value));

const promptHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const summaryHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

ApprovalBinding binding({int revision = 1}) => ApprovalBinding(
  promptHash: promptHash,
  resourceId: 'res-1',
  revision: revision,
);

const consents = ConsentSet(fee: true, upload: true, portrait: true);

void main() {
  test('the same idempotency key causes at most one provider POST', () {
    final approvals = ApprovalService();
    final ledger = BudgetLedger(capacity: 10);
    final reconciler = SubmissionReconciler(approvals: approvals, ledger: ledger);
    final approval = approvals.approve(summaryHash: summaryHash, binding: binding());
    final reservation = ledger.reserve(amount: 3, resourceId: 'res-1', revision: 1);
    final first = reconciler.submit(
      idempotencyKey: 'idem-1',
      approvalId: approval.id,
      binding: binding(),
      reservationId: reservation.id,
      consents: consents,
    );
    expect(first.state, SubmissionState.settled);
    expect(reconciler.provider.postCount, 1);
    final second = reconciler.submit(
      idempotencyKey: 'idem-1',
      approvalId: approval.id,
      binding: binding(),
      reservationId: reservation.id,
      consents: consents,
    );
    expect(second.id, first.id);
    expect(reconciler.provider.postCount, 1);
    expect(reconciler.timeline, [first.id]);
  });

  test('an unknown provider status is not blindly retried with a second POST', () {
    final approvals = ApprovalService();
    final ledger = BudgetLedger(capacity: 10);
    final reconciler = SubmissionReconciler(approvals: approvals, ledger: ledger);
    reconciler.provider.nextStatus = 'unknown';
    final approval = approvals.approve(summaryHash: summaryHash, binding: binding());
    final reservation = ledger.reserve(amount: 2, resourceId: 'res-1', revision: 1);
    final receipt = reconciler.submit(
      idempotencyKey: 'idem-u',
      approvalId: approval.id,
      binding: binding(),
      reservationId: reservation.id,
      consents: consents,
    );
    expect(receipt.state, SubmissionState.unknown);
    expect(reconciler.provider.postCount, 1);
    expect(reconciler.timeline, isEmpty);
    expect(
      () => reconciler.submit(
        idempotencyKey: 'idem-u',
        approvalId: approval.id,
        binding: binding(),
        reservationId: reservation.id,
        consents: consents,
      ),
      code(unknownNoBlindRetry),
    );
    expect(reconciler.provider.postCount, 1);
    final stillUnknown = reconciler.poll('idem-u');
    expect(stillUnknown.state, SubmissionState.unknown);
    expect(reconciler.provider.postCount, 1);
    reconciler.provider.resolve('idem-u', 'ok');
    final settled = reconciler.poll('idem-u');
    expect(settled.state, SubmissionState.settled);
    expect(reconciler.provider.postCount, 1);
    expect(reconciler.timeline, [settled.id]);
  });

  test('a late cancel only settles or releases and does not attach to the timeline', () {
    final approvals = ApprovalService();
    final ledger = BudgetLedger(capacity: 10);
    final reconciler = SubmissionReconciler(approvals: approvals, ledger: ledger);
    reconciler.provider.nextStatus = 'unknown';
    final approval = approvals.approve(summaryHash: summaryHash, binding: binding());
    final reservation = ledger.reserve(amount: 2, resourceId: 'res-1', revision: 1);
    final receipt = reconciler.submit(
      idempotencyKey: 'idem-c',
      approvalId: approval.id,
      binding: binding(),
      reservationId: reservation.id,
      consents: consents,
    );
    expect(receipt.state, SubmissionState.unknown);
    expect(reconciler.timeline, isEmpty);
    final cancelled = reconciler.cancelLate('idem-c');
    expect(cancelled.state, SubmissionState.cancelled);
    expect(reconciler.timeline, isEmpty);
    expect(ledger.reservations[reservation.id]!.state, ReservationState.released);
    expect(
      () => reconciler.forbidTimelineAttach(cancelled.id),
      code(timelineAttachForbidden),
    );
  });

  test('fee, upload, or portrait consent cannot be waived by a license warning', () {
    final approvals = ApprovalService();
    final ledger = BudgetLedger(capacity: 10);
    final reconciler = SubmissionReconciler(approvals: approvals, ledger: ledger);
    final approval = approvals.approve(summaryHash: summaryHash, binding: binding());
    final reservation = ledger.reserve(amount: 1, resourceId: 'res-1', revision: 1);
    expect(
      () => reconciler.submit(
        idempotencyKey: 'idem-n',
        approvalId: approval.id,
        binding: binding(),
        reservationId: reservation.id,
        consents: const ConsentSet(fee: true, upload: false, portrait: true),
        licenseWarning: true,
      ),
      code(warningDoesNotExempt),
    );
    expect(reconciler.provider.postCount, 0);
    expect(reconciler.timeline, isEmpty);
  });

  test('a binding change invalidates approval and does not auto-increase budget', () {
    final approvals = ApprovalService();
    final ledger = BudgetLedger(capacity: 5);
    final reconciler = SubmissionReconciler(approvals: approvals, ledger: ledger);
    final approval = approvals.approve(summaryHash: summaryHash, binding: binding());
    final reservation = ledger.reserve(amount: 5, resourceId: 'res-1', revision: 1);
    expect(ledger.available, 0);
    expect(
      () => ledger.reserve(amount: 1, resourceId: 'res-1', revision: 2),
      code(budgetExhausted),
    );
    expect(ledger.paused, isTrue);
    expect(ledger.capacity, 5);
    expect(
      () => reconciler.submit(
        idempotencyKey: 'idem-b',
        approvalId: approval.id,
        binding: binding(revision: 2),
        reservationId: reservation.id,
        consents: consents,
      ),
      code(approvalStale),
    );
    expect(reconciler.provider.postCount, 0);
  });

  test('a late cancel after a settled post does not append a timeline event', () {
    final approvals = ApprovalService();
    final ledger = BudgetLedger(capacity: 10);
    final reconciler = SubmissionReconciler(approvals: approvals, ledger: ledger);
    final approval = approvals.approve(summaryHash: summaryHash, binding: binding());
    final reservation = ledger.reserve(amount: 2, resourceId: 'res-1', revision: 1);
    final receipt = reconciler.submit(
      idempotencyKey: 'idem-s',
      approvalId: approval.id,
      binding: binding(),
      reservationId: reservation.id,
      consents: consents,
    );
    expect(receipt.state, SubmissionState.settled);
    expect(reconciler.timeline, [receipt.id]);
    final after = reconciler.cancelLate('idem-s');
    expect(after.state, SubmissionState.settled);
    expect(reconciler.timeline, [receipt.id]);
    expect(ledger.reservations[reservation.id]!.state, ReservationState.settled);
  });
}
