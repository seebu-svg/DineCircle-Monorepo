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

/// The serving style in desk words.
///
/// A function rather than `MenuStyle.parse(wire).label` at the call site,
/// because `flutter/material.dart` exports its own `MenuStyle` and every screen
/// that shows this field imports Material too.
String menuStyleLabel(String? wire) => MenuStyle.parse(wire).label;

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
    this.hostId = '',
    this.tagline = '',
    this.coverImage = '',
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
        hostId: asString(json['hostId']),
        tagline: asString(json['tagline']),
        coverImage: asString(json['coverImage']),
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
  final String hostId;

  /// One line the guest reads first. Sent on create/edit; the list read began
  /// returning it alongside the cover so a card can label itself.
  final String tagline;

  /// Stored media value (`/public/venue-images/<id>`, an absolute URL, or a
  /// bundled asset path). Empty means the card falls back to its format art.
  final String coverImage;

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
    String? tagline,
    String? coverImage,
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
    hostId: hostId,
    tagline: tagline ?? this.tagline,
    coverImage: coverImage ?? this.coverImage,
  );
}

/// One course on the menu the venue is being asked to approve.
///
/// The approval list never carried the menu, so a venue approved an experience
/// having seen a title, a date and a price. The detail endpoint returns the
/// same rows the diner sees, in running order.
class RequestCourse {
  const RequestCourse({
    required this.id,
    required this.name,
    this.position = 0,
    this.description = '',
    this.pairing = '',
    this.isSignature = false,
  });

  factory RequestCourse.fromJson(Map<String, dynamic> json) => RequestCourse(
    id: asString(json['id']),
    name: asString(json['name']),
    position: asInt(json['position']),
    description: asString(json['description']),
    pairing: asString(json['pairing']),
    isSignature: asBool(json['isSignature']),
  );

  final String id;
  final String name;
  final int position;
  final String description;
  final String pairing;
  final bool isSignature;
}

