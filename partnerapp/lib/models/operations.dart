import '../api/json.dart';

/// Table-reservation lifecycle, mirroring `TRANSITIONS` in
/// `server/src/reservations.ts`. Statuses in [holdsCovers] keep a slot busy.
enum ReservationStatus {
  pending('pending', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  seated('seated', 'Seated'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  noShow('no_show', 'No-show');

  const ReservationStatus(this.wire, this.label);

  final String wire;
  final String label;

  static ReservationStatus parse(String? value) =>
      ReservationStatus.values.firstWhere(
        (status) => status.wire == value,
        orElse: () => ReservationStatus.pending,
      );

  bool get holdsCovers =>
      this == pending || this == confirmed || this == seated;
}

/// A desk action. [path] is the URL segment the partner route expects (note the
/// hyphen in `no-show`), [target] the status the server moves the row to.
enum ReservationAction {
  confirm('confirm', 'Confirm', ReservationStatus.confirmed),
  seat('seat', 'Seat the party', ReservationStatus.seated),
  complete('complete', 'Complete', ReservationStatus.completed),
  cancel('cancel', 'Cancel', ReservationStatus.cancelled),
  noShow('no-show', 'Mark no-show', ReservationStatus.noShow);

  const ReservationAction(this.path, this.label, this.target);

  final String path;
  final String label;
  final ReservationStatus target;
}

/// The legal transition table duplicated deliberately: it drives which buttons
/// render, so the desk never taps an action the server will answer with `409`.
const Map<ReservationStatus, List<ReservationAction>> kReservationTransitions = {
  ReservationStatus.pending: [
    ReservationAction.confirm,
    ReservationAction.cancel,
    ReservationAction.noShow,
  ],
  ReservationStatus.confirmed: [
    ReservationAction.seat,
    ReservationAction.cancel,
    ReservationAction.noShow,
  ],
  ReservationStatus.seated: [ReservationAction.complete],
  ReservationStatus.completed: [],
  ReservationStatus.cancelled: [],
  ReservationStatus.noShow: [],
};

/// A table reservation (`…/reservations`).
class Reservation {
  const Reservation({
    required this.id,
    required this.restaurantId,
    required this.guestName,
    required this.partySize,
    required this.startAt,
    required this.status,
    this.branchId,
    this.tableId,
    this.userId,
    this.guestPhone = '',
    this.durationMinutes = 90,
    this.endsAt,
    this.reference = '',
    this.notes = '',
    this.source = 'guest',
    this.createdAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
    id: asString(json['id']),
    restaurantId: asString(json['restaurantId']),
    branchId: asStringOrNull(json['branchId']),
    tableId: asStringOrNull(json['tableId']),
    userId: asStringOrNull(json['userId']),
    guestName: asString(json['guestName']),
    guestPhone: asString(json['guestPhone']),
    partySize: asInt(json['partySize']),
    startAt: asDateOr(json['startAt'], DateTime.now()),
    endsAt: asDate(json['endsAt']),
    durationMinutes: asInt(json['durationMinutes'], fallback: 90),
    status: ReservationStatus.parse(asString(json['status'])),
    reference: asString(json['reference']),
    notes: asString(json['notes']),
    source: asString(json['source'], fallback: 'guest'),
    createdAt: asDate(json['createdAt']),
  );

  final String id;
  final String restaurantId;
  final String? branchId;
  final String? tableId;
  final String? userId;
  final String guestName;
  final String guestPhone;
  final int partySize;
  final DateTime startAt;
  final DateTime? endsAt;
  final int durationMinutes;
  final ReservationStatus status;
  final String reference;
  final String notes;

  /// `guest` when the diner booked in the Customer App, `partner` for a booking
  /// taken over the phone by the desk.
  final String source;
  final DateTime? createdAt;

  List<ReservationAction> get allowedActions =>
      kReservationTransitions[status] ?? const [];

  bool get isPhoneIn => source == 'partner' || source == 'phone';

  DateTime get endTime =>
      endsAt ?? startAt.add(Duration(minutes: durationMinutes));

  String get timeLabel =>
      '${_hhmm(startAt)}–${_hhmm(endTime)}';

  String get partyLabel => '$partySize ${partySize == 1 ? 'guest' : 'guests'}';

  static String _hhmm(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

/// One date window of table reservations, plus the server's own total.
///
/// The day board reads a page and stops, because it renders what it got. A
/// trend chart cannot: it has to know whether the rows it received describe the
/// whole window or only the first page of it. [total] is the count the server
/// reports for the same `from`/`to`, so a partial read can say so instead of
/// drawing an axis that quietly leaves reservations out.
class ReservationWindow {
  const ReservationWindow({
    required this.reservations,
    required this.total,
  });

  final List<Reservation> reservations;

  /// Every reservation in the window on the server, whatever its status.
  final int total;

  /// True when the page ceiling cut the window short.
  bool get truncated => reservations.length < total;

  /// The same window with rows that fall outside `[from, to)` removed.
  ///
  /// The partner route compares `to` inclusively, while Insights asks for a
  /// half-open window that ends at midnight after the last day. A booking made
  /// for exactly that midnight comes back in the answer, but it belongs to the
  /// next day: the chart stops at today and cannot place it, so the KPI would
  /// count a booking the chart leaves out. Trimming the rows and [total]
  /// together keeps every card on this page describing the same window, no
  /// matter which way the server compares its bounds.
  ReservationWindow clampedTo(DateTime from, DateTime to) {
    final kept = reservations
        .where((row) => !row.startAt.isBefore(from) && row.startAt.isBefore(to))
        .toList(growable: false);
    if (kept.length == reservations.length) return this;
    final trimmedTotal = total - (reservations.length - kept.length);
    return ReservationWindow(
      reservations: kept,
      total: trimmedTotal < kept.length ? kept.length : trimmedTotal,
    );
  }

  /// Bookings the venue actually serves: anything but a cancellation or a
  /// no-show, the same rule [ReservationCounters.booked] follows on Home.
  List<Reservation> get kept => reservations
      .where(
        (row) =>
            row.status != ReservationStatus.cancelled &&
            row.status != ReservationStatus.noShow,
      )
      .toList(growable: false);

  int get keptCount => kept.length;

  int get lostCount => reservations.length - keptCount;
}

/// Booking status for experience tickets (`/partner/bookings`).
enum BookingStatus {
  pending('pending', 'Pending'),
  confirmed('confirmed', 'Confirmed'),
  cancelled('cancelled', 'Cancelled'),
  refunded('refunded', 'Refunded');

  const BookingStatus(this.wire, this.label);

  final String wire;
  final String label;

  static BookingStatus parse(String? value) => BookingStatus.values.firstWhere(
    (status) => status.wire == value,
    orElse: () => BookingStatus.pending,
  );
}

/// A sold seat bundle for a dining experience.
///
/// Guest dietary requirements are not part of this payload, the platform does
/// not expose them to venues yet, so the detail sheet says so rather than
/// implying the data is missing by accident.
class PartnerBooking {
  const PartnerBooking({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.guestName,
    required this.seats,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.reference,
    required this.checkedIn,
    this.guestId = '',
    this.createdAt,
  });

  factory PartnerBooking.fromJson(Map<String, dynamic> json) => PartnerBooking(
    id: asString(json['id']),
    eventId: asString(json['eventId']),
    eventTitle: asString(json['eventTitle']),
    guestId: asString(json['userId']),
    guestName: asString(json['userName']),
    seats: asInt(json['seats']),
    totalAmount: asDouble(json['totalAmount']),
    status: BookingStatus.parse(asString(json['status'])),
    paymentStatus: asString(json['paymentStatus']),
    reference: asString(json['reference']),
    checkedIn: asBool(json['checkedIn']),
    createdAt: asDate(json['createdAt']),
  );

  final String id;
  final String eventId;
  final String eventTitle;
  final String guestId;
  final String guestName;
  final int seats;
  final double totalAmount;
  final BookingStatus status;
  final String paymentStatus;
  final String reference;
  final bool checkedIn;
  final DateTime? createdAt;

  bool get isCancelled => status == BookingStatus.cancelled;
  bool get isPaid => paymentStatus == 'paid';

  /// Only a paid, live ticket may be checked in.
  bool get canCheckIn => !isCancelled && !checkedIn && isPaid;

  String get amountLabel =>
      '$seats seat${seats == 1 ? '' : 's'} · ${totalAmount.toStringAsFixed(2)}';
}

/// Parses the hourly trend array from the dashboard JSON.
///
/// An older server that does not emit `trend` yields an empty list, so the
/// home timeline simply does not render — it never fabricates bars.
List<HourlyTrend> _parseTrend(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(
        (e) => HourlyTrend(hour: asInt(e['hour']), count: asInt(e['count'])),
      )
      .toList();
}

/// Everything the operational home needs, from one request.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.venue,
    required this.today,
    required this.events,
    required this.deals,
    required this.scans,
    required this.earnings,
    required this.unreadNotifications,
    this.scansAvailable = true,
    this.fetchedAt,
  });

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final venue = asMap(json['restaurant']);
    final today = asMap(json['today']);
    final reservations = asMap(today['reservations']);
    final events = asMap(json['events']);
    final deals = asMap(json['deals']);
    final scans = asMap(json['scans']);
    final earnings = asMap(json['earnings']);
    return DashboardSnapshot(
      venue: DashboardVenueHeader(
        id: asString(venue['id']),
        name: asString(venue['name']),
        partnershipStatus: asString(
          venue['partnershipStatus'],
          fallback: 'unverified',
        ),
        verified: asBool(venue['verified']),
        acceptingBookings: asBool(venue['acceptingBookings']),
        requiresHostApproval: asBool(venue['requiresHostApproval']),
        profileCompletion: asInt(venue['profileCompletion']),
      ),
      today: TodayService(
        date: asString(today['date']),
        timeZone: asString(today['timeZone'], fallback: 'UTC'),
        reservations: ReservationCounters(
          pending: asInt(reservations['pending']),
          confirmed: asInt(reservations['confirmed']),
          seated: asInt(reservations['seated']),
          completed: asInt(reservations['completed']),
          cancelled: asInt(reservations['cancelled']),
          noShow: asInt(reservations['noShow']),
        ),
        covers: asInt(today['covers']),
        capacity: asInt(today['capacity']),
        tables: asInt(today['tables']),
        occupancy: asDouble(today['occupancy']),
        trend: _parseTrend(today['trend']),
        yesterdayCovers: asInt(today['yesterdayCovers']),
        nextBookingAt: asDate(today['nextBookingAt']),
      ),
      events: ExperienceSummary(
        upcoming: asInt(events['upcoming']),
        live: asInt(events['live']),
        pendingRequests: asInt(events['pendingRequests']),
      ),
      deals: DealSummary(
        active: asInt(deals['active']),
        drafts: asInt(deals['drafts']),
      ),
      scans: QrScanSummary(
        today: asInt(scans['today']),
        week: asInt(scans['week']),
        month: asInt(scans['month']),
      ),
      earnings: MonthEarnings(
        gross: asDouble(earnings['monthGross']),
        refunds: asDouble(earnings['monthRefunds']),
        commission: asDouble(earnings['monthCommission']),
        net: asDouble(earnings['monthNet']),
        commissionRate: asDouble(earnings['commissionRate']),
      ),
      unreadNotifications: asInt(asMap(json['notifications'])['unread']),
      // An older server may omit `scans` entirely. That is "not measured",
      // which must read differently from a real zero, never fabricate 0.
      scansAvailable: json['scans'] is Map,
      fetchedAt: DateTime.now(),
    );
  }

  final DashboardVenueHeader venue;
  final TodayService today;
  final ExperienceSummary events;
  final DealSummary deals;
  final QrScanSummary scans;
  final MonthEarnings earnings;
  final int unreadNotifications;

  /// Whether the server supplied QR scan counters at all.
  final bool scansAvailable;
  final DateTime? fetchedAt;

  /// The queue a desk should work first: pending reservations, then experience
  /// requests, then a half-finished profile.
  int get pendingActionCount =>
      today.reservations.pending +
      events.pendingRequests +
      (venue.profileCompletion < 100 ? 1 : 0) +
      (venue.verified ? 0 : 1);
}

class DashboardVenueHeader {
  const DashboardVenueHeader({
    required this.id,
    required this.name,
    required this.partnershipStatus,
    required this.verified,
    required this.acceptingBookings,
    required this.requiresHostApproval,
    required this.profileCompletion,
  });

