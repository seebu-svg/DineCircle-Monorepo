import '../api/json.dart';

/// Promotion lifecycle (`restaurant_deals.status`).
enum DealStatus {
  draft('draft', 'Draft'),
  active('active', 'Active'),
  paused('paused', 'Paused'),
  expired('expired', 'Expired');

  const DealStatus(this.wire, this.label);

  final String wire;
  final String label;

  static DealStatus parse(String? value) => DealStatus.values.firstWhere(
    (status) => status.wire == value,
    orElse: () => DealStatus.draft,
  );
}

/// The legal status transitions, mirroring `DEAL_TRANSITIONS` in
/// `server/src/routes/partner_ops.ts`.
///
/// Driving the buttons from this table means the desk never taps a move the
/// server would answer with `409`. `expired` is terminal, and a deal is retired
/// rather than deleted so a guest holding the code gets a clear answer.
const Map<DealStatus, List<DealStatus>> kDealTransitions = {
  DealStatus.draft: [DealStatus.active, DealStatus.expired],
  DealStatus.active: [DealStatus.paused, DealStatus.expired],
  DealStatus.paused: [DealStatus.active, DealStatus.expired],
  DealStatus.expired: [],
};

/// Discount mechanics offered by `dealBaseSchema.kind`.
enum DealKind {
  percent('percent', 'Percentage off'),
  fixed('fixed', 'Fixed amount off'),
  package('package', 'Package price');

  const DealKind(this.wire, this.label);

  final String wire;
  final String label;

  static DealKind parse(String? value) => DealKind.values.firstWhere(
    (kind) => kind.wire == value,
    orElse: () => DealKind.percent,
  );

  static List<String> get wires =>
      DealKind.values.map((k) => k.wire).toList(growable: false);

  /// Percent deals are capped at 100 server-side; the others are money.
  bool get isPercent => this == percent;
}

/// A venue promotion (`…/deals`).
class Deal {
  const Deal({
    required this.id,
    required this.restaurantId,
    required this.title,
    required this.kind,
    required this.value,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.description = '',
    this.code,
    this.maxRedemptions,
    this.redemptions = 0,
    this.redemptionsReported = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Deal.fromJson(Map<String, dynamic> json) => Deal(
    id: asString(json['id']),
    restaurantId: asString(json['restaurantId']),
    title: asString(json['title']),
    description: asString(json['description']),
    kind: DealKind.parse(asString(json['kind'])),
    value: asDouble(json['value']),
    code: asStringOrNull(json['code']),
    startsAt: asDateOr(json['startsAt'], DateTime.now()),
    endsAt: asDateOr(json['endsAt'], DateTime.now()),
    maxRedemptions: asIntOrNull(json['maxRedemptions']),
    redemptions: asInt(json['redemptions']),
    redemptionsReported: json['redemptions'] is num,
    status: DealStatus.parse(asString(json['status'])),
    createdAt: asDate(json['createdAt']),
    updatedAt: asDate(json['updatedAt']),
  );

  final String id;
  final String restaurantId;
  final String title;
  final String description;
  final DealKind kind;
  final double value;
  final String? code;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Null means unlimited uses. The platform counts redemptions but exposes no
  /// counter endpoint, so this is display-only.
  final int? maxRedemptions;
  final int redemptions;

  /// Missing counters must not appear as measured zero redemptions.
  final bool redemptionsReported;
  final DealStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  List<DealStatus> get allowedTransitions =>
      kDealTransitions[status] ?? const [];

  bool get isLive {
    final now = DateTime.now();
    return status == DealStatus.active &&
        !startsAt.isAfter(now) &&
        endsAt.isAfter(now);
  }

  bool get isDraft => status == DealStatus.draft;
  bool get isScheduled =>
      status == DealStatus.active && startsAt.isAfter(DateTime.now());
  bool get hasPassed => !endsAt.isAfter(DateTime.now());
  bool get isDeleteable => status == DealStatus.draft;

  /// Drafts vanish; anything that has been live is retired instead.
  String get deleteBehaviourLabel =>
      isDeleteable ? 'Delete draft' : 'Retire (mark expired)';

  String get valueLabel {
    if (kind.isPercent) return '${value.toStringAsFixed(0)}% off';
    return '${value.toStringAsFixed(2)} off';
  }

  String get redemptionLabel {
    if (!redemptionsReported) return 'Redemptions unavailable';
    final cap = maxRedemptions;
    if (cap == null) return '$redemptions used · no cap';
    return '$redemptions / $cap used';
  }
}

/// Fields the create form collects, kept separate from [Deal] so the screen can
/// validate before anything reaches the server.
class DealDraftInput {
  const DealDraftInput({
    required this.title,
    required this.kind,
    required this.value,
    required this.startsAt,
    required this.endsAt,
    this.description = '',
    this.code = '',
    this.maxRedemptions,
  });

  final String title;
  final DealKind kind;
  final double value;
  final DateTime startsAt;
  final DateTime endsAt;
  final String description;
  final String code;
  final int? maxRedemptions;

  /// Body for `POST …/deals`. An empty code is omitted rather than sent, so the
  /// server generates none and no uniqueness clash is possible.
  Map<String, dynamic> toBody() => {
    'title': title.trim(),
    'description': description.trim(),
    'kind': kind.wire,
    'value': value,
    if (code.trim().isNotEmpty) 'code': code.trim().toUpperCase(),
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    if (maxRedemptions != null) 'maxRedemptions': maxRedemptions,
  };
}
