import '../api/json.dart';

/// The per-venue role ladder, mirrored from `server/src/access.ts`.
///
/// Ranks are ordered, so a capability check is a numeric comparison rather than
/// a list of role names duplicated across screens. The server is still
/// authoritative, this only decides which controls are enabled before a
/// request is made.
enum PartnerRole {
  staff('staff', 1, 'Staff'),
  manager('manager', 2, 'Manager'),
  owner('owner', 3, 'Owner');

  const PartnerRole(this.wire, this.rank, this.label);

  /// Value on the wire.
  final String wire;

  /// `staff (1) < manager (2) < owner (3)`.
  final int rank;

  /// Display name.
  final String label;

  static PartnerRole parse(String? value) => PartnerRole.values.firstWhere(
    (role) => role.wire == value,
    orElse: () => PartnerRole.staff,
  );
}

/// The signed-in account (`/auth/me`, `/users/me`).
///
/// [role] is the *platform* role (`user`, `host`, `restaurant_owner`,
/// `restaurant_staff`, `partner_admin`, `super_admin`) and decides whether the
/// partner surface is reachable at all; the venue ladder above decides what may
/// be done inside a venue.
class PartnerUser {
  const PartnerUser({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.role = 'user',
    this.handle = '',
    this.avatarUrl = '',
    this.bio = '',
    this.city = '',
    this.dietary = const [],
    this.allergies = const [],
  });

  factory PartnerUser.fromJson(Map<String, dynamic> json) => PartnerUser(
    id: asString(json['id']),
    name: asString(json['name']),
    email: asString(json['email']),
    phone: asString(json['phone']),
    role: asString(json['role'], fallback: 'user'),
    handle: asString(json['handle']),
    avatarUrl: asString(json['avatarUrl']),
    bio: asString(json['bio']),
    city: asString(json['city']),
    dietary: asStringList(json['dietary']),
    allergies: asStringList(json['allergies']),
  );

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String handle;
  final String avatarUrl;
  final String bio;
  final String city;
  final List<String> dietary;
  final List<String> allergies;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    if (parts.length == 1) return first.toUpperCase();
    return '$first${parts.last[0]}'.toUpperCase();
  }

  /// The only role allowed to approve new venues. Nothing else in the app
  /// branches on platform role.
  bool get isPlatformAdmin => role == 'super_admin';

  /// Roles the partner surface accepts (`requirePartner`). A venue member who
  /// keeps a `host` role is still a partner, so membership is probed by loading
  /// the venue list rather than by trusting this flag.
  bool get hasPartnerRole => const [
    'partner_admin',
    'super_admin',
    'restaurant_owner',
    'restaurant_staff',
  ].contains(role);
}

/// One row of the venue roster (`GET …/staff`).
///
/// Invited members stay `invited` until they accept, so a mis-typed invite
/// cannot silently grant access.
class StaffMember {
  const StaffMember({
    required this.userId,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    required this.status,
    this.createdAt,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) => StaffMember(
    userId: asString(json['userId']),
    name: asString(json['name']),
    email: asStringOrNull(json['email']),
    phone: asStringOrNull(json['phone']),
    role: PartnerRole.parse(asString(json['role'])),
    status: asString(json['status'], fallback: 'active'),
    createdAt: asDate(json['createdAt']),
  );

  final String userId;
  final String name;
  final String? email;
  final String? phone;
  final PartnerRole role;
  final String status;
  final DateTime? createdAt;

  bool get isActive => status == 'active';
  bool get isInvited => status == 'invited';
  bool get isOwner => role == PartnerRole.owner;

  String get contact {
    final value = email ?? phone;
    return value == null || value.isEmpty ? 'No contact on file' : value;
  }
}

/// A venue verification request in the platform review queue.
class VerificationRequest {
  const VerificationRequest({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.status,
    this.note = '',
    this.reviewerNote = '',
    this.reviewedAt,
    this.createdAt,
  });

  factory VerificationRequest.fromJson(Map<String, dynamic> json) =>
      VerificationRequest(
        id: asString(json['id']),
        restaurantId: asString(json['restaurantId']),
        restaurantName: asString(json['restaurantName']),
        status: asString(json['status'], fallback: 'pending'),
        note: asString(json['note']),
        reviewerNote: asString(json['reviewerNote']),
        reviewedAt: asDate(json['reviewedAt']),
        createdAt: asDate(json['createdAt']),
      );

  final String id;
  final String restaurantId;
  final String restaurantName;
  final String status;
  final String note;
  final String reviewerNote;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';
}
