import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';

void main() {
  group('capability matrix (staff ⊂ manager ⊂ owner)', () {
    const dailyOps = [
      Capability.viewDayList,
      Capability.checkIn,
      Capability.manageReservations,
    ];
    const managerWork = [
      Capability.manageTables,
      Capability.manageHours,
      Capability.manageProfile,
      Capability.manageMenu,
      Capability.manageDeals,
      Capability.approveRequests,
      Capability.createExperiences,
      Capability.viewEarnings,
    ];
    const ownerWork = [Capability.manageStaff, Capability.registerVenue];

    test('staff can run the daily loop but not edit the venue', () {
      for (final c in dailyOps) {
        expect(PartnerRole.staff.allows(c), isTrue, reason: '$c');
      }
      for (final c in [...managerWork, ...ownerWork]) {
        expect(PartnerRole.staff.allows(c), isFalse, reason: '$c');
      }
    });

    test('manager adds everything manager-level but not owner actions', () {
      for (final c in [...dailyOps, ...managerWork]) {
        expect(PartnerRole.manager.allows(c), isTrue, reason: '$c');
      }
      for (final c in ownerWork) {
        expect(PartnerRole.manager.allows(c), isFalse, reason: '$c');
      }
    });

    test('owner allows every capability', () {
      for (final c in Capability.values) {
        expect(PartnerRole.owner.allows(c), isTrue, reason: '$c');
      }
    });
  });

  group('RoleGate', () {
    test('a platform admin passes everything regardless of venue role', () {
      const gate = RoleGate(role: PartnerRole.staff, isAdmin: true);
      for (final c in Capability.values) {
        expect(gate.can(c), isTrue, reason: '$c');
      }
    });

    test('a non-admin obeys the venue ladder', () {
      const gate = RoleGate(role: PartnerRole.manager, isAdmin: false);
      expect(gate.can(Capability.manageMenu), isTrue);
      expect(gate.can(Capability.manageStaff), isFalse);
    });

    test('denial message names the minimum role and the caller role', () {
      const gate = RoleGate(role: PartnerRole.staff, isAdmin: false);
      expect(gate.denial(Capability.manageStaff), contains('Owner'));
      expect(gate.denial(Capability.manageStaff), contains('staff'));
    });

    test('canSell is exactly the server verified flag', () {
      const gate = RoleGate(role: PartnerRole.owner, isAdmin: false);
      expect(
        gate.canSell(const Venue(id: 'v', name: 'N', verified: true)),
        isTrue,
      );
      expect(gate.canSell(const Venue(id: 'v', name: 'N')), isFalse);
      expect(gate.canSell(null), isFalse);
    });
  });

  group('VenueScopeState.selected', () {
    const a = Venue(id: 'a', name: 'A');
    const b = Venue(id: 'b', name: 'B');

    test('honours the stored id when it is still available', () {
      const state = VenueScopeState(venues: [a, b], selectedId: 'b');
      expect(state.selected?.id, 'b');
    });

    test('falls back to the first venue when the stored id is gone', () {
      const state = VenueScopeState(venues: [a, b], selectedId: 'stale');
      expect(state.selected?.id, 'a');
    });

    test('no venues means no selection and registration is needed', () {
      const state = VenueScopeState(venues: []);
      expect(state.selected, isNull);
      expect(state.hasVenues, isFalse);
      expect(state.needsRegistration, isTrue);
    });

    test('a load error is not treated as "needs registration"', () {
      const state = VenueScopeState(venues: [], loadError: 'offline');
      expect(state.needsRegistration, isFalse);
    });
  });
}
