
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/finance.dart';
import '../../models/operations.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/money.dart';
import '../../widgets/async_views.dart';
import '../../widgets/premium_cards.dart';
import '../../widgets/premium_charts.dart';
import '../../widgets/premium_feedback.dart';
import '../../widgets/status_chip.dart';

class AnalyticsTab extends ConsumerStatefulWidget {
  const AnalyticsTab({super.key});

  @override
  ConsumerState<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<AnalyticsTab> {
  int _rangeDays = 7;

  DateTime get _from =>
      DateTime.now().subtract(Duration(days: _rangeDays));

  String get _fromIso => _from.toIso8601String().split('T').first;

  String get _toIso =>
      DateTime.now().toIso8601String().split('T').first;

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    final analytics = ref.watch(analyticsProvider);
    final dashboard = ref.watch(dashboardProvider(venueId));
    final reservations = ref.watch(
      reservationsProvider((
        venue: venueId,
        date: null,
        status: null,
      )),
    );

    return AsyncView<AnalyticsSnapshot>(
      value: analytics,
      onRetry: () => ref.invalidate(analyticsProvider),
      emptyState: const EmptyState(
        title: 'No activity yet',
        message: 'Once bookings settle across your venues, '
            'the totals and trends appear here.',
        icon: Icons.query_stats_outlined,
      ),
      loading: const LoadingSkeleton(
        count: 5,
        showHeader: true,
      ),
      builder: (context, snap) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final padding = compact ? 16.0 : 20.0;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                padding,
                16,
                padding,
                32,
              ),
              children: [
                _InsightsHeader(
                  rangeDays: _rangeDays,
                  onRangeChanged: (days) {
                    setState(() => _rangeDays = days);
                  },
                ),

                const SizedBox(height: 20),

                _ScopeNotice(),

                const SizedBox(height: 24),

                _SectionHeading(
                  title: 'Performance overview',
                  subtitle: 'Account-wide experience metrics',
                ),

                const SizedBox(height: 14),

                _KpiGrid(snapshot: snap),

                const SizedBox(height: 28),

                if (reservations.hasValue) ...[
                  _ReservationTrends(
                    reservations: reservations.value!,
                    from: _fromIso,
                    to: _toIso,
                    truncated: reservations.value!.length >= 200,
                  ),
                  const SizedBox(height: 28),
                ],

                _SectionHeading(
                  title: 'Recent bookings',
                  subtitle: 'Latest ticket sales',
                ),

                const SizedBox(height: 14),

                if (snap.recentBookings.isEmpty)
                  const _EmptyBookings()
                else
                  ...snap.recentBookings.map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RecentTile(booking: booking),
                    ),
                  ),

                const SizedBox(height: 20),

                if (dashboard.hasValue) ...[
                  _QrScansCard(scans: dashboard.value!.scans),
                  const SizedBox(height: 24),
                ],

                const _UnavailableMetrics(),
              ],
            );
          },
        );
      },
    );
  }
}

class _InsightsHeader extends StatelessWidget {
  const _InsightsHeader({
    required this.rangeDays,
    required this.onRangeChanged,
  });

