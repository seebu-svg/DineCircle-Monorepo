import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/models/deals.dart';
import 'package:partnerapp/models/experience.dart';
import 'package:partnerapp/models/operations.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/module_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/screens/business/analytics_tab.dart';
import 'package:partnerapp/screens/business/insights_widgets.dart';
import 'package:partnerapp/theme/app_theme.dart';

/// The Insights screen, driven the way the app drives it: a venue scope, one
/// window of table reservations, the dashboard's scan counters, the venue's
/// offers and its experiences.
///
/// The assertions are deliberately about *attribution and period* as much as
/// layout: this screen exists because the previous one showed lifetime,
/// account-wide figures under a seven-day label.

const _venue = Venue(
  id: 'v1',
  name: 'Sea & Salt',
  city: 'Karachi',
  verified: true,
);

class _VenueScope extends VenueScopeController {
  @override
  Future<VenueScopeState> build() async =>
      const VenueScopeState(venues: [_venue], selectedId: 'v1');
}

DateTime _day(int back, int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - back, hour);
}

Reservation _booking(
  String id,
  String guest,
  ReservationStatus status,
  DateTime startAt, {
  int party = 2,
  DateTime? createdAt,
}) => Reservation(
  id: id,
  restaurantId: 'v1',
  guestName: guest,
  partySize: party,
  startAt: startAt,
  status: status,
  createdAt: createdAt ?? startAt,
);

/// Five bookings inside the last week, one of them cancelled.
List<Reservation> _bookings() => [
  _booking(
    'r1',
    'Ayesha Khan',
    ReservationStatus.confirmed,
    _day(0, 19),
    party: 4,
    createdAt: _day(0, 9),
  ),
  _booking(
    'r2',
    'Bilal Ahmed',
    ReservationStatus.confirmed,
    _day(1, 20),
  ),
  _booking(
    'r3',
    'Chen Wei',
    ReservationStatus.seated,
    _day(2, 13),
  ),
  _booking(
    'r4',
    'Dana Malik',
    ReservationStatus.cancelled,
    _day(3, 19),
  ),
  _booking(
    'r5',
    'Eli Santos',
    ReservationStatus.completed,
    _day(5, 20),
  ),
];

Deal _deal(
  String id,
  String title, {
  int redemptions = 0,
  int? maxRedemptions,
  bool reported = true,
}) => Deal(
  id: id,
  restaurantId: 'v1',
  title: title,
  kind: DealKind.percent,
  value: 20,
  status: DealStatus.active,
  startsAt: _day(10, 12),
  endsAt: _day(-20, 23),
  redemptions: redemptions,
  redemptionsReported: reported,
  maxRedemptions: maxRedemptions,
);

List<Deal> _deals() => [
  _deal('d1', 'Late-night tasting menu', redemptions: 12, maxRedemptions: 40),
  _deal('d2', 'Weekend brunch for two', redemptions: 5, maxRedemptions: 20),
  _deal('d3', 'Chef’s table upgrade', redemptions: 3),
];

PartnerExperience _experience(
  String id,
  String title, {
  required DateTime startAt,
  int seatsBooked = 18,
  int seatsTotal = 24,
  ExperienceStatus status = ExperienceStatus.confirmed,
}) => PartnerExperience(
  id: id,
  title: title,
  restaurantName: 'Sea & Salt',
  restaurantId: 'v1',
  startAt: startAt,
  seatsTotal: seatsTotal,
  seatsBooked: seatsBooked,
  pricePerSeat: 4500,
  status: status,
  type: ExperienceType.dinner,
);

List<PartnerExperience> _experiences() => [
  _experience('e1', 'Chef’s Table', startAt: _day(2, 19)),
  _experience(
    'e2',
    'Harbour Supper Club',
    startAt: _day(-5, 19),
    seatsBooked: 4,
    seatsTotal: 20,
  ),
];

DashboardSnapshot _snapshot({QrScanSummary? scans, bool scansAvailable = true}) =>
    DashboardSnapshot(
      venue: const DashboardVenueHeader(
        id: 'v1',
        name: 'Sea & Salt',
        partnershipStatus: 'verified',
        verified: true,
        acceptingBookings: true,
        requiresHostApproval: false,
        profileCompletion: 100,
      ),
      today: const TodayService(
        date: '2026-11-11',
        timeZone: 'Asia/Karachi',
        reservations: ReservationCounters(pending: 1, confirmed: 2),
        covers: 8,
        capacity: 40,
        tables: 10,
        occupancy: 0.2,
      ),
      events: const ExperienceSummary(upcoming: 1, pendingRequests: 0),
      deals: const DealSummary(active: 3),
      scans: scans ?? const QrScanSummary(today: 3, week: 41, month: 96),
      earnings: const MonthEarnings(),
      unreadNotifications: 0,
      scansAvailable: scansAvailable,
    );

