import '../api/json.dart';

/// Experience lifecycle (`dinner_events.status`).
///
/// The venue sees the same enum the customer app does; `requested` is the
/// host-approval hold and is deliberately invisible to diners, which is why it
/// renders as "Awaiting your approval" here rather than "Scheduled".
enum ExperienceStatus {
  draft('draft', 'Draft'),
  requested('requested', 'Awaiting approval'),
  confirmed('confirmed', 'Confirmed'),
  live('live', 'Live now'),
  completed('completed', 'Completed'),
  declined('declined', 'Declined'),
  cancelled('cancelled', 'Cancelled');

  const ExperienceStatus(this.wire, this.label);

  final String wire;
  final String label;

  static ExperienceStatus parse(String? value) =>
      ExperienceStatus.values.firstWhere(
        (status) => status.wire == value,
        orElse: () => ExperienceStatus.draft,
      );

  /// Bookable by guests: published and in the future.
  bool get isSellable =>
      this == confirmed || this == live;

  bool get isUpcoming =>
      this == confirmed || this == requested || this == live;
}

/// Event formats offered by `createPartnerEventSchema`.
enum ExperienceType {
  dinner('dinner', 'Dinner'),
  tasting('tasting', 'Tasting'),
  supperClub('supperClub', 'Supper club'),
  brunch('brunch', 'Brunch'),
  workshop('workshop', 'Workshop'),
  festival('festival', 'Festival');

  const ExperienceType(this.wire, this.label);

  final String wire;
  final String label;

  static ExperienceType parse(String? value) => ExperienceType.values.firstWhere(
    (type) => type.wire == value,
    orElse: () => ExperienceType.dinner,
  );

  static List<String> get wires =>
      ExperienceType.values.map((t) => t.wire).toList(growable: false);
}

/// Audience gate for an experience.
enum ExperienceAudience {
  public('public', 'Public'),
  followers('followers', 'Followers only'),
  friends('friends', 'Friends only'),
  inviteOnly('inviteOnly', 'Invite only');

  const ExperienceAudience(this.wire, this.label);

  final String wire;
  final String label;

  static ExperienceAudience parse(String? value) =>
      ExperienceAudience.values.firstWhere(
        (audience) => audience.wire == value,
        orElse: () => ExperienceAudience.public,
      );

  static List<String> get wires =>
      ExperienceAudience.values.map((a) => a.wire).toList(growable: false);
}

/// How the table is served.
enum MenuStyle {
  setMenu('setMenu', 'Set menu'),
  tastingMenu('tastingMenu', 'Tasting menu'),
  familyStyle('familyStyle', 'Family style'),
  sharing('sharing', 'Sharing'),
  buffet('buffet', 'Buffet');

  const MenuStyle(this.wire, this.label);

  final String wire;
  final String label;

  static MenuStyle parse(String? value) => MenuStyle.values.firstWhere(
    (style) => style.wire == value,
    orElse: () => MenuStyle.setMenu,
  );

  static List<String> get wires =>
      MenuStyle.values.map((m) => m.wire).toList(growable: false);
}

/// An experience the venue operates (`GET /partner/events`).
///
/// The list payload is the only read surface for venue-owned events, there is
/// no single-event GET, so the detail screen works from this row and the
/// partial `PUT` writes only what the operator changed.
class PartnerExperience {
  const PartnerExperience({
    required this.id,
    required this.title,
    required this.restaurantName,
    required this.startAt,
    required this.seatsTotal,
    required this.seatsBooked,
    this.seatsLeft = 0,
    required this.pricePerSeat,
    required this.status,
    required this.type,
    this.restaurantId = '',
  });

  factory PartnerExperience.fromJson(Map<String, dynamic> json) =>
      PartnerExperience(
        id: asString(json['id']),
        title: asString(json['title']),
        restaurantName: asString(json['restaurantName']),
        restaurantId: asString(json['restaurantId']),
        startAt: asDateOr(json['startAt'], DateTime.now()),
        seatsTotal: asInt(json['seatsTotal']),
        seatsBooked: asInt(json['seatsBooked']),
        seatsLeft: asIntOrNull(json['seatsLeft']) ?? 0,
        pricePerSeat: asDouble(json['pricePerSeat']),
        status: ExperienceStatus.parse(asString(json['status'])),
        type: ExperienceType.parse(asString(json['type'])),
      );

