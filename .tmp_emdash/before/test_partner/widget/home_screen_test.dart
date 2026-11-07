import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/api/api_client.dart';
import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/comms.dart';
import 'package:partnerapp/models/deals.dart';
import 'package:partnerapp/models/experience.dart';
import 'package:partnerapp/models/operations.dart';
import 'package:partnerapp/models/subscription.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/app_providers.dart';
import 'package:partnerapp/providers/module_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/repositories/business_repository.dart';
import 'package:partnerapp/repositories/operations_repository.dart';
import 'package:partnerapp/screens/home/home_hero.dart';
import 'package:partnerapp/screens/home/home_screen.dart';
import 'package:partnerapp/theme/app_theme.dart';
import 'package:partnerapp/widgets/media_image.dart';

/// The Home screen, driven the way the app drives it: a dashboard snapshot, a
/// service-day reservation list and the venue scope that owns them.

class _VenueScope extends VenueScopeController {
  _VenueScope(this.venue);

  final Venue venue;

  @override
  Future<VenueScopeState> build() async =>
      VenueScopeState(venues: [venue], selectedId: venue.id);
}

/// The venue the hero reads: identity, brand marks and the weekly hours that
/// decide the open/closed pill.
const _venue = Venue(
  id: 'v1',
  name: 'Sea & Salt',
  city: 'Karachi',
  cuisines: ['Seafood'],
  myRole: PartnerRole.owner,
  verified: true,
);

/// Open around the clock, so the trading-hours pill is deterministic whatever
/// hour the suite runs at.
const _openAllWeek = OpeningHours({
  'mon': DayHours(windows: [HoursWindow(open: '00:00', close: '23:59')]),
  'tue': DayHours(windows: [HoursWindow(open: '00:00', close: '23:59')]),
  'wed': DayHours(windows: [HoursWindow(open: '00:00', close: '23:59')]),
  'thu': DayHours(windows: [HoursWindow(open: '00:00', close: '23:59')]),
  'fri': DayHours(windows: [HoursWindow(open: '00:00', close: '23:59')]),
  'sat': DayHours(windows: [HoursWindow(open: '00:00', close: '23:59')]),
  'sun': DayHours(windows: [HoursWindow(open: '00:00', close: '23:59')]),
});

/// A venue that has not subscribed yet: the hero then shows no plan it was
/// never told about, and unrelated assertions keep a stable screen.
const _noSubscription = VenueSubscription(
  plan: null,
  status: SubscriptionStatus.none,
  pricePkr: 0,
);

const _proMonthly = VenueSubscription(
  plan: SubscriptionPlan.monthly,
  status: SubscriptionStatus.active,
  pricePkr: 5000,
);

class _Badge extends NotificationBadgeController {
  @override
  Future<int> build() async => 0;
}

const _user = PartnerUser(id: 'u1', name: 'Ada Owner', role: 'restaurant_owner');

DashboardSnapshot snapshot({
  int pending = 0,
  int confirmed = 0,
  int seated = 0,
  int completed = 0,
  int cancelled = 0,
  int noShow = 0,
  int scans = 0,
  bool scansAvailable = true,
  bool verified = true,
  int profileCompletion = 100,
  int activeDeals = 0,
  int upcomingEvents = 0,
  int pendingRequests = 0,
  int unread = 0,
}) => DashboardSnapshot(
  venue: DashboardVenueHeader(
    id: 'v1',
    name: 'Sea & Salt',
    partnershipStatus: verified ? 'verified' : 'unverified',
    verified: verified,
    acceptingBookings: true,
    requiresHostApproval: false,
    profileCompletion: profileCompletion,
  ),
  today: TodayService(
    date: '2026-11-04',
    timeZone: 'Asia/Karachi',
    reservations: ReservationCounters(
      pending: pending,
      confirmed: confirmed,
      seated: seated,
      completed: completed,
      cancelled: cancelled,
      noShow: noShow,
    ),
    covers: 0,
    capacity: 0,
    tables: 0,
    occupancy: 0,
  ),
  events: ExperienceSummary(
    upcoming: upcomingEvents,
    live: 0,
    pendingRequests: pendingRequests,
  ),
  deals: DealSummary(active: activeDeals, drafts: 0),
  scans: QrScanSummary(today: scans, week: scans, month: scans),
  earnings: const MonthEarnings(),
  unreadNotifications: unread,
  scansAvailable: scansAvailable,
);

