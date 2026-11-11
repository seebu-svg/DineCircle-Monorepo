import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/operations.dart';
import '../../navigation/app_routes.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/async_views.dart';
import '../auth/auth_gate.dart';
import 'home_hero.dart';
import 'home_sections.dart';
import 'home_widgets.dart';

/// Home reads as an operating brief rather than a menu of counters.
///
/// Order:
/// 1. Restaurant header - logo, venue name, date, verification and hours
/// 2. Today's Overview - reservations, tables, active deals, experiences
/// 3. Quick Actions - Reservations, Edit Menu, Create Deal, Show QR
/// 4. Today's Reservations - the next three active bookings
/// 5. Experiences - upcoming dinners and open host proposals in one card
/// 6. Needs Attention - present only when the desk owes a decision
///
/// What Home deliberately does not carry: monthly gross, net and refunds (they
/// live in Insights, where the commission and the period selector are), the
/// full deals list (Deals), the notifications feed (the header bell and the
/// inbox) and a permanent "all caught up" card. Each of those was a second
/// copy of a surface that already exists, and together they pushed the booking
/// board off the first screen of the busiest page in the app.
///
/// Every async section owns its loading and error state, so one failed read
/// never blanks the screen or evicts a neighbouring section.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueId = ref.watch(selectedVenueIdProvider);
    if (venueId.isEmpty) return const AuthGate();

    final snapshot = ref.watch(dashboardProvider(venueId));

    return AppShell(
      active: PrimaryDestination.home,
      // No notifications action here: the shell header already carries the
      // bell with the live unread badge, and two bells a thumb-width apart
      // both going to the same inbox is one control too many.
      child: snapshot.when(
        loading: () => const HomeSkeleton(),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.paddingScreen),
          children: [
            const SizedBox(height: 120),
            ErrorView(
              error: error,
              onRetry: () => ref.invalidate(dashboardProvider(venueId)),
            ),
          ],
        ),
        data: (data) => HomeBody(data: data, venueId: venueId),
      ),
    );
  }
}

class HomeBody extends ConsumerStatefulWidget {
  const HomeBody({super.key, required this.data, required this.venueId});

  final DashboardSnapshot data;
  final String venueId;

  @override
  ConsumerState<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<HomeBody>
    with WidgetsBindingObserver {
  Timer? _autoRefresh;

  DashboardSnapshot get data => widget.data;
  String get venueId => widget.venueId;

  /// Reservations are keyed by the *server's* service day, so a desk in another
  /// timezone still reads the right board.
  ({String venue, String date}) get _reservationsKey =>
      (venue: venueId, date: data.today.date);

  /// The two proposal reads Home shows: what hosts have asked this venue, and
  /// what this venue has asked hosts. Keeping the same family keys here means
  /// the timer refreshes exactly what the sections watch, with no third read.
  ({String venue, String status}) get _requestsKey =>
      (venue: venueId, status: 'requested');

  ({String venue, String? direction}) get _proposalsKey =>
      (venue: venueId, direction: 'outgoing');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause the timer when the app is backgrounded, resume on foreground.
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
    } else {
      _autoRefresh?.cancel();
    }
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      _silentRefresh();
    });
  }

  /// Silent background refresh: invalidates providers but does not await them,
  /// so the UI never flashes a loading spinner on a timer.
  void _silentRefresh() {
    ref.invalidate(dashboardProvider(venueId));
    ref.invalidate(todayReservationsProvider(_reservationsKey));
    ref.invalidate(experiencesProvider(null));
    ref.invalidate(eventRequestsProvider(_requestsKey));
    ref.invalidate(collabProposalsProvider(_proposalsKey));
  }

  /// The same family keys the sections watch, so a pull refreshes exactly what
  /// is on screen. `dashboardProvider` and today's reservations are awaited
  /// because the spinner should live until the header and the booking rail are
  /// real; the evening card resolves on its own skeleton.
  Future<void> _refresh() async {
    ref.invalidate(dashboardProvider(venueId));
    ref.invalidate(todayReservationsProvider(_reservationsKey));
    ref.invalidate(subscriptionProvider(venueId));
    ref.invalidate(experiencesProvider(null));
    ref.invalidate(eventRequestsProvider(_requestsKey));
    ref.invalidate(collabProposalsProvider(_proposalsKey));
    try {
      await ref.read(dashboardProvider(venueId).future);
    } catch (_) {}
    try {
      await ref.read(todayReservationsProvider(_reservationsKey).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final reservations = ref.watch(todayReservationsProvider(_reservationsKey));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        // A day with no rows still has to pull: without always-scrollable
        // physics the empty Home cannot be refreshed at all.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppLayout.screenPadding(context)
            .copyWith(bottom: AppSpacing.xl),
        children: [
          // ── Restaurant header ───────────────────────────────────────────
          HomeHero(snapshot: data),

          // ── Today's Overview - 4 KPI tiles ──────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          TodaysOverview(snapshot: data),

          // ── Quick Actions ───────────────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          const QuickActionsSection(),

          // ── Today's Reservations ────────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          TodaysReservationsSection(
            reservations: reservations,
            venueId: venueId,
            onRetry: () =>
                ref.invalidate(todayReservationsProvider(_reservationsKey)),
          ),

          // ── Experiences - dinners and proposals in one card ─────────────
          const SizedBox(height: AppSpacing.lg),
          ExperiencesSection(venueId: venueId),

          // ── Needs Attention - renders nothing when nothing is owed ──────
          NeedsAttentionSection(snapshot: data),
        ],
      ),
    );
  }
}
