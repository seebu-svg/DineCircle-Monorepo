import '../api/json.dart';

/// The two subscription plans offered to partners. Both carry the same Pro
/// feature set; only the billing period and price differ.
enum SubscriptionPlan {
  monthly('monthly', 5000, 'Monthly'),
  yearly('yearly', 50000, 'Yearly');

  const SubscriptionPlan(this.wire, this.pricePkr, this.label);

  final String wire;
  final int pricePkr;
  final String label;

  static SubscriptionPlan? parse(String? value) {
    for (final plan in SubscriptionPlan.values) {
      if (plan.wire == value) return plan;
    }
    return null;
  }
}

/// The lifecycle statuses a subscription row can hold.
enum SubscriptionStatus {
  none('none', 'Not subscribed'),
  trialing('trialing', 'Trial'),
  active('active', 'Active'),
  pastDue('past_due', 'Past due'),
  cancelled('cancelled', 'Cancelled');

  const SubscriptionStatus(this.wire, this.label);

  final String wire;
  final String label;

  static SubscriptionStatus parse(String? value) {
    for (final s in SubscriptionStatus.values) {
      if (s.wire == value) return s;
    }
    return none;
  }
}

/// The server truth for one venue's subscription.
class VenueSubscription {
  const VenueSubscription({
    required this.plan,
    required this.status,
    required this.pricePkr,
    this.periodStart,
    this.periodEnd,
    this.autoRenew = false,
    this.cancelledAt,
  });

  final SubscriptionPlan? plan;
  final SubscriptionStatus status;
  final int pricePkr;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool autoRenew;
  final DateTime? cancelledAt;

  /// Whether the venue has an active paid plan.
  bool get isActive => status == SubscriptionStatus.active && plan != null;

  /// The saving of yearly over monthly, in PKR.
  static const int yearlySavingPkr = 10000;

  /// The features both plans unlock — identical across tiers.
  static const List<String> proFeatures = [
    'Unlimited menu sections and items',
    'Unlimited deals and promotions',
    'Reservation management with calendar',
    'Insights dashboard with trend charts',
    'QR code for guest-facing menu',
    'Host experience approvals',
    'Priority partner support',
  ];

  factory VenueSubscription.fromJson(Map<String, dynamic> json) {
    return VenueSubscription(
      plan: SubscriptionPlan.parse(asString(json['plan'])),
      status: SubscriptionStatus.parse(asString(json['status'])),
      pricePkr: asInt(json['pricePkr'], fallback: 0),
      periodStart: asDate(json['periodStart']),
      periodEnd: asDate(json['periodEnd']),
      autoRenew: asBool(json['autoRenew'], fallback: false),
      cancelledAt: asDate(json['cancelledAt']),
    );
  }
}