  final String id;
  final String name;
  final String partnershipStatus;
  final bool verified;
  final bool acceptingBookings;
  final bool requiresHostApproval;
  final int profileCompletion;
}

class ReservationCounters {
  const ReservationCounters({
    this.pending = 0,
    this.confirmed = 0,
    this.seated = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.noShow = 0,
  });

  final int pending;
  final int confirmed;
  final int seated;
  final int completed;
  final int cancelled;
  final int noShow;

  int get total =>
      pending + confirmed + seated + completed + cancelled + noShow;

  /// Bookings the venue still expects to serve today: every status except a
  /// cancellation or a no-show. This is what the Home "Reservations" KPI
  /// shows: [total] would count bookings that never happened.
  int get booked => pending + confirmed + seated + completed;
}

class TodayService {
  const TodayService({
    required this.date,
    required this.timeZone,
    required this.reservations,
    required this.covers,
    required this.capacity,
    required this.tables,
    required this.occupancy,
    this.trend = const [],
    this.yesterdayCovers = 0,
    this.nextBookingAt,
  });

  final String date;
  final String timeZone;
  final ReservationCounters reservations;
  final int covers;
  final int capacity;
  final int tables;
  final double occupancy;

  /// Hourly reservation counts for today, used by the home timeline widget.
  final List<HourlyTrend> trend;

