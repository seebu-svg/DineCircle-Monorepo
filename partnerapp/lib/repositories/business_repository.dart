import '../api/api_client.dart';
import '../api/json.dart';
import '../models/comms.dart';
import '../models/deals.dart';
import '../models/finance.dart';

/// Filters for the deal list.
class DealQuery {
  const DealQuery({this.status, this.page, this.limit});

  final String? status;
  final int? page;
  final int? limit;

  Map<String, dynamic> toQuery() => {
    'status': ?status,
    'page': ?page,
    'limit': ?limit,
  };
}

/// Deals, money, inbox, guest feedback and support.
///
/// Groups the four surfaces that are read-mostly and share one thing: they are
/// all scoped to the account or venue but never written by the desk except
/// through an explicit action.
class BusinessRepository {
  BusinessRepository(this._api);

  final ApiClient _api;

  static String base(String venueId) => '/partner/restaurants/$venueId';

  // ── Deals ──────────────────────────────────────────────────────────────────

  Future<List<Deal>> deals(String venueId, [DealQuery query = const DealQuery()]) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/deals',
      query: query.toQuery(),
    );
    return envelope.list('deals', Deal.fromJson);
  }

  /// `403` when the venue is not verified, the create button is disabled for
  /// that reason, and this message is what the screen shows if it is bypassed.
  Future<Deal> createDeal(String venueId, DealDraftInput input) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/deals',
      body: input.toBody(),
    );
    final deal = envelope.single('deal', Deal.fromJson);
    if (deal == null) throw StateError('Deal payload missing');
    return deal;
  }

  Future<Deal> updateDeal(
    String venueId,
    String dealId, {
    String? title,
    String? description,
    double? value,
    String? code,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxRedemptions,
    DealStatus? status,
  }) async {
    final envelope = await _api.envelopePatch(
      '${base(venueId)}/deals/$dealId',
      body: {
        if (title != null) 'title': title.trim(),
        if (description != null) 'description': description.trim(),
        'value': ?value,
        if (code != null) 'code': code.trim().toUpperCase(),
        if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
        if (endsAt != null) 'endsAt': endsAt.toUtc().toIso8601String(),
        'maxRedemptions': ?maxRedemptions,
        if (status != null) 'status': status.wire,
      },
    );
    final deal = envelope.single('deal', Deal.fromJson);
    if (deal == null) throw StateError('Deal payload missing');
    return deal;
  }

  /// Drafts are deleted; anything that has been live is retired to `expired`.
  /// The answer distinguishes the two so the list can say what happened.
  Future<bool> deleteDeal(String venueId, String dealId) async {
    final raw = await _api.deleteJson('${base(venueId)}/deals/$dealId');
    return asBool(asMap(raw)['deleted']);
  }

  // ── Earnings & payouts ─────────────────────────────────────────────────────

  Future<EarningsReport> earnings(
    String venueId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/earnings',
      query: {
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      },
    );
    return EarningsReport.fromJson(envelope.data);
  }

  Future<List<PayoutRecord>> payouts(
    String venueId, {
    int page = 1,
    int limit = 24,
  }) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/payouts',
      query: {'page': page, 'limit': limit},
    );
    return envelope.list('payouts', PayoutRecord.fromJson);
  }

  /// Account-wide, not venue-scoped on the server.
  Future<AnalyticsSnapshot> analytics() async {
    final envelope = await _api.envelopeGet('/partner/analytics');
    return AnalyticsSnapshot.fromJson(envelope.data);
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<NotificationPage> notifications({bool unreadOnly = false}) async {
    final envelope = await _api.envelopeGet(
      '/partner/notifications',
      query: {'unreadOnly': unreadOnly ? 'true' : 'false'},
    );
    return NotificationPage(
      items: envelope.list('notifications', PartnerNotification.fromJson),
      unread: envelope.meta.unread,
    );
  }

  Future<void> markNotificationRead(String notificationId) =>
      _api.postJson('/partner/notifications/$notificationId/read');

  /// Returns how many rows the server actually flipped.
  Future<int> markAllNotificationsRead() async {
    final envelope = await _api.envelopePost('/partner/notifications/read-all');
    return asInt(envelope.raw('updated'));
  }

  // ── Guest feedback ─────────────────────────────────────────────────────────

  /// Reviews for one experience. `/reviews` is the platform's public read route
  /// and is not enveloped; the envelope parser passes that shape through, which
  /// is why the key here is just `reviews`.
  Future<List<PartnerReview>> reviewsForEvent(String eventId) async {
    final envelope = await _api.envelopeGet(
      '/reviews',
      query: {'eventId': eventId, 'limit': 100},
    );
    return envelope.list('reviews', PartnerReview.fromJson);
  }

  /// Venue-scoped review feed with aggregate rating.
  /// `GET /partner/restaurants/:id/reviews`
  Future<List<PartnerReview>> reviewsForVenue(String restaurantId) async {
    final raw = await _api.getJson(
      '/partner/restaurants/$restaurantId/reviews',
      query: {'limit': 100},
    );
    final map = asMap(raw);
    return asMapList(map['reviews']).map(PartnerReview.fromJson).toList();
  }

  /// Partner replies to a customer review.
  /// `PATCH /partner/restaurants/:restaurantId/reviews/:reviewId/reply`
  Future<void> replyToReview({
    required String restaurantId,
    required String reviewId,
    required String reply,
  }) async {
    await _api.patchJson(
      '/partner/restaurants/$restaurantId/reviews/$reviewId/reply',
      body: {'reply': reply},
    );
  }

  // ── Support & disputes ─────────────────────────────────────────────────────

  Future<SupportTicket> createTicket({
    required TicketCategory category,
    required String subject,
    required String description,
    String relatedRef = '',
  }) async {
    final envelope = await _api.envelopePost(
      '/feedback',
      body: {
        'category': category.wire,
        'subject': subject.trim(),
        'description': description.trim(),
        'relatedRef': relatedRef.trim(),
      },
    );
    return SupportTicket.fromJson(
      envelope.resourceMap('feedback') ?? envelope.data,
    );
  }

  Future<List<SupportTicket>> tickets() async {
    final envelope = await _api.envelopeGet('/users/me/feedback');
    return envelope.list('feedback', SupportTicket.fromJson);
  }

  Future<ReportCase> reportGuest({
    required String userId,
    required String reason,
    String description = '',
  }) async {
    final envelope = await _api.envelopePost(
      '/reports',
      body: {
        'targetType': 'user',
        'targetId': userId,
        'reason': reason,
        'description': description.trim(),
      },
    );
    return ReportCase.fromJson(
      envelope.resourceMap('report') ?? envelope.data,
    );
  }

  Future<List<ReportCase>> reports() async {
    final envelope = await _api.envelopeGet('/users/me/reports');
    return envelope.list('reports', ReportCase.fromJson);
  }
}

/// A notification read plus its badge count, which travels on the same call.
class NotificationPage {
  const NotificationPage({required this.items, required this.unread});

  final List<PartnerNotification> items;
  final int unread;
}
