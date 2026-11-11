import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/api/api_client.dart';
import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/collab.dart';
import 'package:partnerapp/models/experience.dart';
import 'package:partnerapp/models/operations.dart';
import 'package:partnerapp/models/subscription.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/app_providers.dart';
import 'package:partnerapp/providers/module_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/repositories/operations_repository.dart';
import 'package:partnerapp/screens/home/home_hero.dart';
import 'package:partnerapp/screens/home/home_screen.dart';
import 'package:partnerapp/screens/home/home_widgets.dart';
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

/// The venue the header reads: identity, brand marks and the weekly hours that
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

/// A venue that has not subscribed yet: the header then shows no plan it was
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
  int tables = 0,
  int capacity = 0,
  bool verified = true,
  int profileCompletion = 100,
  int activeDeals = 0,
  int upcomingEvents = 0,
  int pendingRequests = 0,
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
    capacity: capacity,
    tables: tables,
    occupancy: 0,
  ),
  events: ExperienceSummary(
    upcoming: upcomingEvents,
    live: 0,
    pendingRequests: pendingRequests,
  ),
  deals: DealSummary(active: activeDeals, drafts: 0),
  scans: QrScanSummary(),
  earnings: const MonthEarnings(),
  unreadNotifications: 0,
  scansAvailable: true,
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

/// A host's proposal at this venue (`…/event-requests`).
ExperienceRequest hostRequest(
  String id,
  String title, {
  String hostName = 'Imran Host',
  ExperienceStatus status = ExperienceStatus.requested,
}) => ExperienceRequest(
  id: id,
  title: title,
  hostId: 'host-$id',
  hostName: hostName,
  startAt: DateTime.now().add(const Duration(days: 6)),
  seatsTotal: 20,
  seatsBooked: 4,
  seatsLeft: 16,
  pricePerSeat: 3500,
  status: status,
  type: ExperienceType.dinner,
);

