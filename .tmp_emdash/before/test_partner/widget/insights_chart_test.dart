// Insights only ever charts what the API truly returns, so the chart kit has
// three states the partner must see distinctly: no data at all (an honest
// empty notice, never an axis-drawing lie), a truncated window (a caption),
// and a populated series. These tests pin all three per widget.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/theme/app_theme.dart';
import 'package:partnerapp/widgets/premium_charts.dart';

Widget wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: SizedBox(width: 360, height: 320, child: child),
  ),
);

List<TrendPoint> trend(int days, {double Function(int i)? value}) => [
  for (var i = 0; i < days; i++)
    TrendPoint(
      date: DateTime(2026, 10, 1).add(Duration(days: i)),
      value: value?.call(i) ?? (i.isEven ? 3 : 5).toDouble(),
    ),
];

void main() {
  group('ChartFrame', () {
    testWidgets('shows the empty notice instead of the child body', (t) async {
      await t.pumpWidget(
        wrap(
          ChartFrame(
            title: 'Reservations per day',
            emptyNotice: 'No reservations in this window',
            child: const Text('should not appear'),
          ),
        ),
      );
      expect(find.text('No reservations in this window'), findsOneWidget);
      expect(find.text('should not appear'), findsNothing);
    });

    testWidgets('renders the child and legend when populated', (t) async {
      await t.pumpWidget(
        wrap(
          ChartFrame(
            title: 'Covers per day',
            subtitle: 'Last 7 days · page truncated at 200 rows',
            legend: const [
              ChartLegendEntry(label: 'Covers', color: Colors.orange),
            ],
            child: const Text('chart body'),
          ),
        ),
      );
      expect(find.text('chart body'), findsOneWidget);
      expect(find.text('Covers'), findsOneWidget);
      // The truncation caption is the partial-window disclosure.
      expect(find.textContaining('truncated'), findsOneWidget);
    });
  });

  group('TrendLineChart', () {
    testWidgets('empty series draws nothing rather than a fake axis', (t) async {
      await t.pumpWidget(wrap(const TrendLineChart(points: [])));
      expect(find.byType(LineChart), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('populated series renders a line chart', (t) async {
      await t.pumpWidget(wrap(TrendLineChart(points: trend(7))));
      expect(find.byType(LineChart), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a flat zero series still scales without dividing by zero',
        (t) async {
      await t.pumpWidget(
        wrap(TrendLineChart(points: trend(5, value: (i) => 0))),
      );
      expect(find.byType(LineChart), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('BarTrendChart', () {
    testWidgets('empty series draws nothing', (t) async {
      await t.pumpWidget(
        wrap(const BarTrendChart(points: [])),
      );
      expect(find.byType(BarChart), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('thins x labels past ten bars without overflowing', (t) async {
      await t.pumpWidget(
        wrap(
          BarTrendChart(
            points: [
              for (var i = 0; i < 30; i++)
                BarPoint(label: 'D$i', value: (i % 5) + 1),
            ],
          ),
        ),
      );
      expect(find.byType(BarChart), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('Sparkline', () {
    testWidgets('renders inline without a frame', (t) async {
      await t.pumpWidget(
        wrap(Center(child: Sparkline(points: [
          TrendPoint(date: srcDay, value: 1),
          TrendPoint(date: srcDay, value: 2),
          TrendPoint(date: srcDay, value: 4),
        ]))),
      );
      expect(find.byType(LineChart), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a single-value (flat) series is safe', (t) async {
      await t.pumpWidget(
        wrap(Center(child: Sparkline(points: [
          TrendPoint(date: srcDay, value: 2),
          TrendPoint(date: srcDay, value: 2),
        ]))),
      );
      expect(t.takeException(), isNull);
    });
  });

  group('RankedBarList', () {
    testWidgets('sorts descending and caps at maxRows', (t) async {
      await t.pumpWidget(
        wrap(
          RankedBarList(
            maxRows: 3,
            points: const [
              BarPoint(label: 'Brunch', value: 4),
              BarPoint(label: 'Tasting', value: 12),
              BarPoint(label: 'Wine night', value: 7),
              BarPoint(label: 'Quiz', value: 1),
            ],
          ),
        ),
      );
      expect(find.text('Tasting'), findsOneWidget);
      expect(find.text('Quiz'), findsNothing); // 4th → cut by maxRows
      // Top-to-bottom order is by value, not input order.
      final positions = ['Tasting', 'Wine night', 'Brunch'].map(
        (l) => t.getTopLeft(find.text(l)).dy,
      ).toList();
      for (final dy in positions) {
        expect(dy, greaterThan(0));
      }
      expect(
        positions,
        orderedEquals(positions.toList()..sort()),
      );
      expect(t.takeException(), isNull);
    });
  });
}

final srcDay = DateTime(2026, 10, 1);
