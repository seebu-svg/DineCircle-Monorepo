import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/venue.dart';
import 'app_providers.dart';

/// One venue active at a time. Everything venue-scoped rebuilds on a switch,
/// while the account-wide surfaces (experiences, bookings, packages, analytics,
/// notifications) stay as they are and say so on screen.
class VenueScopeState {
  const VenueScopeState({
    required this.venues,
    this.selectedId,
    this.loadError = '',
  });

  final List<Venue> venues;
  final String? selectedId;
  final String loadError;

  Venue? get selected {
    final id = selectedId;
    if (id == null) return null;
    for (final venue in venues) {
      if (venue.id == id) return venue;
    }
    return venues.isEmpty ? null : venues.first;
  }

  bool get hasVenues => venues.isNotEmpty;

  /// The state the router reacts to: no venues at all means the account has not
  /// registered a restaurant yet.
  bool get needsRegistration => venues.isEmpty && loadError.isEmpty;

  VenueScopeState copyWith({
    List<Venue>? venues,
    String? selectedId,
    String? loadError,
  }) => VenueScopeState(
    venues: venues ?? this.venues,
    selectedId: selectedId ?? this.selectedId,
    loadError: loadError ?? this.loadError,
  );
}

/// Loads the operated venues and remembers the choice per account.
class VenueScopeController extends AsyncNotifier<VenueScopeState> {
  @override
  Future<VenueScopeState> build() async {
    final userId = ref.watch(currentUserProvider)?.id ?? '';
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final stored = userId.isEmpty ? null : prefs.getString(_key(userId));
    try {
      final venues = await ref.read(venueRepositoryProvider).listVenues();
      final resolved = venues.any((v) => v.id == stored)
          ? stored
          : (venues.isEmpty ? null : venues.first.id);
      return VenueScopeState(venues: venues, selectedId: resolved);
    } catch (error) {
      return VenueScopeState(
        venues: const [],
        loadError: error.toString(),
      );
    }
  }

  static String _key(String userId) => 'partner.selectedVenue.$userId';

  /// Switches venue. Persisted so a reload returns to the same desk.
  Future<void> select(String venueId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedId: venueId));
    final userId = ref.read(currentUserProvider)?.id ?? '';
    if (userId.isEmpty) return;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_key(userId), venueId);
  }

  /// Re-reads after a registration or a role change.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final venueScopeProvider =
    AsyncNotifierProvider<VenueScopeController, VenueScopeState>(
      VenueScopeController.new,
    );

/// The active venue, or null while scope is unresolved.
final selectedVenueProvider = Provider<Venue?>(
  (ref) => ref.watch(venueScopeProvider).valueOrNull?.selected,
);

final selectedVenueIdProvider = Provider<String>(
  (ref) => ref.watch(selectedVenueProvider)?.id ?? '',
);

/// The caller's role **inside the active venue**.
final myRoleProvider = Provider<PartnerRole>(
  (ref) => ref.watch(selectedVenueProvider)?.myRole ?? PartnerRole.staff,
);

/// Platform-level admin, which bypasses the venue ladder entirely.
final isPlatformAdminProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider)?.isPlatformAdmin ?? false,
);

/// What an operator may do, derived from the venue role.
///
/// Mirrored client-side only to decide what to *render*; the server stays
/// authoritative and every screen still handles `403`/`409`/`422` inline.
enum Capability {
  viewDayList,
  checkIn,
  manageReservations,
  manageTables,
  manageHours,
  manageProfile,
  manageMenu,
  manageDeals,
  approveRequests,
  createExperiences,
  viewEarnings,
  manageStaff,
  manageBilling,
  registerVenue,
}

/// Human name for a capability, used in the disabled-control tooltip.
extension CapabilityLabel on Capability {
  String get label => switch (this) {
    Capability.viewDayList => 'The day list',
    Capability.checkIn => 'Check-in',
    Capability.manageReservations => 'Reservation actions',
    Capability.manageTables => 'Table editing',
    Capability.manageHours => 'Opening hours',
    Capability.manageProfile => 'Profile editing',
    Capability.manageMenu => 'Menu editing',
    Capability.manageDeals => 'Deal management',
    Capability.approveRequests => 'Approving host requests',
    Capability.createExperiences => 'Creating experiences',
    Capability.viewEarnings => 'Earnings',
    Capability.manageStaff => 'Team management',
    Capability.manageBilling => 'Subscription and billing',
    Capability.registerVenue => 'Venue registration',
  };
}

/// staff ⊂ manager ⊂ owner, exactly as `requireVenueRole` ranks them.
const Map<Capability, PartnerRole> _minimumRole = {
  Capability.viewDayList: PartnerRole.staff,
  Capability.checkIn: PartnerRole.staff,
  Capability.manageReservations: PartnerRole.staff,
  Capability.manageTables: PartnerRole.manager,
  Capability.manageHours: PartnerRole.manager,
  Capability.manageProfile: PartnerRole.manager,
  Capability.manageMenu: PartnerRole.manager,
  Capability.manageDeals: PartnerRole.manager,
  Capability.approveRequests: PartnerRole.manager,
  Capability.createExperiences: PartnerRole.manager,
  Capability.viewEarnings: PartnerRole.manager,
  Capability.manageStaff: PartnerRole.owner,
  Capability.manageBilling: PartnerRole.owner,
  Capability.registerVenue: PartnerRole.owner,
};

/// Why a control is unavailable, for the tooltip beside a disabled button.
String capabilityDenial(Capability capability, PartnerRole role) =>
    '${capability.label} needs the ${_minimumRole[capability]?.label} role. '
    'you are ${role.label.toLowerCase()} here.';

extension CapabilityCheck on PartnerRole {
  bool allows(Capability capability) =>
      rank >= (_minimumRole[capability]?.rank ?? PartnerRole.owner.rank);
}

/// Reads the gate for the active venue. A platform admin passes everything, so
/// the review queue and the venue screens behave the same for them.
final roleGateProvider = Provider<RoleGate>((ref) {
  final role = ref.watch(myRoleProvider);
  return RoleGate(role: role, isAdmin: ref.watch(isPlatformAdminProvider));
});

class RoleGate {
  const RoleGate({required this.role, required this.isAdmin});

  final PartnerRole role;
  final bool isAdmin;

  bool can(Capability capability) => isAdmin || role.allows(capability);

  String denial(Capability capability) => capabilityDenial(capability, role);

  /// The venue must be verified before it can sell anything, deals, host
  /// approvals and payouts all hinge on the same server-side flag.
  bool canSell(Venue? venue) => venue?.verified ?? false;
}
