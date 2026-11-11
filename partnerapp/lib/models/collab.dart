import '../api/json.dart';

/// The two sides of a collaboration proposal (`collaboration_invites`).
///
/// A proposal is always between one host and one venue, and the venue app only
/// ever sees its own half. `direction` is derived server-side from
/// `proposed_by`, so an incoming row is one the venue has to answer and an
/// outgoing row is one the venue sent and has to wait on.
enum ProposalDirection {
  incoming('incoming', 'Incoming'),
  outgoing('outgoing', 'Sent');

  const ProposalDirection(this.wire, this.label);

  final String wire;
  final String label;

  static ProposalDirection parse(String? value) =>
      ProposalDirection.values.firstWhere(
        (direction) => direction.wire == value,
        orElse: () => ProposalDirection.incoming,
      );
}

/// Lifecycle of a proposal. `invited` is the open state; the other four are
/// outcomes, so a single pill vocabulary covers both directions.
enum ProposalStatus {
  invited('invited', 'Awaiting reply'),
  accepted('accepted', 'Accepted'),
  declined('declined', 'Declined'),
  cancelled('cancelled', 'Withdrawn'),
  completed('completed', 'Completed');

  const ProposalStatus(this.wire, this.label);

  final String wire;
  final String label;

  static ProposalStatus parse(String? value) =>
      ProposalStatus.values.firstWhere(
        (status) => status.wire == value,
        orElse: () => ProposalStatus.invited,
      );

  bool get isOpen => this == ProposalStatus.invited;
}

/// The host half of a proposal, as the venue is allowed to see it.
class ProposalHost {
  const ProposalHost({
    required this.id,
    required this.name,
    this.handle = '',
    this.avatarUrl = '',
  });

  factory ProposalHost.fromJson(Object? value) {
    final json = asMap(value);
    return ProposalHost(
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

  String get displayName => name.trim().isEmpty ? 'A host' : name.trim();
}

/// The experience a proposal is attached to, when one exists.
class ProposalExperience {
  const ProposalExperience({
    required this.id,
    required this.title,
    this.startAt,
    this.status = '',
  });

  factory ProposalExperience.fromJson(Object? value) {
    final json = asMap(value);
    return ProposalExperience(
      id: asString(json['id']),
      title: asString(json['title']),
      startAt: asDate(json['startAt']),
      status: asString(json['status']),
    );
  }

  final String id;
  final String title;
  final DateTime? startAt;
  final String status;
}

/// A host the venue may propose to (`GET …/discover-hosts`).
///
/// This is the real discovery surface: professional accounts with host
/// capabilities that this venue is not already in an active collaboration
/// with. The Hosts tab used to derive its list from event requests, which meant
/// a venue could only ever work with people who had already knocked.
class DiscoverableHost {
  const DiscoverableHost({
    required this.id,
    required this.name,
    this.handle = '',
    this.avatarUrl = '',
    this.bio = '',
    this.followersCount = 0,
    this.eventsTogether = 0,
  });

  factory DiscoverableHost.fromJson(Map<String, dynamic> json) =>
      DiscoverableHost(
        id: asString(json['id']),
        name: asString(json['name']),
        handle: asString(json['handle']),
        avatarUrl: asString(json['avatarUrl']),
        bio: asString(json['bio']),
        followersCount: asInt(json['followersCount']),
        eventsTogether: asInt(json['eventsTogether']),
      );

  final String id;
  final String name;
  final String handle;
  final String avatarUrl;
  final String bio;
  final int followersCount;
  final int eventsTogether;

  String get displayName => name.trim().isEmpty ? 'A host' : name.trim();

  String get initials {
    final source = name.trim();
    return source.isEmpty ? '?' : source[0].toUpperCase();
  }

  /// A returning host is worth a second collaboration more than a stranger.
  bool get hasWorkedHere => eventsTogether > 0;
}

/// One collaboration proposal (`GET …/collab-proposals`).
///
/// The same shape serves both directions, which is why the two questions the
/// desk asks of a row are asked here as [awaitsVenue] and [awaitsHost] rather
/// than by branching on direction at every call site.
class CollabProposal {
  const CollabProposal({
    required this.id,
    required this.title,
    required this.direction,
    required this.status,
    required this.host,
    this.message = '',
    this.experience,
    this.declineReason = '',
    this.createdAt,
    this.respondedAt,
  });

  factory CollabProposal.fromJson(Map<String, dynamic> json) => CollabProposal(
    id: asString(json['id']),
    title: asString(json['title']),
    message: asString(json['message']),
    direction: ProposalDirection.parse(asString(json['direction'])),
    status: ProposalStatus.parse(asString(json['status'])),
    host: ProposalHost.fromJson(json['host']),
    experience: json['experience'] == null
        ? null
        : ProposalExperience.fromJson(json['experience']),
    declineReason: asString(json['declineReason']),
    createdAt: asDate(json['createdAt']),
    respondedAt: asDate(json['respondedAt']),
  );

  final String id;
  final String title;
  final String message;
  final ProposalDirection direction;
  final ProposalStatus status;
  final ProposalHost host;
  final ProposalExperience? experience;
  final String declineReason;
  final DateTime? createdAt;
  final DateTime? respondedAt;

  /// A host asked, the venue has not answered: the actionable case.
  bool get awaitsVenue =>
      direction == ProposalDirection.incoming && status.isOpen;

  /// The venue asked and the host has not answered: a wait, not a task.
  bool get awaitsHost =>
      direction == ProposalDirection.outgoing && status.isOpen;

  /// The pill tone. `accepted` has no entry in [AppColors.forStatus], so it is
  /// mapped onto the shared success word instead of rendering grey.
  String get statusTone =>
      status == ProposalStatus.accepted ? 'confirmed' : status.wire;

  String get counterpartLabel => host.displayName;
}
