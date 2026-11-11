import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/json.dart';
import '../models/collab.dart';
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
  /// status } }`, a decision receipt, not a re-serialised row, so the inbox
  /// refetches the list after this instead of splicing a fake object in.
  /// `409` means it was already decided.
  Future<EventDecision> approve(String venueId, String eventId) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/event-requests/$eventId/approve',
    );
    return EventDecision.fromJson(envelope.raw('request'));
  }

  /// The full record behind one request (`GET …/event-requests/:eventId`).
  ///
  /// The list is deliberately thin, which is exactly why approving from it was
  /// unsafe: the menu, gallery, audience, inclusions and the host's note only
  /// exist on this endpoint.
  Future<ExperienceRequest> eventRequestDetail(
    String venueId,
    String eventId,
  ) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/event-requests/$eventId',
    );
    final detail = envelope.single('request', ExperienceRequest.fromJson);
    if (detail == null) throw StateError('Request payload missing');
    return detail;
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

  // ── Collaboration proposals ───────────────────────────────────────────────

  /// The venue's two-way proposal inbox (`GET …/collab-proposals`).
  ///
  /// `direction` splits the two halves the desk cares about: what a host asked
  /// you (`incoming`) and what you asked a host (`outgoing`). Omitting it
  /// returns both, newest first, which is what the proposals list renders.
  Future<List<CollabProposal>> proposals(
    String venueId, {
    ProposalDirection? direction,
    ProposalStatus? status,
    int limit = 100,
  }) async {
    try {
      final envelope = await _api.envelopeGet(
        '${base(venueId)}/collab-proposals',
        query: {
          'direction': ?direction?.wire,
          'status': ?status?.wire,
          'limit': limit,
        },
      );
      return envelope.list('proposals', CollabProposal.fromJson);
    } on ApiException catch (error) {
      // A deployment that predates the proposals router answers 404 for this
      // path. That is a capability the server does not offer, not an empty
      // inbox, so it is surfaced as its own failure instead of being reported
      // as "no proposals": the desk cannot act on a phone call if the screen
      // claims there is nothing to act on. The screen renders this as a named
      // gap with the server's own words and a retry; Home renders the count as
      // unknown rather than zero.
      if (error.isNotFound) {
        throw FeatureUnavailableException(
          'Collaboration proposals',
          error.message,
        );
      }
      rethrow;
    }
  }

  /// Answers a proposal a host sent. A `409` means the other desk already
  /// decided it, which the caller reports as "no longer pending".
  Future<CollabProposal?> answerProposal(
    String venueId,
    String proposalId, {
    required bool accept,
    String reason = '',
  }) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/collab-proposals/$proposalId/${accept ? 'accept' : 'decline'}',
      body: {'reason': reason.trim()},
    );
    return envelope.single('proposal', CollabProposal.fromJson);
  }

  /// Withdraws a proposal the venue sent, while the host has not answered.
  Future<CollabProposal?> cancelProposal(
    String venueId,
    String proposalId,
  ) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/collab-proposals/$proposalId/cancel',
    );
    return envelope.single('proposal', CollabProposal.fromJson);
  }

  /// The hosts this venue may propose to (`GET …/discover-hosts`).
  ///
  /// Professional accounts this venue is not already collaborating with, so a
  /// venue that sends twice is refused by the server rather than creating a
  /// second open proposal. `query` matches the host's name or handle.
  Future<List<DiscoverableHost>> discoverHosts(
    String venueId, {
    String query = '',
    int limit = 30,
  }) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/discover-hosts',
      query: {'q': ?(query.trim().isEmpty ? null : query.trim()), 'limit': limit},
    );
    return envelope.list('hosts', DiscoverableHost.fromJson);
  }

  /// Direction B: the venue proposes a collaboration to a host
  /// (`POST …/collab-proposals`).
  ///
  /// [experienceId] attaches an existing *draft* the host can publish once the
  /// proposal is accepted. A `404` means the target is not a professional host,
  /// a `422` that the draft belongs to somebody else or is already published,
  /// and a `409` that an active proposal already covers the pair.
  Future<CollabProposal> proposeToHost({
    required String venueId,
    required String hostId,
    required String title,
    required String message,
    String? experienceId,
  }) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/collab-proposals',
      body: {
        'hostId': hostId,
        'title': title.trim(),
        'message': message.trim(),
        'experienceId': ?experienceId,
      },
    );
    final proposal = envelope.single('proposal', CollabProposal.fromJson);
    if (proposal == null) throw StateError('Proposal payload missing');
    return proposal;
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
      query: {'status': ?status, 'limit': limit},
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
  ///
  /// `status` is refused here with a `400` by design: a venue must not be able
  /// to drive a host's lifecycle with a raw field write. Use [cancelEvent],
  /// [completeEvent] and [reopenEvent] instead.
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

  // ── Explicit lifecycle transitions ─────────────────────────────────────────
  //
  // These are the only sanctioned way for a venue to move an experience's
  // status. Each one is guarded server-side (an illegal transition is a `409`)
  // and each one tells the host, so no desk can silently take a listing down.

  /// Soft cancel (`POST /partner/events/:id/cancel`): the row is kept because
  /// bookings, payouts and the proposal that produced it reference it.
  Future<ExperienceTransition> cancelEvent(
    String eventId, {
    String reason = '',
  }) async {
    final envelope = await _api.envelopePost(
      '/partner/events/$eventId/cancel',
      body: {'reason': ?(reason.trim().isEmpty ? null : reason.trim())},
    );
    return ExperienceTransition.fromJson(envelope.data);
  }

  Future<ExperienceTransition> completeEvent(String eventId) async {
    final envelope = await _api.envelopePost('/partner/events/$eventId/complete');
    return ExperienceTransition.fromJson(envelope.data);
  }

  Future<ExperienceTransition> reopenEvent(String eventId) async {
    final envelope = await _api.envelopePost('/partner/events/$eventId/reopen');
    return ExperienceTransition.fromJson(envelope.data);
  }

  // ── Hosts & coordination ───────────────────────────────────────────────────

  /// Host performance is private to the host relationship; a venue that only
  /// supplied the space receives `403`, which the caller renders as "numbers not
  /// shared with you" rather than an error screen.
  Future<HostProfile> hostSummary(String hostId, {String name = ''}) async {
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
        .map(
          (json) => EventMessage.fromJson(json, currentUserId: currentUserId),
        )
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

/// A route the deployed API does not expose.
///
/// Distinct from `ApiException`: nothing failed in transit and the caller did
/// nothing wrong, so the screen says which capability is missing instead of
/// offering a retry that will keep answering `404 Route not found`.
///
/// Only thrown where an absent route would otherwise be indistinguishable
/// from a legitimately empty collection.
class FeatureUnavailableException implements Exception {
  const FeatureUnavailableException(this.feature, this.detail);

  /// Name of the capability, for the screen's title.
  final String feature;

  /// What the server actually answered.
  final String detail;

  @override
  String toString() => '$feature is not available on this server: $detail';
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
