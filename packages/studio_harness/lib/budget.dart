import 'package:studio_contracts/studio_contracts.dart';

const budgetExhausted = 'BUDGET_EXHAUSTED';
const reservationNotFound = 'RESERVATION_NOT_FOUND';
const reservationClosed = 'RESERVATION_CLOSED';

enum ReservationState { reserved, settled, released }

final class Reservation {
  Reservation({
    required this.id,
    required this.amount,
    required this.resourceId,
    required this.revision,
  });

  final String id, resourceId;
  final int amount, revision;
  ReservationState state = ReservationState.reserved;
  int settled = 0;
}

/// Unit ledger for reserved, settled, and released amounts. Exhaustion
/// pauses further reservations. This is not a permission grant and does
/// not call a paid API.
final class BudgetLedger {
  BudgetLedger({required this.capacity});

  final int capacity;
  final Map<String, Reservation> reservations = {};
  int reserved = 0;
  int settled = 0;
  int released = 0;
  int _n = 0;
  bool paused = false;

  int get available => capacity - reserved - settled;

  Reservation reserve({
    required int amount,
    required String resourceId,
    required int revision,
  }) {
    requireId(resourceId);
    if (amount <= 0) throw const StudioException('INVALID_ID', 'amount');
    if (paused || amount > available) {
      paused = true;
      throw const StudioException(budgetExhausted);
    }
    _n++;
    final row = Reservation(
      id: 'rsv-$_n',
      amount: amount,
      resourceId: resourceId,
      revision: revision,
    );
    reservations[row.id] = row;
    reserved += amount;
    return row;
  }

  void settle(String reservationId, {required int actual}) {
    final row = _requireOpen(reservationId);
    if (actual < 0 || actual > row.amount) {
      throw const StudioException('INVALID_ID', 'actual');
    }
    reserved -= row.amount;
    settled += actual;
    released += row.amount - actual;
    row.settled = actual;
    row.state = ReservationState.settled;
    if (available <= 0) paused = true;
  }

  void release(String reservationId) {
    final row = _requireOpen(reservationId);
    reserved -= row.amount;
    released += row.amount;
    row.state = ReservationState.released;
  }

  Reservation _requireOpen(String reservationId) {
    final row = reservations[reservationId];
    if (row == null) throw StudioException(reservationNotFound, reservationId);
    if (row.state != ReservationState.reserved) {
      throw StudioException(reservationClosed, reservationId);
    }
    return row;
  }
}
