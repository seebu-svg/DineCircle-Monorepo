import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/module_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/repositories/venue_repository.dart';
import 'package:partnerapp/screens/business/profile_tab.dart';
import 'package:partnerapp/theme/app_theme.dart';

/// The profile tab reads one venue detail and renders it across four sections,
/// so these tests hold the two things a rebuild can silently break: every
/// section still shows the live record, and Edit still opens a form seeded from
/// that same record. Both reads are overridden, so nothing here hits the
/// network, and the last test lays the tab out at 320px under 2.0 text scale.
final _venue = Venue(
  id: 'v1',
  name: 'Sea & Salt',
  tagline: 'Coastal kitchen',
  about: 'Fire-grilled fish at the harbour.',
  cuisines: const ['Seafood', 'Coastal'],
  neighborhood: 'Clifton',
  address: 'Pier 4, Dock Road',
  city: 'Karachi',
  phone: '+92 300 0000000',
  email: 'desk@seaandsalt.pk',
  website: 'https://seaandsalt.pk',
  instagram: '@seaandsalt',
  priceRange: r'$$$',
  rating: 4.6,
  reviewCount: 218,
  seats: 64,
  amenities: const ['Valet', 'Rooftop'],
  verified: true,
  partnershipStatus: 'verified',
  acceptingBookings: true,
  myRole: PartnerRole.owner,
);

class _Scope extends VenueScopeController {
  @override
  Future<VenueScopeState> build() async => VenueScopeState(
    venues: [_venue],
    selectedId: 'v1',
  );
}

Widget _harness() => ProviderScope(
  overrides: [
    venueScopeProvider.overrideWith(() => _Scope()),
    venueDetailProvider.overrideWith(
      (ref, venueId) async => VenueDetail(
        venue: _venue,
        counts: const VenueCounts(
          branches: 2,
          tables: 14,
          menuItems: 48,
          upcomingEvents: 6,
          pendingReservations: 3,
        ),
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const Scaffold(body: ProfileTab()),
  ),
);

void main() {
  testWidgets('renders the live venue across all four sections', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Identity + hero
    expect(find.text('Restaurant Profile'), findsOneWidget);
    expect(find.text('Sea & Salt'), findsOneWidget);
    expect(find.text(r'$$$ · Verified'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    // The hero pill and the policy row state the same fact, one as a badge and
    // one as a named policy, so this label legitimately appears twice.
    expect(find.text('Accepting Bookings'), findsNWidgets(2));

    // About
    expect(find.text('Coastal kitchen'), findsOneWidget);
    expect(find.text('Fire-grilled fish at the harbour.'), findsOneWidget);
    expect(find.text('Seafood, Coastal'), findsOneWidget);
    expect(find.text('64 seats'), findsOneWidget);
    expect(find.text('Valet, Rooftop'), findsOneWidget);

    // Location & contact
    expect(find.text('Pier 4, Dock Road'), findsOneWidget);
    expect(find.text('Clifton'), findsOneWidget);
    expect(find.text('+92 300 0000000'), findsOneWidget);
    expect(find.text('desk@seaandsalt.pk'), findsOneWidget);
    expect(find.text('https://seaandsalt.pk'), findsOneWidget);
    expect(find.text('@seaandsalt'), findsOneWidget);

    // Snapshot, then policies
    expect(find.text('218 reviews'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Booking Policies'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
  });

  testWidgets('blank fields say so instead of disappearing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          venueScopeProvider.overrideWith(() => _Scope()),
          venueDetailProvider.overrideWith(
            (ref, venueId) async => VenueDetail(
              venue: Venue(id: 'v1', name: 'Sea & Salt', myRole: PartnerRole.owner),
              counts: const VenueCounts(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: ProfileTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The tagline and description are empty, so their rows drop out, but the
    // contact rows stay and mark themselves as missing rather than vanishing.
    expect(find.text('Tagline'), findsNothing);
    expect(find.text('Not provided'), findsWidgets);
  });

  testWidgets('Edit opens a form seeded from the venue, Cancel returns', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    // Each seeded field starts from the live record, so nothing blanks on open.
    expect(find.text('Sea & Salt'), findsOneWidget);
    expect(find.text('Pier 4, Dock Road'), findsOneWidget);
    expect(find.text('Coastal kitchen'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsNothing);
    expect(find.text('Restaurant Profile'), findsOneWidget);
  });

  testWidgets('narrow phone at 2x text scale stays scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Restaurant Profile'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
