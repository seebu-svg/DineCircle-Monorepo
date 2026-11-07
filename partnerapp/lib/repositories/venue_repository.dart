import '../api/api_client.dart';
import '../api/json.dart';
import '../models/account.dart';
import '../models/operations.dart';
import '../models/subscription.dart';
import '../models/venue.dart';

/// A single venue read: the profile plus the counts the server joins in.
class VenueDetail {
  const VenueDetail({required this.venue, required this.counts});

  final Venue venue;
  final VenueCounts counts;
}

/// Venues, verification, staff, branches, hours and the operational home.
///
/// Every method takes the venue id explicitly: the scope provider supplies it,
/// so no repository ever holds a hidden "current venue" that could leak across
/// a venue switch mid-request.
class VenueRepository {
  VenueRepository(this._api);

  final ApiClient _api;

  static String base(String venueId) => '/partner/restaurants/$venueId';

  // ── Venues ─────────────────────────────────────────────────────────────────

  /// Venues this account may operate, each carrying `myRole`.
  Future<List<Venue>> listVenues() async {
    final envelope = await _api.envelopeGet('/partner/restaurants');
    return envelope.list('restaurants', Venue.fromJson);
  }

  Future<VenueDetail> venue(String venueId) async {
    final envelope = await _api.envelopeGet(base(venueId));
    final venue = envelope.single('restaurant', Venue.fromJson);
    if (venue == null) {
      // `404` is the normal answer for a venue that is not ours; anything that
      // got here without a restaurant object is a contract break.
      throw StateError('Venue payload missing');
    }
    return VenueDetail(
      venue: venue,
      counts: VenueCounts.fromJson(envelope.resourceMap('counts')),
    );
  }

  /// Self-service registration: creates the venue, its primary branch, a
  /// verification request, and links the caller as `owner`.
  Future<Venue> register(RegisterVenueInput input) async {
    final envelope = await _api.envelopePost(
      '/partner/restaurants',
      body: input.toBody(),
    );
    final venue = envelope.single('restaurant', Venue.fromJson);
    if (venue == null) throw StateError('Registration payload missing venue');
    return venue;
  }

  Future<Venue> updateProfile(
    String venueId,
    VenueProfileEdit edit,
  ) async {
    final envelope = await _api.envelopePatch(base(venueId), body: edit.toBody());
    final venue = envelope.single('restaurant', Venue.fromJson);
    if (venue == null) throw StateError('Venue payload missing');
    return venue;
  }

  // ── Verification ───────────────────────────────────────────────────────────

  /// (Re)opens a verification request, the path out of a rejection.
  Future<void> requestVerification(String venueId) =>
      _api.postJson('${base(venueId)}/verification');

  /// Platform-wide queue. `super_admin` only; anyone else gets `403`.
  Future<List<VerificationRequest>> verificationQueue({
    String status = 'pending',
  }) async {
    final envelope = await _api.envelopeGet(
      '/partner/verification/requests',
      query: {'status': status},
    );
    return envelope.list('requests', VerificationRequest.fromJson);
  }

  /// Admin decision. The route answers a receipt (`{requestId, status,
  /// restaurantId}`) rather than a re-serialised request, and re-reviewing is a
  /// `409`.
  Future<VerificationDecision> reviewVerification(
    String requestId, {
    required String decision,
    String reviewerNote = '',
  }) async {
    final envelope = await _api.envelopePost(
      '/partner/verification/requests/$requestId/review',
      body: {'decision': decision, 'reviewerNote': reviewerNote},
    );
    return VerificationDecision(
      requestId: asString(envelope.raw('requestId'), fallback: requestId),
      status: asString(envelope.raw('status')),
      restaurantId: asString(envelope.raw('restaurantId')),
    );
  }

  // ── Staff ──────────────────────────────────────────────────────────────────

  Future<List<StaffMember>> staff(String venueId) async {
    final envelope = await _api.envelopeGet('${base(venueId)}/staff');
    return envelope.list('staff', StaffMember.fromJson);
  }

