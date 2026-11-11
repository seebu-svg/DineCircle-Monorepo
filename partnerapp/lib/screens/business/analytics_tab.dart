import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/deals.dart';
import '../../models/experience.dart';
import '../../models/operations.dart';
import '../../navigation/app_routes.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/date_time.dart';
import '../../widgets/role_gate_builder.dart';
import 'insights_widgets.dart';

/// Restaurant performance for the venue in the switcher.
///
/// The page answers one question: is DineCircle bringing guests to *this*
/// restaurant? Every figure has a verified source and states the period it
/// covers:
///
///  * reservations come from the venue's own table book
///    (`…/restaurants/:id/reservations?from=&to=`) and follow the range chips;
///  * QR scans come from the dashboard's venue-scoped counters, which the
///    server computes for today, 7 days and 30 days only;
///  * deal redemptions are the lifetime counters carried on the venue's own
///    offers, and there is no ledger behind them;
///  * experiences are `/partner/events` rows filtered to this venue's id.
///
/// Money is deliberately absent. `/partner/analytics` spans every operated
/// venue and sums ticket value, and the dashboard's month figures are
/// subscription data (gross, refunds, commission). Neither is this
/// restaurant's earnings, so neither is labelled as such here, and the
/// subscription model means there is no commission or payout metric to show.
class AnalyticsTab extends ConsumerStatefulWidget {
  const AnalyticsTab({super.key});

