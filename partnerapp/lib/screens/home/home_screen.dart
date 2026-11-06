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
/// 1. Venue hero - brand, open/closed, subscription, service pulse
/// 2. Today's Overview - 4 KPI tiles, each tapping through to its section
/// 3. Quick Actions - Menu, Deal, QR Code, Reservations
/// 4. Upcoming Reservations - the next three active bookings
/// 5. Active Deals - what the desk can offer a guest right now
/// 6. Upcoming Experiences - the next two dinners this venue hosts
/// 7. Needs Attention - actionable items first, unread notifications last
/// 8. Recent Activity - the last three notifications
///
/// Every async section owns its loading and error state, so one failed read
/// never blanks the screen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueId = ref.watch(selectedVenueIdProvider);
    if (venueId.isEmpty) return const AuthGate();

    final snapshot = ref.watch(dashboardProvider(venueId));

    return AppShell(
      active: PrimaryDestination.home,
      title: 'Home',
      actions: [
        ShellAction(
          icon: Icons.notifications_outlined,
          label: 'Notifications',
          onPressed: () => _openNotifications(context, venueId),
        ),
      ],
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

  void _openNotifications(BuildContext context, String venueId) {
    Navigator.of(context).pushNamed('${AppRoute.inbox}?tab=notifications');
  }
}

class HomeBody extends ConsumerWidget {
  const HomeBody({super.key, required this.data, required this.venueId});

  final DashboardSnapshot data;
  final String venueId;

  ({String venue, String date}) get _key =>
      (venue: venueId, date: data.today.date);

  /// The same family keys the sections watch, so a pull refreshes exactly what
  /// is on screen. `dashboardProvider` and today's reservations are awaited
  /// because the spinner should live until the identity block and the booking
  /// rail are real; the secondary rails resolve on their own skeletons.
  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardProvider(venueId));
    ref.invalidate(todayReservationsProvider(_key));
    ref.invalidate(subscriptionProvider(venueId));
    ref.invalidate(dealsProvider((venue: venueId, status: 'active')));
    ref.invalidate(experiencesProvider(null));
    ref.invalidate(notificationsProvider(false));
    try {
      await ref.read(dashboardProvider(venueId).future);
    } catch (_) {}
    try {
      await ref.read(todayReservationsProvider(_key).future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = ref.watch(todayReservationsProvider(_key));

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        // A day with no rows still has to pull: without always-scrollable
        // physics the empty Home cannot be refreshed at all.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppLayout.screenPadding(context).copyWith(bottom: AppSpacing.xl),
        children: [
          // ── Brand hero + service pulse ──────────────────────────────────
          HomeHero(snapshot: data),

          // ── Today's Overview - 4 KPI tiles ──────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          TodaysOverview(snapshot: data),

          // ── Quick Actions ───────────────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          const QuickActionsSection(),

          // ── Upcoming Reservations ───────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          TodaysReservationsSection(
            reservations: reservations,
            venueId: venueId,
            onRetry: () => ref.invalidate(todayReservationsProvider(_key)),
          ),

          // ── Active Deals ────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          ActiveDealsRail(venueId: venueId),

          // ── Upcoming Experiences ────────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          UpcomingExperiencesStrip(venueId: venueId),

          // ── Needs Attention ─────────────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          NeedsAttentionSection(snapshot: data),

          // ── Recent Activity ─────────────────────────────────────────────
          const SizedBox(height: AppSpacing.lg),
          const RecentActivitySection(),
        ],
      ),
    );
  }
}