  /// Invite by email or phone. `owner` only, the server enforces the rank.
  Future<StaffMember> inviteStaff(
    String venueId, {
    String email = '',
    String phone = '',
    String role = 'staff',
  }) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/staff',
      body: {
        if (email.trim().isNotEmpty) 'email': email.trim().toLowerCase(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        'role': role,
      },
    );
    return StaffMember.fromJson(envelope.data);
  }

  /// Acceptance of an invite the caller owns; invited staff are inert until
  /// this runs.
  Future<void> acceptInvite(String venueId) =>
      _api.postJson('${base(venueId)}/staff/accept');

  Future<StaffMember> updateStaffRole(
    String venueId,
    String userId, {
    String? role,
    String? status,
  }) async {
    final envelope = await _api.envelopePatch(
      '${base(venueId)}/staff/$userId',
      body: {
        'role': ?role,
        'status': ?status,
      },
    );
    return StaffMember.fromJson(envelope.data);
  }

  Future<void> revokeStaff(String venueId, String userId) =>
      _api.deleteJson('${base(venueId)}/staff/$userId');

  // ── Branches & hours ───────────────────────────────────────────────────────

  Future<List<Branch>> branches(String venueId) async {
    final envelope = await _api.envelopeGet('${base(venueId)}/branches');
    return envelope.list('branches', Branch.fromJson);
  }

  Future<Branch> createBranch(String venueId, BranchInput input) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/branches',
      body: input.toBody(),
    );
    final branch = envelope.single('branch', Branch.fromJson);
    if (branch == null) throw StateError('Branch payload missing');
    return branch;
  }

  Future<Branch> updateBranch(
    String venueId,
    String branchId,
    BranchInput input,
  ) async {
    final envelope = await _api.envelopePatch(
      '${base(venueId)}/branches/$branchId',
      body: input.toBody(),
    );
    final branch = envelope.single('branch', Branch.fromJson);
    if (branch == null) throw StateError('Branch payload missing');
    return branch;
  }

  Future<void> deleteBranch(String venueId, String branchId) =>
      _api.deleteJson('${base(venueId)}/branches/$branchId');

  /// Weekly hours for one branch, in its own timezone.
  Future<BranchHours> branchHours(String venueId, String branchId) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/branches/$branchId/hours',
    );
    return BranchHours(
      branchId: asString(envelope.raw('branchId'), fallback: branchId),
      hours: OpeningHours.fromJson(envelope.raw('openingHours')),
    );
  }

  /// Replaces the whole week. The route takes the hours map as the body (not a
  /// wrapper), writes it to the branch, and mirrors it onto the venue when the
  /// branch is the primary one, so the response's branch is the fresh truth.
  Future<Branch> saveBranchHours(
    String venueId,
    String branchId,
    OpeningHours hours,
  ) async {
    final envelope = await _api.envelopePut(
      '${base(venueId)}/branches/$branchId/hours',
      body: hours.toJson(),
    );
    final branch = envelope.single('branch', Branch.fromJson);
    if (branch == null) throw StateError('Branch payload missing');
    return branch;
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  Future<DashboardSnapshot> dashboard(String venueId) async {
    final envelope = await _api.envelopeGet('${base(venueId)}/dashboard');
    return DashboardSnapshot.fromJson(envelope.data);
  }

  // ── Subscription ───────────────────────────────────────────────────────────

  /// The venue's current subscription (synthetic default when no row exists).
  Future<VenueSubscription> subscription(String venueId) async {
    final envelope = await _api.envelopeGet(
      '${base(venueId)}/subscription',
    );
    return VenueSubscription.fromJson(envelope.data);
  }

  /// Owner-only: change plan, toggle auto-renew, or cancel.
  Future<VenueSubscription> updateSubscription(
    String venueId, {
    String? plan,
    bool? autoRenew,
    String? status,
  }) async {
    final envelope = await _api.envelopePatch(
      '${base(venueId)}/subscription',
      body: {
        'plan': ?plan,
        'autoRenew': ?autoRenew,
        'status': ?status,
      },
    );
    return VenueSubscription.fromJson(envelope.data);
  }
}

/// The hours payload as the branch route answers it.
class BranchHours {
  const BranchHours({required this.branchId, required this.hours});

  final String branchId;
  final OpeningHours hours;
}

/// Receipt for a platform-admin verification decision.
class VerificationDecision {
  const VerificationDecision({
    required this.requestId,
    required this.status,
    required this.restaurantId,
  });

  final String requestId;
  final String status;
  final String restaurantId;

  bool get approved => status == 'approved';
}
