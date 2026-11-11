import '../api/json.dart';
import '../utils/money.dart';

/// PKR, written the way the rest of the app writes money (`Rs. 1,250`).
///
/// Deals are the one surface where a bare number reads as a bug: "750.00 off"
/// is not an amount a Karachi venue would recognise, and the Customer App has
/// always shown the same value with the rupee symbol.
String dealMoney(double value) => formatMoney(value, currency: 'PKR', decimals: 0);

/// The largest page the deals list asks for, and the server's own ceiling
/// (`MAX_LIMIT` in `server/src/api.ts`, which clamps anything above it).
///
/// The list reads every status in one page so the figures above it and the
/// filter chips describe the same rows; asking for more than this would be
/// quietly cut back, so the screen says out loud when it has been.
const int kDealPageLimit = 200;

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
    this.terms = '',
    this.imageUrl = '',
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
    terms: asString(json['terms']),
    imageUrl: asString(json['imageUrl']),
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

  /// Conditions and redemption steps, shown to the guest under "Conditions".
  /// Days and time windows live here because that is the only validity text
  /// the public route and the Customer App already carry.
  final String terms;

  /// Per-deal banner. Empty means the guest sees the venue cover image, which
  /// the public route substitutes, so an empty value is not a broken card.
  final String imageUrl;
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

  /// Within a week of ending, while it can still be honoured.
  ///
  /// The KPI strip counts these so a partner renewing or retiring an offer does
  /// not have to read every card to find the one expiring tomorrow.
  bool get isExpiringSoon {
    final now = DateTime.now();
    return isLive && !endsAt.isAfter(now.add(const Duration(days: 7)));
  }

  /// Uses left before the cap, or null when the deal is uncapped.
  int? get redemptionsLeft {
    final cap = maxRedemptions;
    if (cap == null) return null;
    final left = cap - redemptions;
    return left < 0 ? 0 : left;
  }

  bool get isLimitReached => redemptionsLeft != null && redemptionsLeft == 0;

  /// Whether the floor may count one more use right now.
  ///
  /// Mirrors the WHERE clause on the redeem route so the button and the server
  /// refuse for the same reason; the server stays the authority.
  bool get isRedeemable {
    final now = DateTime.now();
    return status == DealStatus.active &&
        !startsAt.isAfter(now) &&
        endsAt.isAfter(now) &&
        !isLimitReached;
  }

  /// Share of the cap already used, for the progress meter. Null when uncapped
  /// or when the counter never arrived, so the card shows no meter rather than
  /// a fabricated 0%.
  double? get redemptionProgress {
    final cap = maxRedemptions;
    if (cap == null || cap <= 0 || !redemptionsReported) return null;
    final ratio = redemptions / cap;
    return ratio.clamp(0.0, 1.0);
  }

  /// Drafts vanish; anything that has been live is retired instead.
  String get deleteBehaviourLabel =>
      isDeleteable ? 'Delete draft' : 'Retire (mark expired)';

  /// Headline on the card: what the guest actually saves.
  ///
  /// A package deal has no discount to state — its value is the price — so it
  /// reads as the price alone rather than the misleading "Rs. 2,999 off".
  String get valueLabel {
    switch (kind) {
      case DealKind.percent:
        final whole = value % 1 == 0;
        return '${value.toStringAsFixed(whole ? 0 : 1)}% off';
      case DealKind.fixed:
        return '${dealMoney(value)} off';
      case DealKind.package:
        return dealMoney(value);
    }
  }

  /// Secondary line naming the mechanic behind [valueLabel].
  String get mechanicLabel => switch (kind) {
    DealKind.percent => 'Percentage discount',
    DealKind.fixed => 'Fixed amount off',
    DealKind.package => 'Set package price',
  };

  String get redemptionLabel {
    if (!redemptionsReported) return 'Redemptions unavailable';
    final cap = maxRedemptions;
    if (cap == null) return '$redemptions used · no cap';
    return '$redemptions / $cap used';
  }

  /// Pre-fills the duplicate form from an existing deal.
  ///
  /// The copy drops the promo code: the server refuses a second live deal with
  /// the same code, and a partner duplicating an offer intends to rename it, not
  /// to be blocked on save. `endsAt` keeps the original window so the copy can
  /// be published immediately; a duplicate landing in the past could not.
  DealDraftInput copyToDraft() {
    final now = DateTime.now();
    final endsAt = this.endsAt.isAfter(now)
        ? this.endsAt
        : now.add(const Duration(days: 14));
    return DealDraftInput(
      // 120 is the server's ceiling on title length, and " (copy)" on an
      // already-long name would otherwise fail the save the tap is meant to
      // make easy.
      title: _clampedCopyTitle(title),
      kind: kind,
      value: value,
      startsAt: startsAt.isBefore(now) ? now : startsAt,
      endsAt: endsAt,
      description: description,
      terms: terms,
      imageUrl: imageUrl,
      maxRedemptions: maxRedemptions,
    );
  }
}

/// Appends " (copy" without letting the result pass the server's 120 limit.
String _clampedCopyTitle(String title) {
  const suffix = ' (copy)';
  if (title.length + suffix.length <= 120) return '$title$suffix';
  return title.substring(0, 120 - suffix.length) + suffix;
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
    this.terms = '',
    this.imageUrl = '',
  });

  final String title;
  final DealKind kind;
  final double value;
  final DateTime startsAt;
  final DateTime endsAt;
  final String description;
  final String code;
  final int? maxRedemptions;
  final String terms;
  final String imageUrl;

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
    'terms': terms.trim(),
    'imageUrl': imageUrl.trim(),
  };
}