/// Wraps the tab in the smallest app it needs: a theme, a route recorder and
/// the venue scope. Text scale is applied through [MaterialApp.builder] so it
/// reaches every `MediaQuery.textScalerOf` read inside the screen.
Widget harness(
  WidgetTester tester, {
  Size surface = const Size(1000, 3600),
  double textScale = 1,
  DashboardSnapshot? dashboard,
  Future<DashboardSnapshot> Function()? dashboardReader,
  ReservationWindow? window,
  Future<ReservationWindow> Function()? windowReader,
  ReservationWindow Function(({String venue, String from, String to}) key)?
      windowFor,
  List<Deal> deals = const [],
  Future<List<Deal>> Function()? dealsReader,
  List<PartnerExperience> experiences = const [],
  Future<List<PartnerExperience>> Function()? experiencesReader,
  List<({String venue, String from, String to})>? keys,
  List<String>? routes,
}) {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final snapshot = dashboard ?? _snapshot();
  final data = window ??
      ReservationWindow(reservations: _bookings(), total: _bookings().length);
  final captured = routes ?? <String>[];

  return ProviderScope(
    overrides: [
      venueScopeProvider.overrideWith(_VenueScope.new),
      insightsReservationsProvider.overrideWith((ref, key) {
        keys?.add(key);
        final reader = windowReader;
        if (reader != null) return reader();
        return Future.value(windowFor?.call(key) ?? data);
      }),
      dashboardProvider.overrideWith(
        (ref, venueId) => dashboardReader?.call() ?? Future.value(snapshot),
      ),
      dealsProvider.overrideWith(
        (ref, key) => dealsReader?.call() ?? Future.value(deals),
      ),
      insightsExperiencesProvider.overrideWith(
        (ref, venueId) =>
            experiencesReader?.call() ?? Future.value(experiences),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      onGenerateRoute: (settings) {
        captured.add(settings.name ?? '');
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('target')),
        );
      },
      home: const Scaffold(body: AnalyticsTab()),
    ),
  );
}

/// Drags the whole page, so every lazily built section is really laid out.
Future<void> drain(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'overflow after drag $i');
  }
  await tester.pumpAndSettle();
}

