import '../api/json.dart';

/// Payout run state (`restaurant_payouts.status`).
enum PayoutStatus {
  scheduled('scheduled', 'Scheduled'),
  processing('processing', 'Processing'),
  paid('paid', 'Paid');

  const PayoutStatus(this.wire, this.label);

  final String wire;
  final String label;

  static PayoutStatus parse(String? value) => PayoutStatus.values.firstWhere(
    (status) => status.wire == value,
    orElse: () => PayoutStatus.scheduled,
  );
}

/// One reporting window of venue revenue (`GET …/earnings`).
///
/// `net` is computed by the server as `gross - refunds - commission`, and the
/// commission percentage is echoed rather than assumed, so a platform-side rate
/// change shows up here without an app release.
class EarningsReport {
  const EarningsReport({
    required this.from,
    required this.to,
    required this.gross,
    required this.refunds,
    required this.commission,
    required this.commissionRate,
    required this.net,
    required this.bookings,
    required this.paidBookings,
    required this.covers,
    required this.refundCount,
    required this.payoutPending,
    required this.payoutPaid,
    this.lastPaidAt,
  });

  factory EarningsReport.fromJson(Map<String, dynamic> json) {
    final payouts = asMap(json['payouts']);
    final earnings = asMap(json['earnings']);
    final payload = earnings.isEmpty ? json : earnings;
    final payoutSection = payouts.isEmpty
        ? asMap(json['payouts'])
        : payouts;
    return EarningsReport(
      from: asDateOr(payload['from'], DateTime.now()),
      to: asDateOr(payload['to'], DateTime.now()),
      gross: asDouble(payload['gross']),
      refunds: asDouble(payload['refunds']),
      commission: asDouble(payload['commission']),
      commissionRate: asDouble(payload['commissionRate']),
      net: asDouble(payload['net']),
      bookings: asInt(payload['bookings']),
      paidBookings: asInt(payload['paidBookings']),
      covers: asInt(payload['covers']),
      refundCount: asInt(payload['refundCount']),
      payoutPending: asDouble(payoutSection['pending']),
      payoutPaid: asDouble(payoutSection['paid']),
      lastPaidAt: asDate(payoutSection['lastPaidAt']),
    );
  }

  final DateTime from;
  final DateTime to;
  final double gross;
  final double refunds;
  final double commission;
  final double commissionRate;
  final double net;
  final int bookings;
  final int paidBookings;
  final int covers;
  final int refundCount;
  final double payoutPending;
  final double payoutPaid;
  final DateTime? lastPaidAt;

  /// Average ticket value for the window; zero when nothing sold.
  double get averageTicket => bookings <= 0 ? 0 : gross / bookings;

  bool get isEmpty => bookings == 0 && gross == 0;

  String get windowLabel =>
      '${_day(from)} – ${_day(to)}';

  static String _day(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

/// A single payout run (`GET …/payouts`).
class PayoutRecord {
  const PayoutRecord({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    required this.gross,
    required this.commission,
    required this.net,
    required this.status,
    this.createdAt,
  });

  factory PayoutRecord.fromJson(Map<String, dynamic> json) => PayoutRecord(
    id: asString(json['id']),
    periodStart: asDateOr(json['periodStart'], DateTime.now()),
    periodEnd: asDateOr(json['periodEnd'], DateTime.now()),
    gross: asDouble(json['gross']),
    commission: asDouble(json['commission']),
    net: asDouble(json['net']),
    status: PayoutStatus.parse(asString(json['status'])),
    createdAt: asDate(json['createdAt']),
  );

  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double gross;
  final double commission;
  final double net;
  final PayoutStatus status;
  final DateTime? createdAt;

  bool get isPaid => status == PayoutStatus.paid;

  String get periodLabel =>
      '${_day(periodStart)} – ${_day(periodEnd)}';

  static String _day(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}';
  }
}

/// Account-wide performance (`GET /partner/analytics`).
///
/// The endpoint is not venue-scoped — it covers every venue the account
/// operates — so the screen labels it as such instead of implying it followed
/// the venue switcher.
class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.totalRevenue,
    required this.totalBookings,
    required this.totalEvents,
    required this.avgPricePerSeat,
    required this.totalCovers,
    required this.upcomingEvents,
    required this.avgFillRate,
    this.recentBookings = const [],
  });

  factory AnalyticsSnapshot.fromJson(Map<String, dynamic> json) {
    final analytics = asMap(json['analytics']);
    final payload = analytics.isEmpty ? json : analytics;
    return AnalyticsSnapshot(
      totalRevenue: asDouble(payload['totalRevenue']),
      totalBookings: asInt(payload['totalBookings']),
      totalEvents: asInt(payload['totalEvents']),
      avgPricePerSeat: asDouble(payload['avgPricePerSeat']),
      totalCovers: asInt(payload['totalCovers']),
      upcomingEvents: asInt(payload['upcomingEvents']),
      avgFillRate: asDouble(payload['avgFillRate']),
      recentBookings: asMapList(json['recentBookings'])
          .map(RecentBooking.fromJson)
          .toList(growable: false),
    );
  }

  final double totalRevenue;
  final int totalBookings;
  final int totalEvents;
  final double avgPricePerSeat;
  final int totalCovers;
  final int upcomingEvents;

  /// `AVG(seats_booked / seats_total)` over past events, 0–1.
  final double avgFillRate;
  final List<RecentBooking> recentBookings;

  double get averageCoversPerEvent =>
      totalEvents <= 0 ? 0 : totalCovers / totalEvents;
}

class RecentBooking {
  const RecentBooking({
    required this.id,
    required this.eventTitle,
    required this.userName,
    required this.seats,
    required this.totalAmount,
    required this.status,
    this.createdAt,
  });

  factory RecentBooking.fromJson(Map<String, dynamic> json) => RecentBooking(
    id: asString(json['id']),
    eventTitle: asString(json['eventTitle']),
    userName: asString(json['userName']),
    seats: asInt(json['seats']),
    totalAmount: asDouble(json['totalAmount']),
    status: asString(json['status']),
    createdAt: asDate(json['createdAt']),
  );

  final String id;
  final String eventTitle;
  final String userName;
  final int seats;
  final double totalAmount;
  final String status;
  final DateTime? createdAt;
}
