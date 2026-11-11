import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/catalog.dart';
import '../models/collab.dart';
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
import 'venue_scope_provider.dart';

/// Reads, one provider per surface.
///
/// Every list is `autoDispose` + `family` on the arguments that actually change
/// the payload, so switching venue or date re-reads without a manual refresh and
/// a stale screen can never show another venue's rows. Mutations go straight to
/// a repository and then `ref.invalidate` the affected provider, writes are
/// never optimistic, because the same rows are live in the customer app.

// ── Venue & account ──────────────────────────────────────────────────────────

final venueDetailProvider = FutureProvider.autoDispose
    .family<VenueDetail, String>(
      (ref, venueId) => ref.watch(venueRepositoryProvider).venue(venueId),
    );

final dashboardProvider = FutureProvider.autoDispose
    .family<DashboardSnapshot, String>(
      (ref, venueId) => ref.watch(venueRepositoryProvider).dashboard(venueId),
    );

final staffProvider = FutureProvider.autoDispose
    .family<List<StaffMember>, String>(
      (ref, venueId) => ref.watch(venueRepositoryProvider).staff(venueId),
    );

final branchesProvider = FutureProvider.autoDispose
    .family<List<Branch>, String>(
      (ref, venueId) => ref.watch(venueRepositoryProvider).branches(venueId),
    );

final branchHoursProvider = FutureProvider.autoDispose
    .family<BranchHours, ({String venue, String branch})>(
      (ref, key) =>
          ref.watch(venueRepositoryProvider).branchHours(key.venue, key.branch),
    );

final verificationQueueProvider =
    FutureProvider.autoDispose<List<VerificationRequest>>(
      (ref) => ref.watch(venueRepositoryProvider).verificationQueue(),
    );

// ── Catalogue ────────────────────────────────────────────────────────────────

final menuProvider = FutureProvider.autoDispose
    .family<List<MenuSection>, String>(
      (ref, venueId) => ref.watch(menuRepositoryProvider).menu(venueId),
    );

/// Account-wide: the special-menu route is not venue-scoped, so packages from
/// every operated venue appear together and the list is labelled as such.
final packagesProvider = FutureProvider.autoDispose<List<DiningPackage>>(
  (ref) => ref.watch(menuRepositoryProvider).packages(),
);

