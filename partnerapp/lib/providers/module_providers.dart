import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/catalog.dart';
import '../models/comms.dart';
import '../models/deals.dart';
import '../models/experience.dart';
import '../models/finance.dart';
import '../models/operations.dart';
import '../models/subscription.dart';
import '../models/venue.dart';
import '../repositories/business_repository.dart';
import '../repositories/operations_repository.dart';
import '../repositories/venue_repository.dart';
import 'app_providers.dart';

/// Reads, one provider per surface.
///
/// Every list is `autoDispose` + `family` on the arguments that actually change
/// the payload, so switching venue or date re-reads without a manual refresh and
/// a stale screen can never show another venue's rows. Mutations go straight to
/// a repository and then `ref.invalidate` the affected provider — writes are
/// never optimistic, because the same rows are live in the customer app.

// ── Venue & account ──────────────────────────────────────────────────────────

final venueDetailProvider = FutureProvider.autoDispose.family<VenueDetail, String>(
  (ref, venueId) => ref.watch(venueRepositoryProvider).venue(venueId),
);

final dashboardProvider =
    FutureProvider.autoDispose.family<DashboardSnapshot, String>(
      (ref, venueId) => ref.watch(venueRepositoryProvider).dashboard(venueId),
    );

final staffProvider =
    FutureProvider.autoDispose.family<List<StaffMember>, String>(
      (ref, venueId) => ref.watch(venueRepositoryProvider).staff(venueId),
    );

final branchesProvider =
    FutureProvider.autoDispose.family<List<Branch>, String>(
      (ref, venueId) => ref.watch(venueRepositoryProvider).branches(venueId),
    );

final branchHoursProvider =
    FutureProvider.autoDispose.family<BranchHours, ({String venue, String branch})>(
      (ref, key) =>
          ref.watch(venueRepositoryProvider).branchHours(key.venue, key.branch),
    );

final verificationQueueProvider = FutureProvider.autoDispose<List<VerificationRequest>>(
  (ref) => ref.watch(venueRepositoryProvider).verificationQueue(),
);

// ── Catalogue ────────────────────────────────────────────────────────────────

final menuProvider =
    FutureProvider.autoDispose.family<List<MenuSection>, String>(
      (ref, venueId) => ref.watch(menuRepositoryProvider).menu(venueId),
    );

/// Account-wide: the special-menu route is not venue-scoped, so packages from
/// every operated venue appear together and the list is labelled as such.
final packagesProvider = FutureProvider.autoDispose<List<DiningPackage>>(
  (ref) => ref.watch(menuRepositoryProvider).packages(),
);

final tablesProvider =
    FutureProvider.autoDispose.family<List<DiningTable>, String>(
      (ref, venueId) => ref.watch(operationsRepositoryProvider).tables(venueId),
    );

final availabilityProvider = FutureProvider.autoDispose
    .family<DayAvailability, ({String venue, String date, int partySize})>(
      (ref, key) => ref
          .watch(operationsRepositoryProvider)
          .availability(key.venue, date: key.date, partySize: key.partySize),
    );

// ── Desk operations ──────────────────────────────────────────────────────────

final reservationsProvider = FutureProvider.autoDispose
    .family<List<Reservation>, ({String venue, String? date, String? status})>(
      (ref, key) => ref
          .watch(operationsRepositoryProvider)
          .reservations(
            key.venue,
            ReservationQuery(date: key.date, status: key.status),
          ),
    );

/// Reservations for one service day, keyed by the *server's* `today.date` (the
/// dashboard resolves it in the venue's timezone). Computing the day from the
/// device clock would show the wrong list to a desk in another zone.
final todayReservationsProvider = FutureProvider.autoDispose
    .family<List<Reservation>, ({String venue, String date})>(
      (ref, key) => ref
          .watch(operationsRepositoryProvider)
          .reservations(key.venue, ReservationQuery(date: key.date)),
    );

final bookingsProvider = FutureProvider.autoDispose
    .family<List<PartnerBooking>, ({String? eventId, String? status})>(
      (ref, key) => ref
          .watch(operationsRepositoryProvider)
          .bookings(eventId: key.eventId, status: key.status),
    );

// ── Experiences ──────────────────────────────────────────────────────────────

final experiencesProvider = FutureProvider.autoDispose
    .family<List<PartnerExperience>, String?>(
      (ref, status) =>
          ref.watch(experienceRepositoryProvider).experiences(status: status),
    );

final eventRequestsProvider = FutureProvider.autoDispose
    .family<List<ExperienceRequest>, ({String venue, String status})>(
      (ref, key) => ref
          .watch(experienceRepositoryProvider)
          .requests(key.venue, status: key.status),
    );