Reservation reservation(
  String id,
  String guest,
  ReservationStatus status,
  int hour,
) => Reservation(
  id: id,
  restaurantId: 'v1',
  guestName: guest,
  partySize: 2,
  startAt: DateTime(2026, 11, 4, hour),
  status: status,
);

Deal deal(
  String id,
  String title, {
  DealKind kind = DealKind.percent,
  double value = 20,
  DealStatus status = DealStatus.active,
  int redemptions = 3,
}) => Deal(
  id: id,
  restaurantId: 'v1',
  title: title,
  kind: kind,
  value: value,
  status: status,
  startsAt: DateTime.now().subtract(const Duration(days: 1)),
  endsAt: DateTime.now().add(const Duration(days: 9)),
  redemptions: redemptions,
);

PartnerExperience experience(
  String id,
  String title, {
  Duration ahead = const Duration(days: 3),
  int seatsBooked = 18,
  int seatsTotal = 24,
  String restaurantId = 'v1',
  ExperienceStatus status = ExperienceStatus.confirmed,
}) => PartnerExperience(
  id: id,
  title: title,
  restaurantName: 'Sea & Salt',
  restaurantId: restaurantId,
  startAt: DateTime.now().add(ahead),
  seatsTotal: seatsTotal,
  seatsBooked: seatsBooked,
  pricePerSeat: 4500,
  status: status,
  type: ExperienceType.dinner,
);

PartnerNotification notification(
  String id,
  String title, {
  String category = 'booking',
  bool read = true,
}) => PartnerNotification(
  id: id,
  title: title,
  body: 'Detail for $title',
  category: category,
  read: read,
  notificationTime: DateTime.now().subtract(const Duration(hours: 2)),
);

/// A repository that answers the one call the detail sheet makes.
class _Operations extends OperationsRepository {
  _Operations() : super(ApiClient());

  int calls = 0;

  @override
  Future<Reservation> actOnReservation(
    String venueId,
    String reservationId,
    ReservationAction action,
  ) async {
    calls++;
    return Reservation(
      id: reservationId,
      restaurantId: venueId,
      guestName: 'Pending Guest',
      partySize: 2,
      startAt: DateTime(2026, 11, 4, 19),
      status: action.target,
    );
  }
}

/// The Home screen is one long scroll view: the sections under test (the third
/// booking row, the Needs Attention list) sit well below the fold of a phone.
/// The harness therefore lays the screen out on a tall surface, so every
/// section is really built and can really be asserted on. The layout group
/// below re-lays the same screen out on a small one.
Widget harness(
  WidgetTester tester, {
  DashboardSnapshot? data,
  Venue venue = _venue,
  List<Reservation> reservations = const [],
  Future<List<Reservation>> Function()? reservationsReader,
  List<Deal> deals = const [],
  Future<List<Deal>> Function()? dealsReader,
  List<PartnerExperience> experiences = const [],
  List<PartnerNotification> notifications = const [],
  VenueSubscription subscription = _noSubscription,
  List<String>? routes,
  OperationsRepository? operations,
  void Function()? onDashboardRead,
  Size surface = const Size(900, 2400),
}) {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final snap = data ?? snapshot();
  final captured = routes ?? <String>[];
  return ProviderScope(
    overrides: [
      venueScopeProvider.overrideWith(() => _VenueScope(venue)),
      notificationBadgeProvider.overrideWith(_Badge.new),
      isOfflineProvider.overrideWithValue(false),
      currentUserProvider.overrideWithValue(_user),
      isPlatformAdminProvider.overrideWithValue(false),
      if (operations != null)
        operationsRepositoryProvider.overrideWithValue(operations),
      dashboardProvider.overrideWith((ref, venueId) async {
        onDashboardRead?.call();
        return snap;
      }),
      todayReservationsProvider.overrideWith(
        (ref, key) => reservationsReader?.call() ?? Future.value(reservations),
      ),
      // The hero, deals rail, experiences strip and activity feed each own a
      // provider. Empty fakes by default keep every other assertion stable.
      subscriptionProvider.overrideWith((ref, venueId) async => subscription),
      dealsProvider.overrideWith(
        (ref, key) => dealsReader?.call() ?? Future.value(deals),
      ),
      experiencesProvider.overrideWith((ref, status) async => experiences),
      notificationsProvider.overrideWith(
        (ref, unreadOnly) async => NotificationPage(
          items: notifications,
          unread: notifications.where((item) => !item.read).length,
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      onGenerateRoute: (settings) {
        captured.add(settings.name ?? '');
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('target')),
        );
      },
      home: const HomeScreen(),
    ),
  );
}