  final String id;
  final String title;
  final String restaurantName;
  final String restaurantId;
  final DateTime startAt;
  final int seatsTotal;
  final int seatsBooked;
  final int seatsLeft;
  final double pricePerSeat;
  final ExperienceStatus status;
  final ExperienceType type;

  int get seatsRemaining =>
      seatsLeft > 0 ? seatsLeft : _positive(seatsTotal - seatsBooked);

  double get fillRate => seatsTotal <= 0 ? 0 : seatsBooked / seatsTotal;

  bool get isPast => startAt.isBefore(DateTime.now());

  String get grossLabel => (seatsBooked * pricePerSeat).toStringAsFixed(2);

  PartnerExperience copyWith({
    String? title,
    DateTime? startAt,
    int? seatsTotal,
    double? pricePerSeat,
    ExperienceStatus? status,
    ExperienceType? type,
    int? seatsLeft,
  }) => PartnerExperience(
    id: id,
    title: title ?? this.title,
    restaurantName: restaurantName,
    restaurantId: restaurantId,
    startAt: startAt ?? this.startAt,
    seatsTotal: seatsTotal ?? this.seatsTotal,
    seatsBooked: seatsBooked,
    seatsLeft: seatsLeft ?? this.seatsLeft,
    pricePerSeat: pricePerSeat ?? this.pricePerSeat,
    status: status ?? this.status,
    type: type ?? this.type,
  );
}

/// A host's proposal awaiting this venue's decision
/// (`GET …/event-requests`).
class ExperienceRequest {
  const ExperienceRequest({
    required this.id,
    required this.title,
    required this.hostId,
    required this.hostName,
    required this.startAt,
    required this.seatsTotal,
    required this.seatsBooked,
    required this.seatsLeft,
    required this.pricePerSeat,
    required this.status,
    required this.type,
    this.tagline = '',
    this.description = '',
    this.coverImage = '',
    this.declineReason = '',
    this.approvedAt,
    this.createdAt,
  });

  factory ExperienceRequest.fromJson(Map<String, dynamic> json) =>
      ExperienceRequest(
        id: asString(json['id']),
        title: asString(json['title']),
        tagline: asString(json['tagline']),
        description: asString(json['description']),
        hostId: asString(json['hostId']),
        hostName: asString(json['hostName']),
        startAt: asDateOr(json['startAt'], DateTime.now()),
        seatsTotal: asInt(json['seatsTotal']),
        seatsBooked: asInt(json['seatsBooked']),
        seatsLeft: asInt(json['seatsLeft']),
        pricePerSeat: asDouble(json['pricePerSeat']),
        type: ExperienceType.parse(asString(json['type'])),
        status: ExperienceStatus.parse(asString(json['status'])),
        coverImage: asString(json['coverImage']),
        declineReason: asString(json['declineReason']),
        approvedAt: asDate(json['approvedAt']),
        createdAt: asDate(json['createdAt']),
      );

  final String id;
  final String title;
  final String tagline;
  final String description;
  final String hostId;
  final String hostName;
  final DateTime startAt;
  final int seatsTotal;
  final int seatsBooked;
  final int seatsLeft;
  final double pricePerSeat;
  final ExperienceType type;
  final ExperienceStatus status;
  final String coverImage;
  final String declineReason;
  final DateTime? approvedAt;
  final DateTime? createdAt;

  bool get isAwaitingDecision => status == ExperienceStatus.requested;

  String get capacityLabel => '$seatsBooked / $seatsTotal seats booked';

  String get priceLabel =>
      '${pricePerSeat.toStringAsFixed(2)} per seat · '
      '$seatsLeft left';
}

int _positive(int value) => value < 0 ? 0 : value;