final hostSummaryProvider =
    FutureProvider.autoDispose.family<HostProfile, String>(
      (ref, hostId) =>
          ref.watch(experienceRepositoryProvider).hostSummary(hostId),
    );

final eventThreadProvider =
    FutureProvider.autoDispose.family<List<EventMessage>, String>(
      (ref, eventId) => ref
          .watch(experienceRepositoryProvider)
          .thread(eventId, currentUserId: ref.watch(currentUserProvider)?.id ?? ''),
    );

// ── Money & performance ──────────────────────────────────────────────────────

final dealsProvider = FutureProvider.autoDispose
    .family<List<Deal>, ({String venue, String? status})>(
      (ref, key) => ref
          .watch(businessRepositoryProvider)
          .deals(key.venue, DealQuery(status: key.status)),
    );

/// Range is carried as ISO strings so the family key is stable across rebuilds
/// (a `DateTime` key would re-read on every microsecond change of `now`).
final earningsProvider = FutureProvider.autoDispose
    .family<EarningsReport, ({String venue, String? from, String? to})>(
      (ref, key) => ref.watch(businessRepositoryProvider).earnings(
        key.venue,
        from: key.from == null ? null : DateTime.parse(key.from!),
        to: key.to == null ? null : DateTime.parse(key.to!),
      ),
    );

final payoutsProvider = FutureProvider.autoDispose
    .family<List<PayoutRecord>, ({String venue, int page})>(
      (ref, key) => ref
          .watch(businessRepositoryProvider)
          .payouts(key.venue, page: key.page),
    );

final analyticsProvider = FutureProvider.autoDispose<AnalyticsSnapshot>(
  (ref) => ref.watch(businessRepositoryProvider).analytics(),
);

// ── Subscription ─────────────────────────────────────────────────────────────

final subscriptionProvider =
    FutureProvider.autoDispose.family<VenueSubscription, String>(
  (ref, venueId) =>
      ref.watch(venueRepositoryProvider).subscription(venueId),
);

// ── Guests & inbox ───────────────────────────────────────────────────────────

final reviewsProvider =
    FutureProvider.autoDispose.family<List<PartnerReview>, String>(
      (ref, eventId) =>
          ref.watch(businessRepositoryProvider).reviewsForEvent(eventId),
    );

/// Venue-scoped review feed (primary path per Phase 1d).
final venueReviewsProvider =
    FutureProvider.autoDispose.family<List<PartnerReview>, String>(
      (ref, restaurantId) =>
          ref.watch(businessRepositoryProvider).reviewsForVenue(restaurantId),
    );

final notificationsProvider =
    FutureProvider.autoDispose.family<NotificationPage, bool>(
      (ref, unreadOnly) => ref
          .watch(businessRepositoryProvider)
          .notifications(unreadOnly: unreadOnly),
    );

final ticketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(businessRepositoryProvider).tickets(),
);

final reportsProvider = FutureProvider.autoDispose<List<ReportCase>>(
  (ref) => ref.watch(businessRepositoryProvider).reports(),
);

// ── Foreground polling ───────────────────────────────────────────────────────

/// There is no push endpoint on the partner surface, so the badge is kept live
/// by re-reading notifications on a timer while the app is in the foreground.
/// The cadence is a device preference, not a server setting.
final notificationPollSecondsProvider = StateProvider<int>((ref) => 60);

final notificationBadgeProvider =
    AsyncNotifierProvider<NotificationBadgeController, int>(
      NotificationBadgeController.new,
    );

class NotificationBadgeController extends AsyncNotifier<int> {
  Timer? _timer;

  @override
  Future<int> build() async {
    _startTimer();
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<int> _fetch() async {
    final page = await ref
        .read(businessRepositoryProvider)
        .notifications(unreadOnly: true);
    return page.unread;
  }

  void _startTimer() {
    _timer?.cancel();
    final seconds = ref.watch(notificationPollSecondsProvider);
    if (seconds <= 0) return;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => refresh());
  }

  /// Manual pull-to-refresh and the shell's refresh action both land here, so
  /// the badge and the inbox list stay consistent with one read.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
    ref.invalidate(notificationsProvider);
  }

  Future<void> markAll() async {
    await ref.read(businessRepositoryProvider).markAllNotificationsRead();
    await refresh();
  }

  Future<void> markOne(String notificationId) async {
    await ref
        .read(businessRepositoryProvider)
        .markNotificationRead(notificationId);
    await refresh();
  }
}

/// Live connectivity, so the shell can show one banner instead of every screen
/// discovering the outage separately on its next request.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  final plugin = Connectivity();
  return plugin.onConnectivityChanged;
});

final isOfflineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityProvider).valueOrNull;
  if (results == null) return false;
  return results.every((r) => r == ConnectivityResult.none);
});