final tablesProvider = FutureProvider.autoDispose
    .family<List<DiningTable>, String>(
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

/// One request opened in full, for the decision sheet.
///
/// Keyed on both the venue and the event so a venue switch can never leave the
/// previous venue's menu on screen.
final eventRequestDetailProvider = FutureProvider.autoDispose
    .family<ExperienceRequest, ({String venue, String request})>(
      (ref, key) => ref
          .watch(experienceRepositoryProvider)
          .eventRequestDetail(key.venue, key.request),
    );

/// The key the Proposals tab renders: the unfiltered feed.
///
/// The tab reads every row once and splits it by direction locally, so that one
/// read is the only entry it has to refresh. Sending a proposal from host
/// discovery must invalidate exactly this key; hand-built records compare by
/// value, so `(venue: v, direction: 'outgoing')` is a different cache entry and
/// would leave the outbox showing the list from before the send.
({String venue, String? direction}) proposalFeedKey(String venueId) =>
    (venue: venueId, direction: null);

/// The venue's collaboration proposals, keyed by direction.
///
/// The desk asks two different questions of them: "what do I have to answer"
/// (incoming) and "what am I waiting on" (outgoing), so callers key the read
/// rather than filtering one shared list. Both are always scoped to the
/// selected venue, so a venue switch can never show another kitchen's inbox.
final collabProposalsProvider = FutureProvider.autoDispose
    .family<List<CollabProposal>, ({String venue, String? direction})>(
      (ref, key) => ref
          .watch(experienceRepositoryProvider)
          .proposals(
            key.venue,
            direction: key.direction == null
                ? null
                : ProposalDirection.parse(key.direction),
          ),
    );

final hostSummaryProvider = FutureProvider.autoDispose
    .family<HostProfile, String>(
      (ref, hostId) =>
          ref.watch(experienceRepositoryProvider).hostSummary(hostId),
    );

/// Hosts this venue can propose to, keyed by the search term.
final discoverHostsProvider = FutureProvider.autoDispose
    .family<List<DiscoverableHost>, ({String venue, String query})>(
      (ref, key) => ref
          .watch(experienceRepositoryProvider)
          .discoverHosts(key.venue, query: key.query),
    );

final eventThreadProvider = FutureProvider.autoDispose
    .family<List<EventMessage>, String>(
      (ref, eventId) => ref
          .watch(experienceRepositoryProvider)
          .thread(
            eventId,
            currentUserId: ref.watch(currentUserProvider)?.id ?? '',
          ),
    );

// ── Money & performance ──────────────────────────────────────────────────────

final dealsProvider = FutureProvider.autoDispose
    .family<List<Deal>, ({String venue, String? status})>(
      // The page ceiling rather than the server's default of 50: the deals
      // screen counts every status from this one read, and home and the QR tab
      // take a slice of the same rows.
      (ref, key) => ref
          .watch(businessRepositoryProvider)
          .deals(key.venue, DealQuery(status: key.status, limit: kDealPageLimit)),
    );

/// Range is carried as ISO strings so the family key is stable across rebuilds
/// (a `DateTime` key would re-read on every microsecond change of `now`).
final earningsProvider = FutureProvider.autoDispose
    .family<EarningsReport, ({String venue, String? from, String? to})>(
      (ref, key) => ref
          .watch(businessRepositoryProvider)
          .earnings(
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

/// The experience row ceiling the Insights screen reads at.
const int kInsightsEventPageLimit = 200;

/// One window of table reservations for Insights, with the server's total.
///
/// Keys are ISO strings for the same reason [earningsProvider] uses them: a
/// `DateTime` key would re-read on every microsecond change of `now`.
final insightsReservationsProvider = FutureProvider.autoDispose
    .family<ReservationWindow, ({String venue, String from, String to})>(
      (ref, key) => ref
          .watch(operationsRepositoryProvider)
          .reservationWindow(
            key.venue,
            from: DateTime.parse(key.from),
            to: DateTime.parse(key.to),
          ),
    );

/// The selected venue's experiences.
///
/// `/partner/events` is account-wide, so the answer arrives as every operated
/// venue's events; each row carries its `restaurantId`, and this provider keeps
/// the ones that belong to [venueId]. Reading the account feed at its ceiling
/// keeps a multi-venue account from hiding this venue's older experiences
/// behind another venue's newer ones.
///
/// A server that does not stamp the owner id on each row is attributed by the
/// venue name instead. Without that, every row would be dropped and the
/// Experiences card would report a confident zero for a venue that has events.
/// The id is authoritative whenever the feed carries one.
final insightsExperiencesProvider = FutureProvider.autoDispose
    .family<List<PartnerExperience>, String>((ref, venueId) async {
      final rows = await ref
          .watch(experienceRepositoryProvider)
          .experiences(limit: kInsightsEventPageLimit);
      if (rows.any((row) => row.restaurantId.isNotEmpty)) {
        return rows
            .where((row) => row.restaurantId == venueId)
            .toList(growable: false);
      }
      // Await the scope: reading it synchronously would see an unresolved
      // venue on the first frame and answer an empty list that never retries.
      final scope = await ref.watch(venueScopeProvider.future);
      final name = scope.selected?.name.trim() ?? '';
      if (name.isEmpty) return const [];
      return rows
          .where((row) => row.restaurantName.trim() == name)
          .toList(growable: false);
    });

// ── Subscription ─────────────────────────────────────────────────────────────

final subscriptionProvider = FutureProvider.autoDispose
    .family<VenueSubscription, String>(
      (ref, venueId) =>
          ref.watch(venueRepositoryProvider).subscription(venueId),
    );

// ── Guests & inbox ───────────────────────────────────────────────────────────

final reviewsProvider = FutureProvider.autoDispose
    .family<List<PartnerReview>, String>(
      (ref, eventId) =>
          ref.watch(businessRepositoryProvider).reviewsForEvent(eventId),
    );

/// Venue-scoped review feed (primary path per Phase 1d).
final venueReviewsProvider = FutureProvider.autoDispose
    .family<List<PartnerReview>, String>(
      (ref, restaurantId) =>
          ref.watch(businessRepositoryProvider).reviewsForVenue(restaurantId),
    );

final notificationsProvider = FutureProvider.autoDispose
    .family<NotificationPage, bool>(
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
