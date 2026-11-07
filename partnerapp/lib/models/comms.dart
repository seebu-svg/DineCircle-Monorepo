import '../api/json.dart';

/// An inbox item for one of the account's venues
/// (`GET /partner/notifications`).
class PartnerNotification {
  const PartnerNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.read,
    required this.notificationTime,
    this.restaurantId = '',
    this.icon,
    this.tint,
  });

  factory PartnerNotification.fromJson(Map<String, dynamic> json) =>
      PartnerNotification(
        id: asString(json['id']),
        restaurantId: asString(json['restaurantId']),
        title: asString(json['title']),
        body: asString(json['body']),
        category: asString(json['category'], fallback: 'general'),
        read: asBool(json['read']),
        icon: asStringOrNull(json['icon']),
        tint: asStringOrNull(json['tint']),
        notificationTime:
            asDateOr(json['notificationTime'], DateTime.now()),
      );

  final String id;
  final String restaurantId;
  final String title;
  final String body;
  final String category;
  final bool read;
  final String? icon;
  final String? tint;
  final DateTime notificationTime;

  /// Categories the desk can jump straight from the inbox; anything else opens
  /// the notification on its own.
  String get deepLink => switch (category) {
    'reservation' || 'booking' => '/service/reservations',
    'event_request' || 'request' => '/experiences/requests',
    'deal' => '/business/deals',
    'payout' || 'earnings' => '/business/subscription',
    'review' => '/guests/reviews',
    _ => '/inbox/notifications',
  };
}

/// A guest review of a restaurant or experience.
///
/// When [restaurantId] is set the review is venue-scoped (the new primary
/// feed). Legacy event reviews still flow through [eventId].
class PartnerReview {
  const PartnerReview({
    required this.id,
    required this.rating,
    required this.text,
    required this.createdAt,
    this.eventId = '',
    this.eventTitle = '',
    this.restaurantId = '',
    this.authorId = '',
    this.authorName = 'Guest',
    this.authorHandle = '',
    this.authorAvatarUrl = '',
    this.partnerReply,
    this.partnerRepliedAt,
  });

  factory PartnerReview.fromJson(Map<String, dynamic> json) {
    final author = asMap(json['author']);
    return PartnerReview(
      id: asString(json['id']),
      eventId: asString(json['eventId']),
      eventTitle: asString(json['eventTitle']),
      restaurantId: asString(json['restaurantId']),
      rating: asInt(json['rating']),
      text: asString(json['text']),
      createdAt: asDateOr(json['createdAt'], DateTime.now()),
      authorId: asString(author['id'], fallback: asString(json['authorId'])),
      authorName: asString(author['name'], fallback: asString(json['authorName'], fallback: 'Guest')),
      authorHandle: asString(author['handle']),
      authorAvatarUrl: asString(author['avatarUrl']),
      partnerReply: asStringOrNull(json['partnerReply']),
      partnerRepliedAt: asDate(json['partnerRepliedAt']),
    );
  }

  final String id;
  final String eventId;
  final String eventTitle;
  final String restaurantId;
  final int rating;
  final String text;
  final DateTime createdAt;
  final String authorId;
  final String authorName;
  final String authorHandle;
  final String authorAvatarUrl;
  final String? partnerReply;
  final DateTime? partnerRepliedAt;

  bool get hasPartnerReply => partnerReply != null && partnerReply!.isNotEmpty;

  String get authorLabel {
    if (authorHandle.isEmpty) return authorName;
    return '$authorName \u00b7 @${authorHandle.replaceFirst('@', '')}';
  }
}

/// Public performance summary for an experience host
/// (`GET /hosts/:id/summary`).
///
/// The route asserts a host-relationship, so a venue that only supplied the
/// space receives `403`, the collaboration screen renders [HostProfile.name]
/// from the request row and states that the host's numbers are private.
class HostProfile {
  const HostProfile({
    required this.hostId,
    required this.name,
    this.earned = 0,
    this.inTransit = 0,
    this.scheduled = 0,
    this.lifetimeGross = 0,
    this.commissionTotal = 0,
    this.seatsSold = 0,
    this.hostedCount = 0,
    this.upcomingCount = 0,
    this.averageFillRate = 0,
    this.averageSeatPrice = 0,
    this.nextPayoutDate,
    this.avatarUrl = '',
    this.handle = '',
  });