/// One side of the collaboration inbox (`…/collab-proposals`).
CollabProposal invitation(
  String id,
  String title, {
  ProposalDirection direction = ProposalDirection.outgoing,
  ProposalStatus status = ProposalStatus.invited,
  String hostName = 'Sara Host',
}) => CollabProposal(
  id: id,
  title: title,
  direction: direction,
  status: status,
  host: ProposalHost(id: 'host-$id', name: hostName),
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
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
/// booking row, the Needs attention list) sit well below the fold of a phone.
/// The harness therefore lays the screen out on a tall surface, so every
/// section is really built and can really be asserted on. The layout group
/// below re-lays the same screen out on a small one.
Widget harness(
  WidgetTester tester, {
  DashboardSnapshot? data,
  Venue venue = _venue,
  List<Reservation> reservations = const [],
  Future<List<Reservation>> Function()? reservationsReader,
  List<PartnerExperience> experiences = const [],
  Future<List<PartnerExperience>> Function()? experiencesReader,
  List<ExperienceRequest> hostRequests = const [],
  List<CollabProposal> proposals = const [],
  Future<List<CollabProposal>> Function()? proposalsReader,
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
      subscriptionProvider.overrideWith((ref, venueId) async => subscription),
      // The Experiences card owns three reads: the event feed, the host
      // requests this venue received and the invitations it sent.
      experiencesProvider.overrideWith(
        (ref, status) =>
            experiencesReader?.call() ?? Future.value(experiences),
      ),
      eventRequestsProvider.overrideWith(
        (ref, key) async =>
            key.status == 'requested' ? hostRequests : const <ExperienceRequest>[],
      ),
      collabProposalsProvider.overrideWith(
        (ref, key) => proposalsReader?.call() ?? Future.value(proposals),
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
    testWidgets('shows the four operational counters', (tester) async {
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
            tables: 12,
            capacity: 40,
            activeDeals: 8,
            upcomingEvents: 9,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bookings that will be served today; cancellations and no-shows are not
      // reservations.
      expect(find.text('10'), findsOneWidget);
      expect(find.text('2 to confirm'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('of 40 seats'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps financial panels and notification feeds off Home', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tester,
          data: snapshot(pending: 1, activeDeals: 2, upcomingEvents: 3),
        ),
      );
      await tester.pumpAndSettle();

      // Money belongs to Insights, deals management to Deals, the feed to the
      // inbox the header bell already opens.
      expect(find.textContaining('Gross'), findsNothing);
      expect(find.textContaining('Refunds'), findsNothing);
      expect(find.textContaining('Net'), findsNothing);
      expect(find.text('QR Scans'), findsNothing);
      expect(find.text('Recent activity'), findsNothing);
      expect(find.text('Active deals'), findsNothing);
    });

    testWidgets('an unconfigured table plan says so instead of a dead zero', (
      tester,
    ) async {
      await tester.pumpWidget(harness(tester));
      await tester.pumpAndSettle();

      expect(find.text('Not set up'), findsOneWidget);
      expect(find.text('None live'), findsOneWidget);
      expect(find.text('None upcoming'), findsOneWidget);
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

      // Two active rows did not fit, the desk is told there are more.
      expect(find.text('2 more bookings today'), findsOneWidget);

      final early = tester.getTopLeft(find.text('Early Pending')).dy;
      final later = tester.getTopLeft(find.text('Later Pending')).dy;
      final confirmed = tester.getTopLeft(find.text('Confirmed Guest')).dy;
      expect(early, lessThan(later));
      expect(later, lessThan(confirmed));
    });

    testWidgets('an empty day shows one compact line', (tester) async {
      await tester.pumpWidget(harness(tester, reservations: const []));
      await tester.pumpAndSettle();

      expect(find.text('No reservations today'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      // The empty state is a row, not a paragraph: it never explains how
      // reservations are created on the screen a busy venue opens at service.
      expect(find.textContaining('Share your QR'), findsNothing);
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
            return [
              reservation('r1', 'Early Pending', ReservationStatus.pending, 19),
            ];
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
    testWidgets('lists the decisions the desk owes, most urgent first', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tester,
          data: snapshot(
            pending: 2,
            pendingRequests: 1,
            verified: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 reservations to confirm'), findsOneWidget);
      expect(find.text('1 host request to review'), findsOneWidget);
      expect(find.text('Venue not verified'), findsOneWidget);

      final bookings = tester.getTopLeft(find.text('2 reservations to confirm')).dy;
      final hosts = tester.getTopLeft(find.text('1 host request to review')).dy;
      final verified = tester.getTopLeft(find.text('Venue not verified')).dy;
      expect(bookings, lessThan(hosts));
      expect(hosts, lessThan(verified));
    });

    testWidgets('renders nothing at all when nothing is owed', (tester) async {
      await tester.pumpWidget(harness(tester, data: snapshot()));
      await tester.pumpAndSettle();

      // No permanent "all caught up" card: the row is returned to the board.
      expect(find.text('Needs attention'), findsNothing);
      expect(find.text('All caught up'), findsNothing);
    });
  });

  group('quick actions', () {
    testWidgets('Reservations tile lands on the day board', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(harness(tester, routes: routes));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-quick-reservations')));
      await tester.pumpAndSettle();

      expect(routes, contains('/service?tab=reservations'));
    });

    testWidgets('Menu tile lands on its destination', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(harness(tester, routes: routes));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-quick-menu')));
      await tester.pumpAndSettle();

      expect(routes, contains('/business?tab=menu'));
    });

    testWidgets('Create Deal tile lands on its destination', (tester) async {
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

    testWidgets('carries the four actions the desk needs, and no others', (
      tester,
    ) async {
      await tester.pumpWidget(harness(tester));
      await tester.pumpAndSettle();

      expect(find.text('Reservations'), findsNWidgets(2));
      expect(find.text('Edit Menu'), findsOneWidget);
      expect(find.text('Create Deal'), findsOneWidget);
      expect(find.text('Show QR'), findsOneWidget);
      // Creating an experience lives in the Experiences section, where the
      // evening book can explain what an empty one needs.
      expect(find.text('Create Experience'), findsNothing);
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
          data: snapshot(pending: 2, tables: 6, activeDeals: 1),
          reservations: [
            reservation('r1', 'Early Pending', ReservationStatus.pending, 19),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text("Today's Overview"),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(find.text("Today's Overview"), findsOneWidget);
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

    testWidgets('a phone shows the numbers, not a blank band under the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tester,
          surface: const Size(412, 915),
          data: snapshot(
            pending: 2,
            tables: 8,
            activeDeals: 3,
            upcomingEvents: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // The regression this holds shut: a KPI tile whose shell could not size
      // itself inside a scroll view collapsed to nothing, and Home read as a
      // header, one label, and a wall of black. Every tile has to carry real
      // geometry on a phone.
      // Scoped to the overview: 'Reservations' and 'Experiences' also name a
      // quick action and a section, and getRect only accepts one match.
      for (final label in [
        'Reservations',
        'Tables',
        'Active Deals',
        'Experiences',
      ]) {
        final rect = tester.getRect(
          find.descendant(
            of: find.byType(TodaysOverview),
            matching: find.text(label),
          ),
        );
        expect(rect.width, greaterThan(40), reason: label);
        expect(rect.height, greaterThan(8), reason: label);
      }
      for (final key in [
        'home-quick-reservations',
        'home-quick-menu',
        'home-quick-deal',
        'home-quick-qr',
      ]) {
        final tile = find.byKey(ValueKey(key));
        expect(tile, findsOneWidget, reason: key);
        final rect = tester.getRect(tile);
        expect(rect.width, greaterThan(100), reason: key);
        // The desk operates this with one thumb, standing up, in a dining room.
        expect(rect.height, greaterThanOrEqualTo(44), reason: key);
      }

      // And the header spends well under a third of the screen on branding, so
      // the first numbers are on screen the moment the dashboard answers.
      expect(tester.getRect(find.byType(HomeHero)).height, lessThan(200));
      expect(tester.getRect(find.text("Today's Overview")).top, lessThan(300));
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

  group('restaurant header', () {
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

      // One brand mark, and no second service pulse repeating the KPI counters.
      expect(find.byType(MediaImage), findsOneWidget);
      expect(find.text('COVERS TODAY'), findsNothing);
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

  group('experiences', () {
    testWidgets('summarises dinners and open proposals in one card', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tester,
          experiences: [
            experience('e1', 'Chef Table'),
            // Another venue's dinner is not this venue's business.
            experience('e2', 'Someone Else', restaurantId: 'v2'),
            // A dinner already in the past is not upcoming.
            experience('e3', 'Last Month', ahead: const Duration(days: -30)),
          ],
          hostRequests: [hostRequest('r1', 'Coastal Supper')],
          proposals: [invitation('p1', 'Late-night tasting')],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-exp-count-upcoming')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-exp-count-to-review')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-exp-count-awaiting')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );

      // Two rows only: the decision the desk owes, then the next dinner.
      expect(find.text('Coastal Supper'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-exp-request-r1')),
          matching: find.text('Your decision'),
        ),
        findsOneWidget,
      );
      expect(find.text('Chef Table'), findsOneWidget);
      expect(find.textContaining('18/24 seats'), findsOneWidget);
      expect(find.text('Someone Else'), findsNothing);
      expect(find.text('Last Month'), findsNothing);
      // The invitation is counted, but Home does not list it: the inbox does.
      expect(find.text('Late-night tasting'), findsNothing);
    });

    testWidgets('a host request opens the requests inbox', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(
        harness(
          tester,
          routes: routes,
          hostRequests: [hostRequest('r1', 'Coastal Supper')],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-exp-request-r1')));
      await tester.pumpAndSettle();

      expect(routes, contains('/experiences?tab=requests'));
    });

    testWidgets('the counters open the surface that owns them', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(
        harness(tester, routes: routes, proposals: [invitation('p1', 'Tasting')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-exp-count-awaiting')));
      await tester.pumpAndSettle();

      expect(routes, contains('/experiences?tab=proposals'));
    });

    testWidgets('an empty book shows one honest state', (tester) async {
      await tester.pumpWidget(harness(tester));
      await tester.pumpAndSettle();

      expect(find.text('No experiences yet'), findsOneWidget);
      expect(find.text('Create experience'), findsOneWidget);
    });

    testWidgets('a failed dinner read keeps the proposals on screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          tester,
          hostRequests: [hostRequest('r1', 'Coastal Supper')],
          experiencesReader: () => Future.error(Exception('offline')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coastal Supper'), findsOneWidget);
      // The half that failed reads as unknown, and says so.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-exp-count-upcoming')),
          matching: find.text('-'),
        ),
        findsOneWidget,
      );
      expect(find.text('Some experiences could not load.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('View all opens the evening book', (tester) async {
      final routes = <String>[];
      await tester.pumpWidget(harness(tester, routes: routes));
      await tester.pumpAndSettle();

      final link = find.descendant(
        of: find.byKey(const ValueKey('home-experiences')),
        matching: find.text('View all'),
      );
      expect(link, findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();

      expect(routes, contains('/experiences?tab=experiences'));
    });
  });
}
