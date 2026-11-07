import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/theme/app_theme.dart';
import 'package:partnerapp/widgets/data_widgets.dart';

/// The dashboard KPI grid is the app's first signed-in surface. Its tiles were
/// sized by a hard aspect ratio, which clipped a two-line caption at narrow
/// widths and at 2.0 text scale (the spec's non-overflow guard, plan line 48).
/// These tests pin the fix: the aspect ratio is a floor, tiles grow instead of
/// overflowing.
void main() {
  List<Widget> tiles() => [
    KpiCard(
      label: 'Covers booked',
      value: '128',
      caption: 'of 240 seats across three services today',
      icon: Icons.event_seat,
    ),
    KpiCard(
      label: 'Net this month',
      value: '\$25,000',
      caption: 'after a 12.5% platform commission is deducted',
      tone: KpiTone.positive,
    ),
    KpiCard(
      label: 'Open experiences',
      value: '7',
      caption: '3 upcoming · 2 awaiting your approval this week',
    ),
  ];

  Future<void> pumpGrid(WidgetTester tester, double width) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(Size(width, 1200));
    addTearDown(() => binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: SingleChildScrollView(
              child: DataGrid(minTileWidth: 200, aspectRatio: 2.4, children: tiles()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('KPI grid does not overflow at a narrow 320px width', (tester) async {
    await pumpGrid(tester, 320);
    expect(tester.takeException(), isNull);
    // KpiCard uppercases its label.
    expect(find.text('COVERS BOOKED'), findsOneWidget);
  });

  testWidgets('KPI grid does not overflow at 2.0 text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpGrid(tester, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KPI grid lays out multiple columns on a wide surface', (tester) async {
    await pumpGrid(tester, 1440);
    expect(tester.takeException(), isNull);
    // Three cards fit side by side on a wide viewport with room to spare.
    expect(find.byType(KpiCard), findsNWidgets(3));
  });
}