  factory HostProfile.fromJson(
    Map<String, dynamic> json, {
    String name = '',
    String handle = '',
    String avatarUrl = '',
  }) => HostProfile(
    hostId: asString(json['hostId'], fallback: asString(json['id'])),
    name: name,
    handle: handle,
    avatarUrl: avatarUrl,
    earned: asDouble(json['earned']),
    inTransit: asDouble(json['inTransit']),
    scheduled: asDouble(json['scheduled']),
    lifetimeGross: asDouble(json['lifetimeGross']),
    commissionTotal: asDouble(json['commissionTotal']),
    seatsSold: asInt(json['seatsSold']),
    hostedCount: asInt(json['hostedCount']),
    upcomingCount: asInt(json['upcomingCount']),
    averageFillRate: asDouble(json['averageFillRate']),
    averageSeatPrice: asDouble(json['averageSeatPrice']),
    nextPayoutDate: asDate(json['nextPayoutDate']),
  );

  final String hostId;
  final String name;
  final String handle;
  final String avatarUrl;
  final double earned;
  final double inTransit;
  final double scheduled;
  final double lifetimeGross;
  final double commissionTotal;
  final int seatsSold;
  final int hostedCount;
  final int upcomingCount;
  final double averageFillRate;
  final double averageSeatPrice;
  final DateTime? nextPayoutDate;

  int get experienceCount => hostedCount;
}

/// One message in an experience thread (`GET|POST /events/:id/messages`).
class EventMessage {
  const EventMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.isSystem,
    this.authorId = '',
    this.authorName = '',
    this.isMine = false,
  });

  factory EventMessage.fromJson(
    Map<String, dynamic> json, {
    String currentUserId = '',
  }) {
    final author = asMap(json['author']);
    final authorId = asString(json['authorId']);
    return EventMessage(
      id: asString(json['id']),
      text: asString(json['text']),
      sentAt: asDateOr(json['sentAt'], DateTime.now()),
      isSystem: asBool(json['isSystem']),
      authorId: authorId,
      authorName: asString(author['name']),
      isMine:
          currentUserId.isNotEmpty && authorId == currentUserId,
    );
  }

  final String id;
  final String text;
  final DateTime sentAt;
  final bool isSystem;
  final String authorId;
  final String authorName;
  final bool isMine;
}

/// Support ticket lifecycle (`feedback.status`).
enum TicketStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In progress'),
  resolved('resolved', 'Resolved'),
  closed('closed', 'Closed');

  const TicketStatus(this.wire, this.label);

  final String wire;
  final String label;

  static TicketStatus parse(String? value) => TicketStatus.values.firstWhere(
    (status) => status.wire == value,
    orElse: () => TicketStatus.open,
  );

  bool get isClosed => this == resolved || this == closed;
}

/// Categories accepted by `POST /feedback`.
enum TicketCategory {
  bug('bug', 'Bug or outage'),
  feature('feature', 'Feature request'),
  booking('booking', 'Booking problem'),
  payment('payment', 'Payment or payout'),
  restaurantExperience('restaurant_experience', 'Experience problem'),
  general('general', 'Something else');

  const TicketCategory(this.wire, this.label);

  final String wire;
  final String label;

  static List<String> get wires =>
      TicketCategory.values.map((c) => c.wire).toList(growable: false);
}

/// A ticket raised from the app (`GET /users/me/feedback`).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    required this.ticket,
    this.relatedRef = '',
    this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: asString(json['id']),
    category: asString(json['category']),
    subject: asString(json['subject']),
    description: asString(json['description']),
    relatedRef: asString(json['relatedRef']),
    status: TicketStatus.parse(asString(json['status'])),
    ticket: asString(json['ticket']),
    createdAt: asDate(json['createdAt']),
    updatedAt: asDate(json['updatedAt']),
  );

  final String id;
  final String category;
  final String subject;
  final String description;
  final String relatedRef;
  final TicketStatus status;

  /// The reference support quotes (`FB-XXXXXX`).
  final String ticket;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get statusLabel => status.label;
}

/// A moderation case raised against a guest (`POST /reports`).
class ReportCase {
  const ReportCase({
    required this.id,
    required this.targetType,
    required this.reason,
    required this.status,
    required this.reference,
    this.description = '',
    this.createdAt,
  });

  factory ReportCase.fromJson(Map<String, dynamic> json) => ReportCase(
    id: asString(json['id']),
    targetType: asString(json['targetType']),
    reason: asString(json['reason']),
    description: asString(json['description']),
    status: asString(json['status'], fallback: 'pending'),
    reference: asString(json['reference']),
    createdAt: asDate(json['createdAt']),
  );

  final String id;
  final String targetType;
  final String reason;
  final String description;
  final String status;
  final String reference;
  final DateTime? createdAt;

  bool get isPending => status == 'pending' || status == 'reviewing';

  String get statusLabel => switch (status) {
    'pending' => 'Awaiting review',
    'reviewing' => 'Under review',
    'resolved' => 'Resolved',
    'dismissed' => 'No action taken',
    _ => status,
  };
}
