import '../api/api_client.dart';
import '../models/catalog.dart';
import '../models/operations.dart';

/// Filters for the day board (`GET …/reservations`).
///
/// `date` is resolved by the server in the branch timezone, which is why the
/// board sends a `yyyy-MM-dd` key rather than a timestamp.
class ReservationQuery {
  const ReservationQuery({
    this.date,
    this.status,
    this.from,
    this.to,
    this.page,
    this.limit,
  });

  final String? date;
  final String? status;
  final String? from;
  final String? to;
  final int? page;
  final int? limit;

  Map<String, dynamic> toQuery() => {
    'date': ?date,
    'status': ?status,
    'from': ?from,
    'to': ?to,
    'page': ?page,
    'limit': ?limit,
  };
}

/// The payload for a phone-in booking (`POST …/reservations`).
///
/// The desk takes these over the phone, so `status` defaults to `confirmed`
/// server-side, a guest who has agreed on the phone is not left pending.
class PhoneBookingInput {
  const PhoneBookingInput({
    required this.guestName,
    required this.partySize,
    required this.startAt,
    this.guestPhone = '',
    this.durationMinutes = 90,
    this.tableId,
    this.branchId,
    this.notes = '',
    this.status = 'confirmed',
  });

  final String guestName;
  final String guestPhone;
  final int partySize;
  final DateTime startAt;
  final int durationMinutes;
  final String? tableId;
  final String? branchId;
  final String notes;
  final String status;

  Map<String, dynamic> toBody() => {
    'guestName': guestName.trim(),
    'guestPhone': guestPhone.trim(),
    'partySize': partySize,
    'startAt': startAt.toUtc().toIso8601String(),
    'durationMinutes': durationMinutes,
    'tableId': ?tableId,
    'branchId': ?branchId,
    'notes': notes.trim(),
    'status': status,
  };
}

/// Tables, availability, reservations, bookings and door check-in.
class OperationsRepository {
  OperationsRepository(this._api);

  final ApiClient _api;

  static String base(String venueId) => '/partner/restaurants/$venueId';

  // ── Tables ─────────────────────────────────────────────────────────────────

  Future<List<DiningTable>> tables(String venueId) async {
    final envelope = await _api.envelopeGet('${base(venueId)}/tables');
    return envelope.list('tables', DiningTable.fromJson);
  }

