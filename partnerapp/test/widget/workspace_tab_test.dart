import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/subscription.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/module_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/repositories/venue_repository.dart';
import 'package:partnerapp/screens/business/workspace_tab.dart';
import 'package:partnerapp/theme/app_theme.dart';

/// The workspace is a navigation surface, so the two things a rebuild can
/// silently break are duplicated destinations and a layout that only survives
/// at the designer's screen size. These tests hold both: every shortcut and
/// every row appears exactly once, and the whole page still lays out at 320dp
/// under 2.0 text scaling. Reads are overridden, so nothing here needs a server.
final _venue = Venue(
  id: 'v1',
  name: 'Sea & Salt',
  city: 'Karachi',
  verified: true,
  myRole: PartnerRole.owner,
);

class _Scope extends VenueScopeController {
  _Scope(this._venues, this._selected);

  final List<Venue> _venues;
  final String _selected;

  @override
  Future<VenueScopeState> build() async => VenueScopeState(
    venues: _venues,
    selectedId: _selected,
  );
}

Widget _harness({
  VenueSubscription? subscription,
  bool failSubscription = false,
  String selectedId = 'v1',
  bool noVenue = false,
  double textScale = 1,
}) =>
    ProviderScope(
      overrides: [
        // An empty scope is the only way to reach the "no venue" state, since
        // VenueScopeState.selected falls back to the first venue otherwise.
        venueScopeProvider.overrideWith(
          () => _Scope(noVenue ? const [] : [_venue], noVenue ? '' : selectedId),
        ),
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
        subscriptionProvider.overrideWith((ref, venueId) async {
          if (failSubscription) throw StateError('offline');
          return subscription ??
              VenueSubscription(
                plan: SubscriptionPlan.monthly,
                status: SubscriptionStatus.active,
                pricePkr: 5000,
                periodEnd: DateTime(2026, 12, 31),
                autoRenew: true,
              );
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: WorkspaceTab()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );

void main() {
  testWidgets('identity, shortcuts and lists render with no duplicate route', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // Identity card: name plus role and city, and the verification state. A
    // venue with no configured hours admits it instead of claiming "Closed".
    expect(find.text('Sea & Salt'), findsOneWidget);
    expect(find.text('Owner, Karachi'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Hours not set'), findsOneWidget);

    // Exactly three shortcuts.
    expect(find.text('Restaurant Profile'), findsOneWidget);
    expect(find.text('QR Codes'), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);

    // Section labels, then the destinations that are not already shortcuts.
    expect(find.text('QUICK ACCESS'), findsOneWidget);
    expect(find.text('RESTAURANT MANAGEMENT'), findsOneWidget);
    expect(find.text('BUSINESS OPERATIONS'), findsOneWidget);
    expect(find.text('ACCOUNT AND SUPPORT'), findsOneWidget);
    expect(find.text('Menu Configuration'), findsOneWidget);
    expect(find.text('Booking Policies'), findsOneWidget);
    expect(find.text('Operating Hours'), findsOneWidget);
    expect(find.text('Amenities and Facilities'), findsOneWidget);
    expect(find.text('Reservations Management'), findsOneWidget);
    expect(find.text('Dining Experiences'), findsOneWidget);
    expect(find.text('Check-in'), findsOneWidget);
    expect(find.text('Account settings'), findsOneWidget);
    expect(find.text('Help and Support'), findsOneWidget);

    // Requirement: the shortcut strip and the lists must not repeat each other,
    // because two rows that open the same screen read as a bug, not a feature.
    expect(find.text('Menu Configuration'), findsOneWidget);
    expect(find.text('QR Codes'), findsOneWidget);
  });

  testWidgets('subscription card states plan, price and renewal date', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Monthly plan, PKR 5,000'), findsOneWidget);
    expect(find.text('Renews on 2026-12-31'), findsOneWidget);
    expect(find.text('Manage Subscription'), findsOneWidget);
  });

  testWidgets('a cancelled plan names the end date, not a renewal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        subscription: VenueSubscription(
          plan: SubscriptionPlan.yearly,
          status: SubscriptionStatus.cancelled,
          pricePkr: 50000,
          periodEnd: DateTime(2026, 11, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Yearly plan, PKR 50,000'), findsOneWidget);
    expect(find.text('Ends on 2026-11-30'), findsOneWidget);
    expect(find.textContaining('Renews on'), findsNothing);
  });

  testWidgets('a failed subscription read still leaves the lists usable', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(failSubscription: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The hub's job is navigation, so one slow endpoint cannot hide it.
    expect(find.text('Menu Configuration'), findsOneWidget);
    expect(find.text('Reservations Management'), findsOneWidget);
  });

  testWidgets('no venue selected says so instead of rendering an empty hub', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(noVenue: true));
    await tester.pumpAndSettle();

    expect(find.text('No venue selected'), findsOneWidget);
    expect(find.text('Menu Configuration'), findsNothing);
  });

  testWidgets('lays out at 320dp under 2.0 text scaling, top to bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_harness(textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sea & Salt'), findsOneWidget);

    // The lower groups only lay out once scrolled into view, which is exactly
    // where a narrow screen with large text would overflow.
    for (var step = 0; step < 6; step++) {
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'overflow at scroll step $step');
    }

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Manage Subscription'), findsOneWidget);
  });
}