  /// Yesterday's total covers, so the KPI card can show a trend arrow.
  final int yesterdayCovers;

  /// The next upcoming confirmed/pending reservation, or null if none.
  final DateTime? nextBookingAt;

  bool get hasCapacityConfigured => capacity > 0;

  /// Whether today is ahead of (or behind) yesterday by at least one cover.
  int get coversDelta => covers - yesterdayCovers;
}

/// One bar of the hourly reservation trend chart.
class HourlyTrend {
  const HourlyTrend({required this.hour, required this.count});

  final int hour;
  final int count;
}

class ExperienceSummary {
  const ExperienceSummary({
    this.upcoming = 0,
    this.live = 0,
    this.pendingRequests = 0,
  });

  final int upcoming;
  final int live;
  final int pendingRequests;
}

class DealSummary {
  const DealSummary({this.active = 0, this.drafts = 0});

  final int active;
  final int drafts;
}

class QrScanSummary {
  const QrScanSummary({this.today = 0, this.week = 0, this.month = 0});

  final int today;
  final int week;
  final int month;
}

class MonthEarnings {
  const MonthEarnings({
    this.gross = 0,
    this.refunds = 0,
    this.commission = 0,
    this.net = 0,
    this.commissionRate = 0,
  });

  final double gross;
  final double refunds;
  final double commission;

  /// `gross - refunds - commission`, computed by the server.
  final double net;

  /// Read from the server (`PLATFORM_COMMISSION_RATE`); never hardcoded.
  final double commissionRate;
}