  Future<DiningTable> createTable(
    String venueId, {
    required String label,
    required int seats,
    String zone = '',
    String? branchId,
    bool isActive = true,
  }) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/tables',
      body: {
        'label': label.trim(),
        'seats': seats,
        'zone': zone.trim(),
        'isActive': isActive,
        'branchId': ?branchId,
      },
    );
    final table = envelope.single('table', DiningTable.fromJson);
    if (table == null) throw StateError('Table payload missing');
    return table;
  }

  Future<DiningTable> updateTable(
    String venueId,
    String tableId, {
    String? label,
    int? seats,
    String? zone,
    bool? isActive,
  }) async {
    final envelope = await _api.envelopePatch(
      '${base(venueId)}/tables/$tableId',
      body: {
        if (label != null) 'label': label.trim(),
        'seats': ?seats,
        if (zone != null) 'zone': zone.trim(),
        'isActive': ?isActive,
      },
    );
    final table = envelope.single('table', DiningTable.fromJson);
    if (table == null) throw StateError('Table payload missing');
    return table;
  }

  /// Deactivates rather than deletes, a table a guest sat at stays on record.
  Future<void> deleteTable(String venueId, String tableId) =>
      _api.deleteJson('${base(venueId)}/tables/$tableId');

  // ── Availability ───────────────────────────────────────────────────────────

  Future<DayAvailability> availability(
    String venueId, {
    required String date,
    int partySize = 2,
    String? branchId,
  }) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/availability',
      query: {
        'date': date,
        'partySize': partySize,
        'branchId': ?branchId,
      },
    );
    return envelope.whole(DayAvailability.fromJson);
  }

  // ── Reservations ───────────────────────────────────────────────────────────

  Future<List<Reservation>> reservations(
    String venueId, [
    ReservationQuery query = const ReservationQuery(),
  ]) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/reservations',
      query: query.toQuery(),
    );
    return envelope.list('reservations', Reservation.fromJson);
  }

  /// Every reservation in one window, for the Insights chart.
  ///
  /// The route already takes `from`/`to` instants and pages its answer, so the
  /// range is resolved on the server rather than by filtering a page of the
  /// oldest rows on the device (which is what made the previous chart wrong).
  /// Two pages are fetched at most: a full quarter of daily service fits well
  /// inside 400 rows for a single venue, and beyond that the caller is told the
  /// window was cut instead of being handed a silently short series.
  ///
  /// The answer is trimmed to `[from, to)` before it is returned: the route
  /// compares `to` inclusively, so a booking made for exactly the midnight the
  /// window ends at would otherwise reach a chart that cannot place it.
  Future<ReservationWindow> reservationWindow(
    String venueId, {
    required DateTime from,
    required DateTime to,
    int pageLimit = 200,
    int maxPages = 2,
  }) async {
    final rows = <Reservation>[];
    var total = 0;
    for (var page = 1; page <= maxPages; page++) {
      final envelope = await _api.envelopeGet(
        '${base(venueId)}/reservations',
        query: ReservationQuery(
          from: from.toUtc().toIso8601String(),
          to: to.toUtc().toIso8601String(),
          page: page,
          limit: pageLimit,
        ).toQuery(),
      );
      rows.addAll(envelope.list('reservations', Reservation.fromJson));
      // An older server sends no `meta`; then the page itself is the whole
      // answer and there is nothing to page through.
      if (!envelope.meta.hasMeta) {
        return ReservationWindow(reservations: rows, total: rows.length)
            .clampedTo(from, to);
      }
      total = envelope.meta.total;
      if (!envelope.meta.hasMore || rows.length >= total) break;
    }
    return ReservationWindow(reservations: rows, total: total)
        .clampedTo(from, to);
  }

  Future<Reservation> reservation(String venueId, String reservationId) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/reservations/$reservationId',
    );
    final row = envelope.single('reservation', Reservation.fromJson);
    if (row == null) throw StateError('Reservation payload missing');
    return row;
  }

  Future<Reservation> createPhoneBooking(
    String venueId,
    PhoneBookingInput input,
  ) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/reservations',
      body: input.toBody(),
    );
    final row = envelope.single('reservation', Reservation.fromJson);
    if (row == null) throw StateError('Reservation payload missing');
    return row;
  }

  /// One step of the transition map. A `409` means the row moved under the
  /// operator (guest cancelled, another desk seated it) and the message from
  /// the server is what the board should show.
  Future<Reservation> actOnReservation(
    String venueId,
    String reservationId,
    ReservationAction action,
  ) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/reservations/$reservationId/${action.path}',
    );
    final row = envelope.single('reservation', Reservation.fromJson);
    if (row == null) throw StateError('Reservation payload missing');
    return row;
  }

  // ── Bookings & check-in ────────────────────────────────────────────────────

  /// Ticket sales for the account's experiences. Not venue-scoped on the server,
  /// so the screen filters by the selected venue's experiences locally.
  Future<List<PartnerBooking>> bookings({
    String? eventId,
    String? status,
    int limit = 100,
  }) async {
    final envelope = await _api.envelopeGet(
      '/partner/bookings',
      query: {
        'eventId': ?eventId,
        'status': ?status,
        'limit': limit,
      },
    );
    return envelope.list('bookings', PartnerBooking.fromJson);
  }

  /// Door scan. `409` carries "already checked in" or "cancelled", which the
  /// result sheet renders as distinct outcomes instead of one failure.
  Future<PartnerBooking> checkIn(String bookingId) async {
    final envelope = await _api.envelopePost(
      '/partner/bookings/$bookingId/checkin',
    );
    final row = envelope.single('booking', PartnerBooking.fromJson);
    if (row == null) throw StateError('Booking payload missing');
    return row;
  }
}