  final int rangeDays;
  final ValueChanged<int> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Understand your restaurant activity',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final days in const [7, 30, 90]) ...[
                _RangeChip(
                  days: days,
                  selected: rangeDays == days,
                  onTap: () => onRangeChanged(days),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.days,
    required this.selected,
    required this.onTap,
  });

  final int days;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        days == 7
            ? '7 days'
            : days == 30
                ? '30 days'
                : '90 days',
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelStyle: AppTextStyles.labelSmall.copyWith(
        color: selected
            ? AppColors.primary
            : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Experience KPIs cover the entire account. '
              'Reservation trends and QR scans use the selected venue.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.snapshot});

  final AnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 3 : 2;
        final gap = 10.0;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        final tiles = <Widget>[
          _KpiTile(
            label: 'Revenue',
            value: formatMoney(snapshot.totalRevenue),
            icon: Icons.payments_outlined,
            tone: AppColors.success,
          ),
          _KpiTile(
            label: 'Bookings',
            value: '${snapshot.totalBookings}',
            icon: Icons.confirmation_number_outlined,
          ),
          _KpiTile(
            label: 'Events',
            value: '${snapshot.totalEvents}',
            caption: '${snapshot.upcomingEvents} upcoming',
            icon: Icons.event_outlined,
          ),
          _KpiTile(
            label: 'Covers',
            value: '${snapshot.totalCovers}',
            caption:
                '${snapshot.averageCoversPerEvent.toStringAsFixed(1)} / event',
            icon: Icons.groups_outlined,
          ),
          _KpiTile(
            label: 'Avg fill rate',
            value:
                '${(snapshot.avgFillRate * 100).toStringAsFixed(0)}%',
            caption: 'Past events',
            icon: Icons.donut_large_outlined,
            tone: AppColors.primary,
          ),
          _KpiTile(
            label: 'Avg seat price',
            value: formatMoney(snapshot.avgPricePerSeat),
            icon: Icons.sell_outlined,
          ),
        ];

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                child: tile,
              ),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.tone,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone ?? AppColors.primary;

    return Container(
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: accent,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.numericMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReservationTrends extends StatelessWidget {
  const _ReservationTrends({
    required this.reservations,
    required this.from,
    required this.to,
    required this.truncated,
  });

  final List<Reservation> reservations;
  final String from;
  final String to;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final byDate = <String, int>{};

    for (final reservation in reservations) {
      final dateKey =
          reservation.startAt.toIso8601String().split('T').first;
      byDate[dateKey] = (byDate[dateKey] ?? 0) + 1;
    }

    final points = byDate.entries
        .map(
          (entry) => TrendPoint(
            date: DateTime.parse(entry.key),
            value: entry.value.toDouble(),
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'Reservation trends',
          subtitle: '$from to $to · Selected venue',
        ),
        const SizedBox(height: 14),
        if (points.isEmpty)
          const InlineNotice(
            message: 'No reservations in this window.',
            kind: InlineNoticeKind.info,
            icon: Icons.info_outline,
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: SizedBox(
              height: 220,
              child: ChartFrame(
                title: 'Daily reservations',
                subtitle: '${points.length} days with activity',
                child: TrendLineChart(points: points),
              ),
            ),
          ),
        if (truncated) ...[
          const SizedBox(height: 12),
          const InlineNotice(
            message: 'Showing first 200 reservations. '
                'Narrow the range for a complete view.',
            kind: InlineNoticeKind.warning,
            icon: Icons.warning_amber_outlined,
          ),
        ],
      ],
    );
  }
}

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_note_outlined,
            size: 28,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 10),
          Text(
            'No recent bookings',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.booking});

  final RecentBooking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;

    return PremiumCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 290;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.eventTitle.isEmpty
                    ? 'Experience'
                    : b.eventTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${b.userName} · ${b.seats} seats',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );

          final amount = Column(
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(b.totalAmount),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.numericMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              StatusChip(status: b.status),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 12),
                amount,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              const SizedBox(width: 12),
              Flexible(child: amount),
            ],
          );
        },
      ),
    );
  }
}

class _QrScansCard extends StatelessWidget {
  const _QrScansCard({required this.scans});

  final QrScanSummary scans;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(
          title: 'QR engagement',
          subtitle: 'Digital menu scan activity',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 650 ? 3 : 2;
            final gap = 10.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;

            final tiles = [
              _KpiTile(
                label: 'Today',
                value: '${scans.today}',
                icon: Icons.today_outlined,
              ),
              _KpiTile(
                label: 'Last 7 days',
                value: '${scans.week}',
                icon: Icons.date_range_outlined,
              ),
              _KpiTile(
                label: 'Last 30 days',
                value: '${scans.month}',
                icon: Icons.calendar_month_outlined,
              ),
            ];

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final tile in tiles)
                  SizedBox(
                    width: width,
                    child: tile,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _UnavailableMetrics extends StatelessWidget {
  const _UnavailableMetrics();

  @override
  Widget build(BuildContext context) {
    return const ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(bottom: 12),
      leading: Icon(
        Icons.info_outline_rounded,
        color: AppColors.textTertiary,
      ),
      title: Text('Other metrics'),
      subtitle: Text('Metrics not currently available'),
      children: [
        NotTrackedTile(
          metric: 'Profile views',
          reason: 'The DineCircle platform does not currently '
              'expose profile view counts to partners.',
        ),
        SizedBox(height: 10),
        NotTrackedTile(
          metric: 'Loyalty rewards',
          reason: 'The DineCircle platform does not currently '
              'expose a loyalty backend to partners.',
          supportLink: 'Contact support',
        ),
      ],
    );
  }
}