  @override
  ConsumerState<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<AnalyticsTab> {
  /// The three windows the server can answer for. QR counters stop at 30 days,
  /// so a longer choice would promise a window one card could not honour.
  static const Map<String, int> _windowDays = {'7d': 7, '30d': 30, '90d': 90};

  String _rangeId = '7d';

  int get _days => _windowDays[_rangeId] ?? 7;

  ({String venue, String from, String to}) _windowKey(
    String venueId,
    DateRange range,
  ) => (venue: venueId, from: range.fromIso, to: range.toIso);

  /// Pull-to-refresh re-reads all four sources, because the four cards claim to
  /// describe the same moment. The indicator waits for every read, not just the
  /// reservations: stopping while scans and deals were still in flight would
  /// leave the page looking refreshed while half of it was stale.
  Future<void> _refresh(String venueId, DateRange range) async {
    final key = _windowKey(venueId, range);
    try {
      await Future.wait<Object?>([
        ref.refresh(insightsReservationsProvider(key).future),
        ref.refresh(dashboardProvider(venueId).future),
        ref.refresh(dealsProvider((venue: venueId, status: null)).future),
        ref.refresh(insightsExperiencesProvider(venueId).future),
      ]);
    } catch (error) {
      if (mounted) {
        reportError(context, error, prefix: 'Could not refresh insights:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(selectedVenueProvider);
    final venueId = ref.watch(selectedVenueIdProvider);

    if (venueId.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.paddingScreen),
        children: const [
          InsightsPlaceholder(
            message: 'Choose a restaurant to see its insights.',
            icon: Icons.storefront_outlined,
          ),
        ],
      );
    }

    final range = DateRange.preset(_rangeId);
    final days = _days;
    final windowLabel = insightsWindowLabel(range);
    final windowKey = _windowKey(venueId, range);

    final window = ref.watch(insightsReservationsProvider(windowKey));
    final dashboard = ref.watch(dashboardProvider(venueId));
    final deals = ref.watch(dealsProvider((venue: venueId, status: null)));
    final experiences = ref.watch(insightsExperiencesProvider(venueId));

    // Only the very first read gets the full skeleton. Once any source has
    // answered, each section shows its own state, so a slow QR counter cannot
    // blank the reservation chart that already arrived.
    final firstRead = window.isLoading &&
        !window.hasValue &&
        dashboard.isLoading &&
        !dashboard.hasValue &&
        deals.isLoading &&
        !deals.hasValue &&
        experiences.isLoading &&
        !experiences.hasValue;
    if (firstRead) return const InsightsSkeleton();

    final dealPerformance = DealPerformance.of(
      deals.valueOrNull ?? const <Deal>[],
    );
    final experiencePerformance = ExperiencePerformance.of(
      experiences.valueOrNull ?? const <PartnerExperience>[],
      range: range,
    );

    final horizontal = MediaQuery.sizeOf(context).width < 360
        ? AppSpacing.md
        : AppSpacing.paddingScreen;

    return RefreshIndicator(
      onRefresh: () => _refresh(venueId, range),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.md,
              horizontal,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: InsightsHeaderCard(
                venue: venue,
                windowLabel: windowLabel,
                days: days,
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _RangeBand(
              inset: horizontal,
              selectedId: _rangeId,
              onSelect: (id) {
                if (id == _rangeId) return;
                setState(() => _rangeId = id);
              },
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.sm,
              horizontal,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: InsightsKpiGrid(
                figures: [
                  _reservationsKpi(window, days),
                  _scansKpi(dashboard, days),
                  _dealsKpi(deals, dealPerformance),
                  _experiencesKpi(experiences, experiencePerformance, days),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.md,
              horizontal,
              AppSpacing.xl,
            ),
            sliver: SliverList.list(
              children: [
                _trendSection(window, venueId, range, days),
                const SizedBox(height: AppSpacing.md),
                _dealSection(deals, dealPerformance),
                const SizedBox(height: AppSpacing.md),
                _qrSection(dashboard),
                const SizedBox(height: AppSpacing.md),
                _experienceSection(
                  experiences,
                  experiencePerformance,
                  venueId,
                  days,
                ),
                const SizedBox(height: AppSpacing.md),
                _recentSection(window, venueId, range, days),
                const SizedBox(height: AppSpacing.lg),
                const InsightsNote(
                  'No earnings are shown: DineCircle runs on a subscription, '
                  'and ticket value is account-wide rather than this '
                  'restaurant’s revenue.',
                  icon: Icons.shield_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI figures ────────────────────────────────────────────────────────────

  InsightsKpi _reservationsKpi(
    AsyncValue<ReservationWindow> window,
    int days,
  ) {
    return window.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const InsightsKpi(
        label: 'Reservations',
        value: '–',
        caption: 'Reading…',
      ),
      error: (error, stack) => const InsightsKpi(
        label: 'Reservations',
        value: '–',
        caption: 'Unavailable',
      ),
      data: (value) => InsightsKpi(
        label: 'Reservations',
        value: '${value.keptCount}',
        caption: value.truncated
            ? 'First ${value.reservations.length} of ${value.total} · $days days'
            : '$days days · booked',
      ),
    );
  }

  InsightsKpi _scansKpi(AsyncValue<DashboardSnapshot> dashboard, int days) {
    return dashboard.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const InsightsKpi(
        label: 'QR scans',
        value: '–',
        caption: 'Reading…',
      ),
      error: (error, stack) => const InsightsKpi(
        label: 'QR scans',
        value: '–',
        caption: 'Unavailable',
      ),
      data: (snap) {
        if (!snap.scansAvailable) {
          return const InsightsKpi(
            label: 'QR scans',
            value: '–',
            caption: 'Not reported',
          );
        }
        return switch (days) {
          7 => InsightsKpi(
            label: 'QR scans',
            value: '${snap.scans.week}',
            caption: 'Last 7 days · menu',
          ),
          30 => InsightsKpi(
            label: 'QR scans',
            value: '${snap.scans.month}',
            caption: 'Last 30 days · menu',
          ),
          _ => const InsightsKpi(
            label: 'QR scans',
            value: '–',
            caption: 'Not tracked past 30 days',
          ),
        };
      },
    );
  }

  InsightsKpi _dealsKpi(
    AsyncValue<List<Deal>> deals,
    DealPerformance performance,
  ) {
    return deals.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const InsightsKpi(
        label: 'Deal redemptions',
        value: '–',
        caption: 'Reading…',
      ),
      error: (error, stack) => const InsightsKpi(
        label: 'Deal redemptions',
        value: '–',
        caption: 'Unavailable',
      ),
      data: (rows) => performance.known
          ? InsightsKpi(
              label: 'Deal redemptions',
              value: '${performance.total}',
              caption:
                  'All time · ${rows.length} ${rows.length == 1 ? 'offer' : 'offers'}',
            )
          : const InsightsKpi(
              label: 'Deal redemptions',
              value: '–',
              caption: 'Not reported',
            ),
    );
  }

  InsightsKpi _experiencesKpi(
    AsyncValue<List<PartnerExperience>> experiences,
    ExperiencePerformance performance,
    int days,
  ) {
    return experiences.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const InsightsKpi(
        label: 'Experiences',
        value: '–',
        caption: 'Reading…',
      ),
      error: (error, stack) => const InsightsKpi(
        label: 'Experiences',
        value: '–',
        caption: 'Unavailable',
      ),
      data: (rows) => InsightsKpi(
        label: 'Experiences',
        value: '${performance.held.length}',
        caption: '$days days · hosted',
      ),
    );
  }

  // ── Sections ───────────────────────────────────────────────────────────────

  Widget _trendSection(
    AsyncValue<ReservationWindow> window,
    String venueId,
    DateRange range,
    int days,
  ) {
    return InsightsSectionCard(
      title: 'Reservation trends',
      subtitle:
          '${insightsWindowLabel(range)} · booked per ${days > 30 ? 'week' : 'day'}',
      child: window.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const InsightsPlaceholder(
          message: 'Reading this window…',
          icon: Icons.hourglass_empty,
        ),
        error: (error, stack) => InsightsReadError(
          message: 'Reservation trends could not be read.',
          onRetry: () => ref.invalidate(
            insightsReservationsProvider(_windowKey(venueId, range)),
          ),
        ),
        data: (value) {
          final buckets = reservationBuckets(value.kept, days: days);
          final total = buckets.fold<int>(0, (sum, b) => sum + b.value);
          if (total == 0) {
            return const InsightsPlaceholder(
              message: 'No bookings in this window yet. Try a longer range.',
              icon: Icons.event_busy_outlined,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReservationTrendChart(buckets: buckets),
              if (value.truncated) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                InsightsNote(
                  'Showing the first ${value.reservations.length} of '
                  '${value.total} bookings in this window.',
                  icon: Icons.filter_alt_outlined,
                ),
              ],
              if (value.lostCount > 0) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                InsightsNote(
                  '${value.lostCount} cancelled or no-show '
                  '${value.lostCount == 1 ? 'booking is' : 'bookings are'} '
                  'left out.',
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _dealSection(
    AsyncValue<List<Deal>> deals,
    DealPerformance performance,
  ) {
    return InsightsSectionCard(
      title: 'Deal performance',
      subtitle: 'Redemptions recorded at the table',
      child: deals.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const InsightsPlaceholder(
          message: 'Reading your offers…',
          icon: Icons.hourglass_empty,
        ),
        error: (error, stack) => InsightsReadError(
          message: 'Deal performance could not be read.',
          onRetry: () => ref.invalidate(
            dealsProvider(
              (venue: ref.read(selectedVenueIdProvider), status: null),
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const InsightsPlaceholder(
              message:
                  'No offers yet. Create one from Deals to start attracting '
                  'guests.',
              icon: Icons.local_offer_outlined,
            );
          }
          if (!performance.known) {
            return const InsightsPlaceholder(
              message: 'Redemption counters are not reported for these offers.',
              icon: Icons.local_offer_outlined,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DealRedemptionList(deals: performance.rows),
              if (performance.rows.length > 3) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                InsightsNote(
                  'Top 3 of ${performance.rows.length} offers by redemptions.',
                ),
              ],
              const SizedBox(height: AppSpacing.sm + 2),
              const InsightsNote(
                'Lifetime totals, so the selected range does not change them.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _qrSection(AsyncValue<DashboardSnapshot> dashboard) {
    return InsightsSectionCard(
      title: 'QR engagement',
      subtitle: 'Menu scans through your DineCircle QR',
      child: dashboard.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const InsightsPlaceholder(
          message: 'Reading scan counters…',
          icon: Icons.hourglass_empty,
        ),
        error: (error, stack) => InsightsReadError(
          message: 'QR scan counters could not be read.',
          onRetry: () =>
              ref.invalidate(dashboardProvider(ref.read(selectedVenueIdProvider))),
        ),
        data: (snap) {
          if (!snap.scansAvailable) {
            return const InsightsPlaceholder(
              message:
                  'Scan counters are not available for this restaurant yet.',
              icon: Icons.qr_code_2_outlined,
            );
          }
          final scans = snap.scans;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InsightsFigureStrip(
                figures: [
                  InsightsFigure(label: 'Today', value: '${scans.today}'),
                  InsightsFigure(label: 'Last 7 days', value: '${scans.week}'),
                  InsightsFigure(
                    label: 'Last 30 days',
                    value: '${scans.month}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              const InsightsNote(
                'One scan counts per device per hour, so these are guests '
                'reached rather than menu views. Counters cover today, 7 and '
                '30 days only.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _experienceSection(
    AsyncValue<List<PartnerExperience>> experiences,
    ExperiencePerformance performance,
    String venueId,
    int days,
  ) {
    return InsightsSectionCard(
      title: 'Experiences performance',
      subtitle: 'Dinners hosted at this restaurant',
      actionLabel: 'View',
      onAction: () => Navigator.of(context).pushNamed(AppRoute.experiences),
      child: experiences.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const InsightsPlaceholder(
          message: 'Reading experiences…',
          icon: Icons.hourglass_empty,
        ),
        error: (error, stack) => InsightsReadError(
          message: 'Experiences could not be read.',
          onRetry: () => ref.invalidate(insightsExperiencesProvider(venueId)),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const InsightsPlaceholder(
              message: 'No experiences for this restaurant yet.',
              icon: Icons.auto_awesome_outlined,
            );
          }
          final next = performance.next;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InsightsFigureStrip(
                figures: [
                  InsightsFigure(
                    label: 'Held',
                    value: '${performance.held.length}',
                    hint: 'Held in $days days',
                  ),
                  InsightsFigure(
                    label: 'Seats booked',
                    value: '${performance.seatsBooked}',
                  ),
                  InsightsFigure(
                    label: 'Fill rate',
                    value: performance.fillRateLabel,
                  ),
                ],
              ),
              if (performance.held.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                const InsightsNote('No experiences ran in this window.'),
              ],
              if (next != null) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                InsightsNote(
                  'Next: ${next.title} · ${DisplayDate.day(next.startAt)}',
                  icon: Icons.event_outlined,
                ),
              ],
              if (performance.awaitingApproval > 0) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                InsightsNote(
                  '${performance.awaitingApproval} host '
                  '${performance.awaitingApproval == 1 ? 'proposal is' : 'proposals are'} '
                  'awaiting your decision.',
                  icon: Icons.pending_actions_outlined,
                  tone: AppColors.warning,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _recentSection(
    AsyncValue<ReservationWindow> window,
    String venueId,
    DateRange range,
    int days,
  ) {
    return InsightsSectionCard(
      title: 'Recent activity',
      subtitle: 'Latest bookings made for this window',
      actionLabel: 'View all',
      onAction: () =>
          Navigator.of(context).pushNamed('${AppRoute.service}?tab=reservations'),
      child: window.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const InsightsPlaceholder(
          message: 'Reading recent bookings…',
          icon: Icons.hourglass_empty,
        ),
        error: (error, stack) => InsightsReadError(
          message: 'Recent bookings could not be read.',
          onRetry: () => ref.invalidate(
            insightsReservationsProvider(_windowKey(venueId, range)),
          ),
        ),
        data: (value) {
          final recent = recentReservations(value.reservations);
          if (recent.isEmpty) {
            return const InsightsPlaceholder(
              message: 'No bookings in this window yet.',
              icon: Icons.event_available_outlined,
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RecentReservationList(reservations: recent),
              if (value.truncated) ...[
                const SizedBox(height: AppSpacing.sm + 2),
                InsightsNote(
                  'Only the earliest ${value.reservations.length} of '
                  '${value.total} bookings loaded; newer ones may be missing.',
                  icon: Icons.filter_alt_outlined,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The range chips, pinned while the sections scroll.
///
/// It paints the page colour so cards sliding underneath cannot show through
/// the gaps between chips, and only the chips stick: the header above travels
/// with the list so a 2x text scale still has room for it.
class _RangeBand extends SliverPersistentHeaderDelegate {
  const _RangeBand({
    required this.inset,
    required this.selectedId,
    required this.onSelect,
  });

  final double inset;
  final String selectedId;
  final ValueChanged<String> onSelect;

  static const double _extent = AppSpacing.minTapTarget - 8;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppColors.bg,
      child: InsightsRangeRail(
        selectedId: selectedId,
        onSelect: onSelect,
        horizontalInset: inset,
      ),
    );
  }

  @override
  bool shouldRebuild(_RangeBand old) =>
      old.inset != inset || old.selectedId != selectedId;
}