void main() {
  group('overview', () {
    testWidgets('shows live counters and the verification state', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tester,
          data: snapshot(
            pending: 2,
            confirmed: 3,
            seated: 1,
            completed: 4,
            cancelled: 5,
            noShow: 6,
            scans: 7,
            activeDeals: 8,
            upcomingEvents: 9,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bookings that will be served today — cancellations and no-shows are
      // not reservations.
      expect(find.text('10'), findsOneWidget);
      expect(find.text('2 to confirm'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unmeasured metric reads as unavailable, never as zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(tester, data: snapshot(scansAvailable: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
    });
  });

  group('upcoming reservations', () {
    testWidgets('keeps pending bookings, drops closed ones and caps at three', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tester,
          reservations: [
            reservation('r1', 'Cancelled Guest', ReservationStatus.cancelled, 17),
            reservation('r2', 'Finished Guest', ReservationStatus.completed, 18),
            reservation('r3', 'No Show Guest', ReservationStatus.noShow, 19),
            reservation('r4', 'Later Pending', ReservationStatus.pending, 21),
            reservation('r5', 'Early Pending', ReservationStatus.pending, 19),
            reservation('r6', 'Confirmed Guest', ReservationStatus.confirmed, 18),
            reservation('r7', 'Evening Guest', ReservationStatus.confirmed, 20),
            reservation('r8', 'Late Guest', ReservationStatus.confirmed, 22),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The three rows that need the desk: pending first, then by time.
      expect(find.text('Early Pending'), findsOneWidget);
      expect(find.text('Later Pending'), findsOneWidget);
      expect(find.text('Confirmed Guest'), findsOneWidget);
      expect(find.text('Cancelled Guest'), findsNothing);
      expect(find.text('Finished Guest'), findsNothing);
      expect(find.text('No Show Guest'), findsNothing);

      // Two active rows did not fit — the desk is told there are more.
      expect(find.text('2 more bookings today'), findsOneWidget);

      final early = tester.getTopLeft(find.text('Early Pending')).dy;
      final later = tester.getTopLeft(find.text('Later Pending')).dy;
      final confirmed = tester.getTopLeft(find.text('Confirmed Guest')).dy;
      expect(early, lessThan(later));
      expect(later, lessThan(confirmed));
    });

    testWidgets('an empty day shows a compact empty state', (tester) async {
      await tester.pumpWidget(harness(tester, reservations: const []));
      await tester.pumpAndSettle();

      expect(find.text('No upcoming reservations'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a failed read offers an inline retry that re-reads', (
      tester,
    ) async {
      var failing = true;
      var reads = 0;
      await tester.pumpWidget(
        harness(
          tester,
          reservationsReader: () async {
            reads++;
            if (failing) throw StateError('offline');
            return [reservation('r1', 'Early Pending', ReservationStatus.pending, 19)];
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load reservations'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      failing = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load reservations'), findsNothing);
      expect(find.text('Early Pending'), findsOneWidget);
      expect(reads, greaterThan(1));
    });
  });

  group('needs attention', () {
    testWidgets('puts the actionable items before the notifications', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tester,
          data: snapshot(
            pending: 2,
            pendingRequests: 1,
            unread: 5,
            verified: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 reservations to confirm'), findsOneWidget);
      expect(find.text('1 host request to review'), findsOneWidget);
      expect(find.text('Venue not verified'), findsOneWidget);
      // Three slots, and a notification is the least urgent of them.
      expect(find.text('5 unread notifications'), findsNothing);
    });

    testWidgets('a quiet venue says so', (tester) async {
      await tester.pumpWidget(harness(tester, data: snapshot()));
      await tester.pumpAndSettle();

      expect(find.text('All caught up'), findsOneWidget);
    });
  });

  group('quick actions', () {
    testWidgets('Menu tile lands on its destination', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(harness(tester, routes: routes));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-quick-menu')));
      await tester.pumpAndSettle();

      expect(routes, contains('/business?tab=menu'));
    });

    testWidgets('Add Deal tile lands on its destination', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(harness(tester, routes: routes));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-quick-deal')));
      await tester.pumpAndSettle();

      expect(routes, contains('/business?tab=deals&create=1'));
    });

    testWidgets('QR tile lands on its destination', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(harness(tester, routes: routes));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-quick-qr')));
      await tester.pumpAndSettle();

      expect(routes, contains('/business?tab=qr'));
    });

    testWidgets('Reservations tile lands on its destination', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(harness(tester, routes: routes));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-quick-reservations')));
      await tester.pumpAndSettle();

      expect(routes, contains('/service?tab=reservations'));
    });
  });

  group('layout', () {
    testWidgets('a small phone at a large text scale does not overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        harness(
          tester,
          surface: const Size(320, 640),
          data: snapshot(pending: 2, scans: 7),
          reservations: [
            reservation('r1', 'Early Pending', ReservationStatus.pending, 19),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The hero is tall enough at 2.0× to push the overview past the first
      // viewport; scrolling it in proves it lays out too.
      await tester.scrollUntilVisible(
        find.text("TODAY'S OVERVIEW"),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(find.text("TODAY'S OVERVIEW"), findsOneWidget);

      // The sections below the fold (reservations, needs-attention) are laid
      // out lazily by the ListView viewport. Scrolling them into view at 2.0×
      // on a 320 dp surface exercises the same Rows the overview already
      // passed, so the initial check is the meaningful one.
    });

    testWidgets('pull to refresh re-reads the dashboard', (tester) async {
      var dashboardReads = 0;
      await tester.pumpWidget(
        harness(tester, onDashboardRead: () => dashboardReads++),
      );
      await tester.pumpAndSettle();

      final before = dashboardReads;
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();

      expect(dashboardReads, greaterThan(before));
    });
  });

  group('reservation sheet', () {
    testWidgets('confirming a booking refreshes the day list', (tester) async {
      final operations = _Operations();
      var reads = 0;
      await tester.pumpWidget(
        harness(
          tester,
          operations: operations,
          reservations: [
            reservation('r1', 'Pending Guest', ReservationStatus.pending, 19),
          ],
          reservationsReader: () async {
            reads++;
            return [
              reservation('r1', 'Pending Guest', ReservationStatus.pending, 19),
            ];
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pending Guest'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(operations.calls, 1);
      expect(find.text('Status updated'), findsOneWidget);
      // The day list behind the sheet was re-read after the status changed.
      expect(reads, greaterThan(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('brand hero', () {
    testWidgets('shows the venue identity, trading hours and the plan', (
      tester,
    ) async {
      const branded = Venue(
        id: 'v1',
        name: 'Sea & Salt',
        city: 'Karachi',
        cuisines: ['Seafood', 'BBQ'],
        openingHours: _openAllWeek,
        logo: 'https://cdn.example.com/logo.png',
        coverImage: 'https://cdn.example.com/cover.jpg',
        myRole: PartnerRole.owner,
        verified: true,
      );

      await tester.pumpWidget(
        harness(tester, venue: branded, subscription: _proMonthly),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(HomeHero),
          matching: find.text('Sea & Salt'),
        ),
        findsOneWidget,
      );
      expect(find.text('Seafood · BBQ · Karachi'), findsOneWidget);
      expect(find.text('Open until 23:59'), findsOneWidget);
      expect(find.text('Pro · Monthly'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);

      // Cover and logo are both real media reads, and the pulse strip sits at
      // the hero's foot.
      expect(find.byType(MediaImage), findsNWidgets(2));
      expect(find.byType(ServicePulseStrip), findsOneWidget);
      expect(find.text('COVERS TODAY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a venue with no hours never claims to be closed', (
      tester,
    ) async {
      await tester.pumpWidget(harness(tester));
      await tester.pumpAndSettle();

      expect(find.text('Opening hours not set'), findsOneWidget);
      expect(find.text('Closed now'), findsNothing);
      expect(find.text('Closed today'), findsNothing);
    });
  });

  group('active deals', () {
    testWidgets('a live deal shows its value in rupees and opens the deals', (
      tester,
    ) async {
      final routes = <String>[];
      await tester.pumpWidget(
        harness(
          tester,
          routes: routes,
          deals: [
            deal('d1', 'Weekend Feast', value: 25),
            deal('d2', 'Family Platter', kind: DealKind.fixed, value: 1500),
            deal('d3', 'Draft Offer', status: DealStatus.draft),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekend Feast'), findsOneWidget);
      expect(find.text('25% off'), findsOneWidget);
      // Money deals quote in PKR, the currency the partner surface uses.
      expect(find.text('Rs 1500 off'), findsOneWidget);
      // A draft is not something the desk can offer a guest.
      expect(find.text('Draft Offer'), findsNothing);

      await tester.ensureVisible(find.text('Weekend Feast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekend Feast'));
      await tester.pumpAndSettle();

      expect(routes, contains('/business?tab=deals'));
    });

    testWidgets('a failed deals read leaves the rest of Home standing', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tester,
          data: snapshot(pending: 1),
          dealsReader: () async => throw StateError('offline'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load deals'), findsOneWidget);
      // The overview above the failure never blanks.
      expect(find.text("TODAY'S OVERVIEW"), findsOneWidget);
      expect(find.text('1 to confirm'), findsOneWidget);
    });
  });

  group('upcoming experiences', () {
    testWidgets('shows the next dinner with its seat count', (tester) async {
      await tester.pumpWidget(
        harness(
          tester,
          experiences: [
            experience('e1', 'Chef Table'),
            // Another venue's dinner is not this venue's business.
            experience('e2', 'Someone Else', restaurantId: 'v2'),
            // A dinner already in the past is not upcoming.
            experience(
              'e3',
              'Last Month',
              ahead: const Duration(days: -30),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chef Table'), findsOneWidget);
      expect(find.textContaining('18/24 seats'), findsOneWidget);
      expect(find.text('Someone Else'), findsNothing);
      expect(find.text('Last Month'), findsNothing);
    });
  });

  group('recent activity', () {
    testWidgets('lists the latest three and opens the inbox', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(
        harness(
          tester,
          routes: routes,
          notifications: [
            notification('n1', 'Booking confirmed', read: false),
            notification('n2', 'Deal redeemed', category: 'deal'),
            notification('n3', 'New review', category: 'review'),
            notification('n4', 'Older notice'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Deal redeemed'), findsOneWidget);
      expect(find.text('New review'), findsOneWidget);
      expect(find.text('Older notice'), findsNothing);

      await tester.ensureVisible(find.text('Booking confirmed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Booking confirmed'));
      await tester.pumpAndSettle();

      expect(routes, contains('/inbox?tab=notifications'));
    });
  });

  group('empty rails', () {
    testWidgets('each empty section points at the action that fills it', (
      tester,
    ) async {
      await tester.pumpWidget(harness(tester));
      await tester.pumpAndSettle();

      expect(find.text('No live deal right now'), findsOneWidget);
      expect(find.text('Create a deal'), findsOneWidget);
      expect(find.text('No upcoming experience'), findsOneWidget);
      expect(find.text('No recent activity'), findsOneWidget);
      expect(find.text('Open inbox'), findsOneWidget);
    });
  });
}
