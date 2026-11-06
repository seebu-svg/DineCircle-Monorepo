import '../api/api_client.dart';
import '../api/json.dart';
import '../models/comms.dart';
import '../models/experience.dart';

/// Create/edit payload for a venue-owned experience (`POST /partner/events`).
///
/// Mirrors `createPartnerEventSchema`. `endAt` is required by the server even
/// though the list read never returns it, so the form always collects it.
class ExperienceInput {
  const ExperienceInput({
    required this.restaurantId,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.seatsTotal,
    required this.pricePerSeat,
    this.tagline = '',
    this.description = '',
    this.type = 'dinner',
    this.audience = 'public',
    this.menuStyle = 'setMenu',
    this.coverImage = '',
    this.tags = const [],
    this.collaboratorIds = const [],
  });

  final String restaurantId;
  final String title;
  final String tagline;
  final String description;
  final DateTime startAt;
  final DateTime endAt;
  final int seatsTotal;
  final double pricePerSeat;
  final String type;
  final String audience;
  final String menuStyle;
  final String coverImage;
  final List<String> tags;
  final List<String> collaboratorIds;

  Map<String, dynamic> toBody() => {
    'restaurantId': restaurantId,
    'title': title.trim(),
    'tagline': tagline.trim(),
    'description': description.trim(),
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'seatsTotal': seatsTotal,
    'pricePerSeat': pricePerSeat,
    'type': type,
    'audience': audience,
    'menuStyle': menuStyle,
    'coverImage': coverImage.trim(),
    'tags': tags,
    'collaboratorIds': collaboratorIds,
  };
}

/// Experiences, host requests, and the coordination surfaces around them.
class ExperienceRepository {
  ExperienceRepository(this._api);

  final ApiClient _api;

  static String base(String venueId) => '/partner/restaurants/$venueId';

  // ── Host proposals ─────────────────────────────────────────────────────────

  /// `requested` is the default on the server; the board also reads `confirmed`
  /// (what you approved) and `declined` to show the outcome.
  Future<List<ExperienceRequest>> requests(
    String venueId, {
    String status = 'requested',
    int limit = 50,
    int page = 1,
  }) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/event-requests',
      query: {'status': status, 'limit': limit, 'page': page},
    );
    return envelope.list('requests', ExperienceRequest.fromJson);
  }

  /// Publishes a requested event. The server answers `{ request: { eventId,
  /// status } }` — a decision receipt, not a re-serialised row — so the inbox
  /// refetches the list after this instead of splicing a fake object in.
  /// `409` means it was already decided.
  Future<EventDecision> approve(String venueId, String eventId) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/event-requests/$eventId/approve',
    );
    return EventDecision.fromJson(envelope.raw('request'));
  }

  Future<EventDecision> decline(
    String venueId,
    String eventId, {
    String reason = '',
  }) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/event-requests/$eventId/decline',
      body: {'reason': reason.trim()},
    );
    return EventDecision.fromJson(envelope.raw('request'));
  }

  // ── Venue-owned experiences ────────────────────────────────────────────────

  /// Account-wide: every venue the caller operates, which is why the screen
  /// labels the list "all your venues" when more than one is linked.
  Future<List<PartnerExperience>> experiences({
    String? status,
    int limit = 50,
  }) async {
    final envelope = await _api.envelopeGet(
      '/partner/events',
      query: {
        'status': ?status,
        'limit': limit,
      },
    );
    return envelope.list('events', PartnerExperience.fromJson);
  }

  Future<PartnerExperience> createExperience(ExperienceInput input) async {
    final envelope = await _api.envelopePost(
      '/partner/events',
      body: input.toBody(),
    );
    final event = envelope.single('event', PartnerExperience.fromJson);
    if (event == null) throw StateError('Event payload missing');
    return event;
  }

  /// Partial update. An empty body is a `400` on the server, so callers pass
  /// only the keys the operator changed.
  Future<PartnerExperience> updateExperience(
    String eventId,
    Map<String, dynamic> changes,
  ) async {
    final envelope = await _api.envelopePut(
      '/partner/events/$eventId',
      body: changes,
    );
    final event = envelope.single('event', PartnerExperience.fromJson);
    if (event == null) throw StateError('Event payload missing');
    return event;
  }

  // ── Hosts & coordination ───────────────────────────────────────────────────

  /// Host performance is private to the host relationship; a venue that only
  /// supplied the space receives `403`, which the caller renders as "numbers not
  /// shared with you" rather than an error screen.
  Future<HostProfile> hostSummary(
    String hostId, {
    String name = '',
  }) async {
    final envelope = await _api.envelopeGet('/hosts/$hostId/summary');
    return HostProfile.fromJson(envelope.data, name: name);
  }

  Future<List<EventMessage>> thread(
    String eventId, {
    String currentUserId = '',
  }) async {
    final envelope = await _api.envelopeGet('/events/$eventId/messages');
    return envelope
        .resources('messages')
        .map((json) => EventMessage.fromJson(json, currentUserId: currentUserId))
        .toList(growable: false);
  }

  Future<EventMessage> sendMessage(String eventId, String text) async {
    final envelope = await _api.envelopePost(
      '/events/$eventId/messages',
      body: {'text': text.trim()},
    );
    final message = envelope.resourceMap('message');
    return EventMessage.fromJson(message ?? envelope.data);
  }
}

/// Receipt for an approve/decline decision.
class EventDecision {
  const EventDecision({
    required this.eventId,
    required this.status,
    this.reason = '',
  });

  factory EventDecision.fromJson(Object? value) {
    final json = asMap(value);
    return EventDecision(
      eventId: asString(json['eventId']),
      status: asString(json['status']),
      reason: asString(json['reason']),
    );
  }

  final String eventId;
  final String status;
  final String reason;
}
