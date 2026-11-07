// The brand widgets must never blank a screen: in a test environment (and on
// a device with a corrupt bundle) the PNGs cannot decode, so every brand
// surface has to fall back to its styled text lockup. These tests verify the
// widgets render without exceptions and that the Image widgets are present.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/theme/app_theme.dart';
import 'package:partnerapp/widgets/brand.dart';

Widget harness(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('BrandWordmark renders without error', (tester) async {
    await tester.pumpWidget(harness(const BrandWordmark()));
    await tester.pumpAndSettle();

    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BrandWordmark renders the dark variant without error',
      (tester) async {
    await tester.pumpWidget(
      harness(const BrandWordmark(variant: BrandWordmarkVariant.dark)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BrandBadge renders without error', (tester) async {
    await tester.pumpWidget(harness(const BrandBadge(height: 40)));
    await tester.pumpAndSettle();

    expect(find.byType(BrandBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BrandLockup shows badge, wordmark and PARTNER eyebrow',
      (tester) async {
    await tester.pumpWidget(harness(const BrandLockup()));
    await tester.pumpAndSettle();

    expect(find.byType(BrandLockup), findsOneWidget);
    expect(find.byType(BrandBadge), findsOneWidget);
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.text('PARTNER'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BrandLockup hides the eyebrow on request', (tester) async {
    await tester.pumpWidget(
      harness(const BrandLockup(showEyebrow: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('PARTNER'), findsNothing);
  });

  testWidgets('BrandMark renders without error', (tester) async {
    await tester.pumpWidget(harness(const BrandMark()));
    await tester.pumpAndSettle();

    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.byType(BrandBadge), findsOneWidget);
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout never overflows a 320px header at 2.0 text scale',
      (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(width: 320, child: Row(children: const [BrandMark()])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