/// A host's proposal awaiting this venue's decision
/// (`GET …/event-requests`).
///
/// The list payload answers the coarse rows; the detail endpoint
/// (`GET …/event-requests/:eventId`) fills in the menu, gallery, audience,
/// inclusions and the host's note, which is what the decision sheet renders.
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
    this.audience = '',
    this.menuStyle = '',
    this.endAt,
    this.hostNote = '',
    this.dressCode = '',
    this.language = '',
    this.durationMinutes = 0,
    this.requiresApproval = false,
    this.isReapproval = false,
    this.cancellationReason = '',
    this.gallery = const [],
    this.included = const [],
    this.tags = const [],
    this.menu = const [],
    this.approvalStaleAt,
    this.cancelledAt,
    this.host = const ProposalHostRef(),
  });

  factory ExperienceRequest.fromJson(Map<String, dynamic> json) =>
      ExperienceRequest(
        id: asString(json['id']),
        title: asString(json['title']),
        tagline: asString(json['tagline']),
        description: asString(json['description']),
        hostId: asString(json['hostId']),
        hostName: asString(json['hostName']),
        host: ProposalHostRef.fromJson(json['host']),
        startAt: asDateOr(json['startAt'], DateTime.now()),
        endAt: asDate(json['endAt']),
        seatsTotal: asInt(json['seatsTotal']),
        seatsBooked: asInt(json['seatsBooked']),
        seatsLeft: asInt(json['seatsLeft']),
        pricePerSeat: asDouble(json['pricePerSeat']),
        type: ExperienceType.parse(asString(json['type'])),
        status: ExperienceStatus.parse(asString(json['status'])),
        coverImage: asString(json['coverImage']),
        gallery: asStringList(json['gallery']),
        audience: asString(json['audience']),
        menuStyle: asString(json['menuStyle']),
        included: asStringList(json['included']),
        tags: asStringList(json['tags']),
        hostNote: asString(json['hostNote']),
        dressCode: asString(json['dressCode']),
        language: asString(json['language']),
        durationMinutes: asInt(json['durationMinutes']),
        menu: asMapList(json['menu'])
            .map(RequestCourse.fromJson)
            .toList(growable: false),
        declineReason: asString(json['declineReason']),
        approvedAt: asDate(json['approvedAt']),
        approvalStaleAt: asDate(json['approvalStaleAt']),
        requiresApproval: asBool(json['requiresApproval']),
        isReapproval: asBool(json['isReapproval']),
        cancelledAt: asDate(json['cancelledAt']),
        cancellationReason: asString(json['cancellationReason']),
        createdAt: asDate(json['createdAt']),
      );

  final String id;
  final String title;
  final String tagline;
  final String description;
  final String hostId;
  final String hostName;
  final ProposalHostRef host;
  final DateTime startAt;
  final DateTime? endAt;
  final int seatsTotal;
  final int seatsBooked;
  final int seatsLeft;
  final double pricePerSeat;
  final ExperienceType type;
  final ExperienceStatus status;
  final String coverImage;
  final List<String> gallery;
  final String audience;
  final String menuStyle;
  final List<String> included;
  final List<String> tags;
  final String hostNote;
  final String dressCode;
  final String language;
  final int durationMinutes;
  final List<RequestCourse> menu;
  final String declineReason;
  final DateTime? approvedAt;
  final DateTime? approvalStaleAt;
  final bool requiresApproval;
  final bool isReapproval;
  final DateTime? cancelledAt;
  final String cancellationReason;
  final DateTime? createdAt;

  bool get isAwaitingDecision => status == ExperienceStatus.requested;

  /// The host changed the experience after this venue approved it, so the row
  /// is back in the queue. `isReapproval` is computed server-side from the two
  /// stamps; the comparison is kept here as a fallback for an older payload
  /// that ships the timestamps without the flag.
  bool get changedSinceApproval =>
      isReapproval ||
      (approvalStaleAt != null &&
          (approvedAt == null || approvalStaleAt!.isAfter(approvedAt!)));

  /// True once the detail read has run, so the sheet can tell "no menu" from
  /// "menu not loaded yet".
  bool get hasFullDetail =>
      menu.isNotEmpty ||
      gallery.isNotEmpty ||
      included.isNotEmpty ||
      hostNote.isNotEmpty;

  String get capacityLabel => '$seatsBooked / $seatsTotal seats booked';

  String get priceLabel =>
      '${pricePerSeat.toStringAsFixed(2)} per seat · '
      '$seatsLeft left';
}

/// The host's public identity as the request payload carries it.
class ProposalHostRef {
  const ProposalHostRef({
    this.id = '',
    this.name = '',
    this.handle = '',
    this.avatarUrl = '',
  });

  factory ProposalHostRef.fromJson(Object? value) {
    final json = asMap(value);
    return ProposalHostRef(
      id: asString(json['id']),
      name: asString(json['name']),
      handle: asString(json['handle']),
      avatarUrl: asString(json['avatarUrl']),
    );
  }

  final String id;
  final String name;
  final String handle;
  final String avatarUrl;

  String get initials {
    final source = name.trim().isEmpty ? '?' : name.trim();
    return source[0].toUpperCase();
  }
}

/// Receipt for a venue-driven lifecycle transition
/// (`POST /partner/events/:id/cancel|complete|reopen`).
///
/// These routes answer a partial row (`{ eventId, status }` or `{ event: ...}`),
/// not a re-serialised experience, so callers refetch the list instead of
/// splicing a fake object into it.
class ExperienceTransition {
  const ExperienceTransition({
    required this.eventId,
    required this.status,
  });

  factory ExperienceTransition.fromJson(Object? value) {
    final wrapper = asMap(value);
    final json = wrapper.containsKey('event')
        ? asMap(wrapper['event'])
        : wrapper;
    return ExperienceTransition(
      eventId: asString(json['id']).isNotEmpty
          ? asString(json['id'])
          : asString(json['eventId']),
      status: asString(json['status']),
    );
  }

  final String eventId;
  final String status;

  bool get isCancelled => status == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isReopened => status == 'confirmed';
}


int _positive(int value) => value < 0 ? 0 : value;