Future<void> selectRange(WidgetTester tester, String label) async {
  // The chips live in a pinned band, so they are always on screen vertically;
  // `ensureVisible` on a pinned sliver would scroll the page far past where the
  // chip actually sits. Only the rail itself needs a horizontal nudge, because
  // a chip past the fold is not built until it scrolls in.
  final rail = find.byType(InsightsRangeRail);
  if (find.text(label).evaluate().isEmpty) {
    await tester.drag(
      find.descendant(of: rail, matching: find.byType(ListView)),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Brings a lazily built sliver child into the viewport.
Future<void> revealOnPage(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    220,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// Reads one figure off the KPI grid, so a test asserts the number the card
/// holds rather than any text on the page with the same digits (an axis label
/// can carry the same value as a total).
InsightsKpi _kpi(WidgetTester tester, String label) {
  final grid = tester.widget<InsightsKpiGrid>(find.byType(InsightsKpiGrid));
  return grid.figures.firstWhere(
    (figure) => figure.label == label,
    orElse: () => fail('no "$label" figure in ${grid.figures.map((f) => f.label)}'),
  );
}

String kpiValue(WidgetTester tester, String label) => _kpi(tester, label).value;

String kpiCaption(WidgetTester tester, String label) =>
    _kpi(tester, label).caption;

/// The "Held" figure of the experiences strip, whichever range labels it.
String heldFigure(WidgetTester tester) {
  for (final strip
      in tester.widgetList<InsightsFigureStrip>(find.byType(InsightsFigureStrip))) {
    for (final figure in strip.figures) {
      if ((figure.hint ?? '').startsWith('Held in')) return figure.value;
    }
  }
  fail('no experiences figure strip on the page');
}

void main() {
  testWidgets('renders identity, every figure and the five supported sections',
      (tester) async {
    await tester.pumpWidget(
      harness(tester, deals: _deals(), experiences: _experiences()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Insights'), findsOneWidget);
    expect(
      find.textContaining('How DineCircle is bringing guests'),
      findsOneWidget,
    );
    expect(find.textContaining('reservations and experiences'), findsOneWidget);

    // Four compact figures, each carrying its own period.
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('QR scans'), findsOneWidget);
    expect(find.text('Deal redemptions'), findsOneWidget);
    expect(find.text('Experiences'), findsOneWidget);
    expect(find.text('4'), findsWidgets); // the venue's bookings this week
    // The scan figure appears twice on purpose: the KPI above the fold and the
    // seven-day cell of the QR section.
    expect(find.text('41'), findsNWidgets(2));
    expect(find.text('20'), findsOneWidget); // lifetime deal redemptions
    expect(find.text('7 days · booked'), findsOneWidget);
    expect(find.text('Last 7 days · menu'), findsOneWidget);
    expect(find.text('All time · 3 offers'), findsOneWidget);
    expect(find.text('7 days · hosted'), findsOneWidget);

    // Sections.
    expect(find.text('Reservation trends'), findsOneWidget);
    expect(find.text('Deal performance'), findsOneWidget);
    expect(find.text('QR engagement'), findsOneWidget);
    expect(find.text('Experiences performance'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
    expect(find.byType(ReservationTrendChart), findsOneWidget);
    expect(find.textContaining('Busiest:'), findsOneWidget);
    expect(find.text('12 of 40'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.textContaining('Next: Harbour Supper Club'), findsOneWidget);

    // Recent activity is capped at three, newest booking first.
    expect(find.byType(RecentReservationList), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.text('Bilal Ahmed'), findsOneWidget);
    expect(find.text('Chen Wei'), findsOneWidget);
    expect(find.text('Eli Santos'), findsNothing);
    expect(find.text('View all'), findsOneWidget);
  });

  testWidgets('the range chips re-read the window and relabel every period',
      (tester) async {
    final keys = <({String venue, String from, String to})>[];
    await tester.pumpWidget(
      harness(tester, keys: keys, deals: _deals(), experiences: _experiences()),
    );
    await tester.pumpAndSettle();

    expect(keys, hasLength(1));
    expect(keys.first.venue, 'v1');

    await selectRange(tester, '30 days');
    expect(keys.length, greaterThan(1));
    expect(keys.last.from, isNot(keys.first.from));
    expect(find.text('30 days · booked'), findsOneWidget);
    expect(find.text('30 days · hosted'), findsOneWidget);

    await selectRange(tester, '90 days');
    expect(find.textContaining('booked per week'), findsOneWidget);
    expect(find.text('90 days · booked'), findsOneWidget);
    // The scan counters stop at 30 days, and the card says so.
    expect(find.text('Not tracked past 30 days'), findsOneWidget);
    expect(find.text('Last 7 days · menu'), findsNothing);
  });

  testWidgets('all three ranges change the figures, the chart and the list',
      (tester) async {
    // A window whose size is its range: 7, 30 or 90 bookings, all on today, so
    // the busiest column, the KPI and the recent list each have to move with
    // the chip.
    ReservationWindow rangeWindow(
      ({String venue, String from, String to}) key,
    ) {
      final days = DateTime.parse(key.to)
              .difference(DateTime.parse(key.from))
              .inDays;
      final rows = [
        for (var i = 0; i < days; i++)
          _booking(
            'r$days-$i',
            '${days}d Guest $i',
            ReservationStatus.confirmed,
            _day(0, 19),
            createdAt: _day(0, 12).subtract(Duration(minutes: i)),
          ),
      ];
      return ReservationWindow(reservations: rows, total: rows.length);
    }

    await tester.pumpWidget(
      harness(
        tester,
        windowFor: rangeWindow,
        deals: _deals(),
        experiences: [
          _experience('e1', 'Chef’s Table', startAt: _day(3, 19)),
          _experience('e2', 'Quarterly Dinner', startAt: _day(45, 19)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 7 days.
    expect(kpiValue(tester, 'Reservations'), '7');
    expect(find.text('7d Guest 0'), findsOneWidget);
    expect(find.text('30d Guest 0'), findsNothing);
    expect(heldFigure(tester), '1');
    expect(find.text('Held in 7 days'), findsOneWidget);

    // 30 days: same card, a month of rows, the same single held experience.
    await selectRange(tester, '30 days');
    expect(kpiValue(tester, 'Reservations'), '30');
    expect(find.text('30 days · booked'), findsOneWidget);
    expect(find.text('30d Guest 0'), findsOneWidget);
    expect(find.text('7d Guest 0'), findsNothing);
    expect(heldFigure(tester), '1');
    expect(find.text('Held in 30 days'), findsOneWidget);

    // 90 days: weekly buckets and the second experience enters the window.
    await selectRange(tester, '90 days');
    expect(kpiValue(tester, 'Reservations'), '90');
    expect(find.text('90 days · booked'), findsOneWidget);
    expect(find.textContaining('booked per week'), findsOneWidget);
    expect(find.text('90d Guest 0'), findsOneWidget);
    expect(heldFigure(tester), '2');
    expect(find.text('Held in 90 days'), findsOneWidget);
    expect(find.text('No experiences ran in this window.'), findsNothing);
  });

  testWidgets('a short range stays empty while a longer one has rows',
      (tester) async {
    ReservationWindow rangeWindow(
      ({String venue, String from, String to}) key,
    ) {
      final days = DateTime.parse(key.to)
              .difference(DateTime.parse(key.from))
              .inDays;
      if (days <= 7) {
        return const ReservationWindow(reservations: [], total: 0);
      }
      return ReservationWindow(
        reservations: [
          _booking(
            'r-$days',
            'Booked $days days ago',
            ReservationStatus.confirmed,
            _day(10, 19),
            createdAt: _day(2, 10),
          ),
        ],
        total: 1,
      );
    }

    await tester.pumpWidget(
      harness(tester, windowFor: rangeWindow, deals: _deals()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No bookings in this window yet. Try a longer range.'),
      findsOneWidget,
    );
    expect(kpiValue(tester, 'Reservations'), '0');

    await selectRange(tester, '30 days');
    expect(find.text('Booked 30 days ago'), findsOneWidget);
    expect(find.byType(ReservationTrendChart), findsOneWidget);
    expect(kpiValue(tester, 'Reservations'), '1');

    // Back to the short window: it is empty again, not stuck on month data.
    await selectRange(tester, '7 days');
    expect(find.text('Booked 30 days ago'), findsNothing);
    expect(
      find.text('No bookings in this window yet. Try a longer range.'),
      findsOneWidget,
    );
  });

  testWidgets('scan and experience failures stay inside their own cards',
      (tester) async {
    await tester.pumpWidget(
      harness(
        tester,
        dashboardReader: () => Future.error(Exception('scans offline')),
        experiencesReader: () => Future.error(Exception('events offline')),
        deals: _deals(),
      ),
    );
    await tester.pumpAndSettle();

    expect(kpiCaption(tester, 'QR scans'), 'Unavailable');
    expect(kpiCaption(tester, 'Experiences'), 'Unavailable');
    expect(find.text('QR scan counters could not be read.'), findsOneWidget);
    expect(find.text('Experiences could not be read.'), findsOneWidget);
    // The reservation read succeeded, so its chart and list are untouched.
    expect(find.byType(ReservationTrendChart), findsOneWidget);
    expect(find.byType(RecentReservationList), findsOneWidget);
  });

  testWidgets('pull to refresh re-reads all four sources', (tester) async {
    var windows = 0;
    var dashboards = 0;
    var deals = 0;
    var experiences = 0;

    await tester.pumpWidget(
      harness(
        tester,
        windowReader: () async {
          windows++;
          return ReservationWindow(
            reservations: _bookings(),
            total: _bookings().length,
          );
        },
        dashboardReader: () async {
          dashboards++;
          return _snapshot();
        },
        dealsReader: () async {
          deals++;
          return _deals();
        },
        experiencesReader: () async {
          experiences++;
          return _experiences();
        },
      ),
    );
    await tester.pumpAndSettle();
    expect([windows, dashboards, deals, experiences], [1, 1, 1, 1]);

    // Drive the indicator's own callback: the gesture arm is Flutter's, and a
    // synthetic overscroll in a test viewport is a flaky way to reach it.
    final indicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await indicator.onRefresh();
    await tester.pumpAndSettle();

    expect([windows, dashboards, deals, experiences], [2, 2, 2, 2]);
  });

  testWidgets('empty reads show zeroes and empty states, never invented data',
      (tester) async {
    await tester.pumpWidget(
      harness(
        tester,
        window: const ReservationWindow(reservations: [], total: 0),
        dashboard: _snapshot(scans: const QrScanSummary()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No bookings in this window yet. Try a longer range.'),
      findsOneWidget,
    );
    expect(find.text('No bookings in this window yet.'), findsOneWidget);
    expect(
      find.textContaining('No offers yet. Create one from Deals'),
      findsOneWidget,
    );
    expect(
      find.text('No experiences for this restaurant yet.'),
      findsOneWidget,
    );
    expect(find.byType(ReservationTrendChart), findsNothing);
    expect(find.byType(RecentReservationList), findsNothing);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('no earnings, commission or payout figure is presented',
      (tester) async {
    await tester.pumpWidget(
      harness(tester, deals: _deals(), experiences: _experiences()),
    );
    await tester.pumpAndSettle();
    await drain(tester);

    final money = RegExp(r'Rs\.?\s?\d|PKR|₨|\$\s?\d');
    expect(find.textContaining(money), findsNothing);
    expect(find.textContaining('revenue'), findsOneWidget); // the disclaimer
    expect(find.textContaining('No earnings are shown'), findsOneWidget);
    expect(find.textContaining('commission'), findsNothing);
    expect(find.textContaining('payout'), findsNothing);
  });

  testWidgets('a failed reservation read stays inside its own sections',
      (tester) async {
    await tester.pumpWidget(
      harness(
        tester,
        windowReader: () => Future.error(Exception('offline')),
        deals: _deals(),
        experiences: _experiences(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Reservation trends could not be read.'),
      findsOneWidget,
    );
    expect(find.text('Recent bookings could not be read.'), findsOneWidget);
    expect(find.text('Try again'), findsNWidgets(2));
    expect(find.text('Unavailable'), findsNWidgets(1));
    // The other sections still render their data.
    expect(find.text('12 of 40'), findsOneWidget);
    expect(find.text('Last 7 days · menu'), findsOneWidget);
  });

  testWidgets('first load shows the skeleton until the reads answer',
      (tester) async {
    await tester.pumpWidget(
      harness(
        tester,
        windowReader: () => Completer<ReservationWindow>().future,
        dashboardReader: () => Completer<DashboardSnapshot>().future,
        dealsReader: () => Completer<List<Deal>>().future,
        experiencesReader: () => Completer<List<PartnerExperience>>().future,
      ),
    );
    await tester.pump();

    expect(find.byType(InsightsSkeleton), findsOneWidget);
    expect(find.text('Reservations'), findsNothing);
  });

  testWidgets('View all hands the reservations list back to Service',
      (tester) async {
    final routes = <String>[];
    await tester.pumpWidget(
      harness(tester, routes: routes, deals: _deals(), experiences: _experiences()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('View all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();
    expect(routes, contains('/service?tab=reservations'));
  });

  testWidgets('small screen, long labels and a 90-day window do not overflow',
      (tester) async {
    final longTitle =
        'Three-course late-night tasting menu with paired drinks for two';
    await tester.pumpWidget(
      harness(
        tester,
        surface: const Size(320, 640),
        deals: [
          _deal('d1', longTitle, redemptions: 1200, maxRedemptions: 4000),
          _deal('d2', longTitle, redemptions: 8, maxRedemptions: 20),
          _deal('d3', longTitle, redemptions: 4),
          _deal('d4', longTitle, redemptions: 2),
        ],
        experiences: _experiences(),
      ),
    );
    await tester.pumpAndSettle();
    await selectRange(tester, '90 days');
    expect(find.text('Insights'), findsOneWidget);
    await revealOnPage(tester, find.textContaining('booked per week'));
    expect(find.textContaining('booked per week'), findsOneWidget);
    // Read the deal section before `drain`: the last drag parks the page at its
    // end, where a section above the fold is no longer built.
    await revealOnPage(tester, find.byType(DealRedemptionList));
    expect(find.byType(DealRedemptionList), findsOneWidget);
    await drain(tester);
  });

  testWidgets('a 2x text scale on a phone lays out without overflow',
      (tester) async {
    await tester.pumpWidget(
      harness(
        tester,
        surface: const Size(360, 720),
        textScale: 2,
        deals: _deals(),
        experiences: _experiences(),
      ),
    );
    await tester.pumpAndSettle();
    await selectRange(tester, '90 days');

    expect(find.text('Insights'), findsOneWidget);
    await revealOnPage(tester, find.text('Reservation trends'));
    expect(find.byType(ReservationTrendChart), findsOneWidget);

    await drain(tester);
  });

  test('no gridline is ever labelled with the value of another', () {
    // One booking used to print 1, 1, 0: the half step was rounded up to the
    // ceiling and the middle rule read as the top one.
    expect(axisLabels(1), const [
      (fraction: 1.0, value: 1),
      (fraction: 0.0, value: 0),
    ]);
    expect(axisLabels(2).map((tick) => tick.value), [2, 1, 0]);
    expect(axisLabels(3).map((tick) => tick.value), [3, 0]);
    expect(axisLabels(15).map((tick) => tick.value), [15, 0]);
    for (var ceiling = 1; ceiling <= 60; ceiling++) {
      final values = axisLabels(ceiling).map((tick) => tick.value).toList();
      expect(values.toSet().length, values.length, reason: 'ceiling $ceiling');
    }
  });
}
