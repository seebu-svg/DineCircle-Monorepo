// The premium kit is the shell every rewritten screen is built from, so it
// must survive the two hostile cases the spec pins: a 320dp phone and that
// same phone at 2.0 text scale. Anything that overflows here will overflow in
// production, on real devices, in front of a partner.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/theme/app_theme.dart';
import 'package:partnerapp/widgets/premium_cards.dart';

Widget kit() => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HeroPanel(
        title: 'Sea & Salt',
        eyebrow: 'PARTNER VENUE',
        subtitle: 'Good evening · Tuesday, 3 November',
        trailing: const Icon(Icons.storefront, size: 20),
      ),
      const SizedBox(height: 12),
      SectionTitle(
        title: 'Performance',
        overline: 'TODAY',
        trailing: TextButton(onPressed: () {}, child: const Text('See all')),
      ),
      PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            StatTile(
              label: 'Reservations',
              value: '12',
              caption: '3 pending · 9 confirmed',
              icon: Icons.event_available,
            ),
            MetricRow(label: 'Net revenue', value: 'PKR 45,000'),
            DeltaPill(value: 4.5),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ActionGrid(
        tiles: const [
          ActionTile(label: 'Add Menu Item', icon: Icons.add),
          ActionTile(label: 'Create Deal', icon: Icons.local_offer),
          ActionTile(label: 'View QR', icon: Icons.qr_code_2),
          ActionTile(label: 'Reservations', icon: Icons.event_available),
          ActionTile(label: 'Business Hours', icon: Icons.schedule),
        ],
        onTap: (_) {},
      ),
      const SizedBox(height: 12),
      const ProgressMeter(
        percent: 0.6,
        label: 'Occupancy · 40% (24/60 seats)',
      ),
      const SizedBox(height: 12),
      PlanCard(
        name: 'Yearly',
        priceLabel: 'PKR 50,000',
        periodLabel: 'per year',
        features: const ['Unlimited menu items', 'Priority support'],
        badge: 'Save PKR 10,000',
        selected: true,
        onTap: () {},
      ),
    ],
  ),
);

Future<void> pumpKit(WidgetTester tester, {double? scale}) async {
  if (scale != null) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(const Size(320, 1400));
  addTearDown(() => binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: kit()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the full kit renders at 320dp', (tester) async {
    await pumpKit(tester);
    expect(find.text('Sea & Salt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the full kit renders at 320dp with 2.0 text scale',
      (tester) async {
    await pumpKit(tester, scale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HeroPanel renders statically when animations are disabled',
      (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(
              body: HeroPanel(title: 'No motion', subtitle: 'reduced'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No motion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ActionGrid reports the tapped tile index', (tester) async {
    final taps = <int>[];
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ActionGrid(
            tiles: const [
              ActionTile(label: 'One', icon: Icons.looks_one),
              ActionTile(label: 'Two', icon: Icons.looks_two),
              ActionTile(label: 'Three', icon: Icons.looks_3),
              ActionTile(label: 'Four', icon: Icons.looks_4),
            ],
            onTap: taps.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Three'));
    await tester.pump();
    expect(taps, [2]);
  });

  testWidgets('PremiumCard onTap fires and accent renders', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: PremiumCard(
              accent: Colors.amber,
              onTap: () => tapped++,
              child: const Text('Body'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Body'));
    expect(tapped, 1);
  });

  testWidgets('StatTile uppercases the label and keeps the caption',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: StatTile(
              label: 'covers',
              value: '24',
              caption: 'of 60 seats',
            ),
          ),
        ),
      ),
    );
    expect(find.text('COVERS'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('of 60 seats'), findsOneWidget);
  });
}
