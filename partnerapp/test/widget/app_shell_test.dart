import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/navigation/app_routes.dart';
import 'package:partnerapp/providers/app_providers.dart';
import 'package:partnerapp/providers/module_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/widgets/app_shell.dart';
import 'package:partnerapp/widgets/brand.dart';

class _VenueScope extends VenueScopeController {
  @override
  Future<VenueScopeState> build() async => const VenueScopeState(
    venues: [
      Venue(id: 'v1', name: 'Sea & Salt', city: 'Karachi', myRole: PartnerRole.owner),
      Venue(id: 'v2', name: 'The Fold', city: 'Lahore', myRole: PartnerRole.manager),
    ],
    selectedId: 'v1',
  );
}

class _Badge extends NotificationBadgeController {
  @override
  Future<int> build() async => 0;
}

const _user = PartnerUser(id: 'u1', name: 'Ada Owner', role: 'restaurant_owner');

Widget _harness(Size logicalSize) => ProviderScope(
  overrides: [
    venueScopeProvider.overrideWith(_VenueScope.new),
    notificationBadgeProvider.overrideWith(_Badge.new),
    isOfflineProvider.overrideWithValue(false),
    currentUserProvider.overrideWithValue(_user),
    isPlatformAdminProvider.overrideWithValue(false),
  ],
  child: MaterialApp(
    // The real surface is sized to the widest case; this override is what
    // AppLayout actually reads, so the branch decision is exact while the
    // layout engine always has room (never a spurious overflow from lying
    // bigger than the viewport).
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: logicalSize),
      child: child!,
    ),
    home: AppShell(
      active: PrimaryDestination.business,
      title: 'Business',
      child: ListView(
        children: const [SizedBox(height: 400, child: Center(child: Text('Body')))],
      ),
    ),
  ),
);

/// Sizes the real test surface to the largest breakpoint so no branch can
/// overflow the viewport, then drives [AppLayout] purely through the
/// overridden MediaQuery size passed to [_harness].
Future<void> _pumpAt(
  WidgetTester tester,
  Size logicalSize, {
  Size realSurface = const Size(1440, 1000),
}) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(realSurface);
  addTearDown(() => binding.setSurfaceSize(null));
  await tester.pumpWidget(_harness(logicalSize));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('compact (<600) uses a bottom navigation bar', (tester) async {
    await _pumpAt(tester, const Size(320, 900));

    expect(find.byType(NavigationBar), findsOneWidget);
    // Exactly the five agreed tabs render in the bar, in order.
    for (final label in ['Home', 'Menu', 'Deals', 'Insights', 'Business']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    expect(find.text('DineCircle'), findsNothing); // sidebar brand absent
    expect(find.byType(BrandLockup), findsNothing); // brand widget absent
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact really laid out at 320px with 2.0 text scale does not overflow',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // Real surface and MediaQuery agree at 320, so this is a genuine tight
    // layout, not just a branch decision — the spec's key overflow guard.
    await _pumpAt(
      tester,
      const Size(320, 900),
      realSurface: const Size(320, 900),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium (600–1023) uses a rail drawer, not the bar', (tester) async {
    await _pumpAt(tester, const Size(800, 1000));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('DineCircle'), findsNothing);
    expect(find.byType(BrandLockup), findsNothing);
    expect(find.text('Body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded (>=1024) shows the grouped sidebar', (tester) async {
    await _pumpAt(tester, const Size(1440, 1000));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BrandLockup), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'expanded really laid out at 1024px with 2.0 text scale does not overflow',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // The fixed-width sidebar brand row is the spec's tight case at large text
    // scale; real surface and MediaQuery agree so the layout is genuine.
    await _pumpAt(
      tester,
      const Size(1024, 900),
      realSurface: const Size(1024, 900),
    );

    expect(find.byType(BrandLockup), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
