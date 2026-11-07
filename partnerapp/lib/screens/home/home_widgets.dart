import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/operations.dart';
import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/image_background_card.dart';
import '../../widgets/status_chip.dart';
import '../service/reservation_detail_sheet.dart';
import 'home_sections.dart';

/// ─── Today's Overview ──────────────────────────────────────────────────────

/// A small animated green dot that pulses to indicate live auto-refresh.
///
/// Rendered beside section labels so the desk knows the numbers are keeping
/// themselves up to date without a manual pull.
class LivePulseIndicator extends StatefulWidget {
  const LivePulseIndicator({super.key});

  @override
  State<LivePulseIndicator> createState() => _LivePulseIndicatorState();
}

class _LivePulseIndicatorState extends State<LivePulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(
            alpha: 0.4 + (_controller.value * 0.6),
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(
                alpha: 0.3 * _controller.value,
              ),
              blurRadius: 4 * _controller.value,
              spreadRadius: 1 * _controller.value,
            ),
          ],
        ),
      ),
    );
  }
}

/// The four numbers the desk checks first.
///
/// Every value is a live dashboard counter. A metric the server did not
/// measure is rendered as ": " with an *Unavailable* caption, so it can never
/// be mistaken for a real zero. Each tile taps through to the surface that
/// explains it.
class TodaysOverview extends StatelessWidget {
  const TodaysOverview({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final counters = snapshot.today.reservations;
    final pending = counters.pending;
    final scansAvailable = snapshot.scansAvailable;

    final cards = <Widget>[
      _KpiCard(
        value: '${counters.booked}',
        label: 'Reservations',
        icon: Icons.event_available,
        color: AppColors.primary,
        subtitle: pending > 0 ? '$pending to confirm' : 'All confirmed',
        subtitleColor: pending > 0 ? AppColors.warning : AppColors.success,
        trend: snapshot.today.yesterdayCovers > 0 || snapshot.today.covers > 0
            ? snapshot.today.coversDelta
            : null,
        imageAsset: CardImageAssets.reservations,
        onTap: () => _go(context, '${AppRoute.service}?tab=reservations'),
      ),
      _KpiCard(
        value: scansAvailable ? '${snapshot.scans.today}' : '-',
        label: 'QR Scans',
        icon: Icons.qr_code_2,
        color: AppColors.info,
        subtitle: scansAvailable ? 'Today' : 'Unavailable',
        unavailable: !scansAvailable,
        imageAsset: CardImageAssets.qrScans,
        onTap: () => _go(context, '${AppRoute.business}?tab=qr'),
      ),
      _KpiCard(
        value: '${snapshot.deals.active}',
        label: 'Active Deals',
        icon: Icons.local_offer,
        color: AppColors.gold,
        subtitle: 'Live now',
        imageAsset: CardImageAssets.activeDeals,
        onTap: () => _go(context, '${AppRoute.business}?tab=deals'),
      ),
      _KpiCard(
        value: '${snapshot.events.upcoming}',
        label: 'Experiences',
        icon: Icons.auto_awesome,
        color: AppColors.success,
        subtitle: 'Upcoming',
        imageAsset: CardImageAssets.experiences,
        onTap: () => _go(context, '${AppRoute.experiences}?tab=experiences'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel(title: "TODAY'S OVERVIEW")),
            const SizedBox(width: AppSpacing.sm),
            const LivePulseIndicator(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _KpiGrid(cards: cards),
      ],
    );
  }

  void _go(BuildContext context, String route) =>
      Navigator.of(context).pushReplacementNamed(route);
}

/// Two columns of KPI cards, dropping to one column on a very narrow screen or
/// at a large text scale, where a card can no longer hold its own label.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final single = scale >= 1.8 || constraints.maxWidth < 300;
        if (single) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                cards[i],
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < cards.length; i += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: cards[i + 1]),
              ],
            ),
          );
          if (i + 2 < cards.length) {
            rows.add(const SizedBox(height: AppSpacing.sm));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.subtitle,
    this.subtitleColor,
    this.unavailable = false,
    this.trend,
    this.imageAsset,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback? onTap;

  /// The metric was not measured. The value reads as ": " instead of `0`.
  final bool unavailable;

  /// Positive = up vs yesterday, negative = down, zero = flat.
  /// When non-null a small arrow is rendered beside the subtitle.
  final int? trend;

  /// Optional photographic background. When provided, the card renders with a
  /// dark scrim overlay for readability. When null, falls back to a plain
  /// gradient surface.
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final tone = unavailable ? AppColors.textTertiary : color;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: imageAsset != null
            ? null
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.surface, AppColors.surfaceElevated],
                ),
                borderRadius: radius,
                border: Border.all(color: AppColors.border),
              ),
        child: InkWell(
          onTap: onTap,
          child: imageAsset != null
              ? ImageBackgroundCard(
                  imageAsset: imageAsset,
                  overlayOpacity: 0.70,
                  borderRadius: radius,
                  border: Border.all(color: AppColors.border),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _buildContent(tone),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildContent(tone),
                ),
        ),
      ),
    );
  }

  Widget _buildContent(Color tone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusSm,
                ),
                border: Border.all(
                  color: tone.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(icon, color: tone, size: 16),
            ),
            const Spacer(),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.textTertiary,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTextStyles.metricValue.copyWith(
              fontSize: 28,
              color: unavailable
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trend != null) _TrendArrow(delta: trend!),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppTextStyles.labelSmall.copyWith(
              color: subtitleColor ?? AppColors.textTertiary,
              fontSize: 10,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// A small coloured arrow beside a KPI label showing up/down vs yesterday.
class _TrendArrow extends StatelessWidget {
  const _TrendArrow({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (delta.sign) {
      1 => (Icons.trending_up, AppColors.success),
      -1 => (Icons.trending_down, AppColors.danger),
      _ => (Icons.trending_flat, AppColors.textTertiary),
    };
    return Icon(icon, size: 14, color: color);
  }
}

/// ─── Quick Actions ─────────────────────────────────────────────────────────

/// The four things a desk does between tables.
///
/// Every tile lands on a registered route: the two Business tiles on a `?tab=`
/// of the Business section, the reservations tile on the day board. *Add Deal*
/// asks the Deals tab to open its creation form straight away, the tab still
/// owns the venue-verification and role rules, so an unverified venue simply
/// sees why the button is disabled.
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _QuickActionTile(
        tileKey: const ValueKey('home-quick-menu'),
        icon: Icons.restaurant_menu,
        label: 'Edit Menu',
        caption: 'Dishes & prices',
        color: AppColors.primary,
        imageAsset: CardImageAssets.editMenu,
        onTap: () => Navigator.of(
          context,
        ).pushReplacementNamed('${AppRoute.business}?tab=menu'),
      ),
      _QuickActionTile(
        tileKey: const ValueKey('home-quick-deal'),
        icon: Icons.add_circle_outline,
        label: 'Create Deal',
        caption: 'Publish an offer',
        color: AppColors.gold,
        imageAsset: CardImageAssets.createDeal,
        onTap: () => Navigator.of(
          context,
        ).pushReplacementNamed('${AppRoute.business}?tab=deals&create=1'),
      ),
      _QuickActionTile(
        tileKey: const ValueKey('home-quick-qr'),
        icon: Icons.qr_code_2,
        label: 'QR Code',
        caption: 'Share the menu',
        color: AppColors.info,
        imageAsset: CardImageAssets.qrCode,
        onTap: () => Navigator.of(
          context,
        ).pushReplacementNamed('${AppRoute.business}?tab=qr'),
      ),
      _QuickActionTile(
        tileKey: const ValueKey('home-quick-reservations'),
        icon: Icons.event_available,
        label: 'Reservations',
        caption: "Today's board",
        color: AppColors.success,
        imageAsset: CardImageAssets.reservationsBoard,
        onTap: () => Navigator.of(
          context,
        ).pushReplacementNamed('${AppRoute.service}?tab=reservations'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(title: 'QUICK ACTIONS'),
        const SizedBox(height: AppSpacing.sm),
        _QuickActionGrid(tiles: tiles),
      ],
    );
  }
}

/// Four tiles across on a roomy phone, two by two once the labels would not
/// fit, at 320dp or at a large text scale.
class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth >= 320 && scale < 1.4 ? 4 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += columns) {
          final slice = tiles.sublist(i, (i + columns).clamp(0, tiles.length));
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var j = 0; j < slice.length; j++) ...[
                  if (j > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: slice[j]),
                ],
              ],
            ),
          );
          if (i + columns < tiles.length) {
            rows.add(const SizedBox(height: AppSpacing.sm));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.onTap,
    this.imageAsset,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final VoidCallback onTap;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: imageAsset != null
            ? null
            : BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.10),
                    AppColors.surface,
                    AppColors.surfaceElevated,
                  ],
                ),
                borderRadius: radius,
                border: Border.all(color: AppColors.border),
              ),
        child: InkWell(
          key: tileKey,
          onTap: onTap,
          child: imageAsset != null
              ? ImageBackgroundCard(
                  imageAsset: imageAsset,
                  overlayOpacity: 0.72,
                  borderRadius: radius,
                  border: Border.all(color: AppColors.border),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                      horizontal: AppSpacing.xs,
                    ),
                    child: _buildContent(),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                    horizontal: AppSpacing.xs,
                  ),
                  child: _buildContent(),
                ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 9,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// ─── Upcoming Reservations ─────────────────────────────────────────────────

/// The bookings that still hold a table: pending, confirmed or seated.
///
/// Cancelled, completed and no-show rows are history, not upcoming, so they are
/// dropped. A *pending* booking is kept,it still needs a confirmation,and
/// leads the list because it is the one row the desk has to act on. The rest
/// follow in start-time order and the list is capped at [limit].
List<Reservation> upcomingReservations(
  List<Reservation> rows, {
  int limit = 3,
}) {
  final visible = rows.where((r) => r.status.holdsCovers).toList();
  visible.sort((a, b) {
    final aPending = a.status == ReservationStatus.pending;
    final bPending = b.status == ReservationStatus.pending;
    if (aPending != bPending) return aPending ? -1 : 1;
    return a.startAt.compareTo(b.startAt);
  });
  return visible.take(limit).toList();
}

/// The next bookings of the service day, with the failures of the read kept
/// next to the list they belong to.
class TodaysReservationsSection extends StatelessWidget {
  const TodaysReservationsSection({
    super.key,
    required this.reservations,
    required this.venueId,
    required this.onRetry,
    this.trend = const [],
  });

  final AsyncValue<List<Reservation>> reservations;
  final String venueId;

  /// Re-reads the day list without touching the rest of the screen.
  final VoidCallback onRetry;

  /// Hourly reservation counts for the day, used to draw the compact timeline.
  final List<HourlyTrend> trend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: 'UPCOMING RESERVATIONS',
          trailing: SectionLink(
            label: 'View all',
            onPressed: () => Navigator.of(
              context,
            ).pushReplacementNamed('${AppRoute.service}?tab=reservations'),
          ),
        ),
        if (trend.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _HourlyTimeline(trend: trend),
        ],
        const SizedBox(height: AppSpacing.sm),
        reservations.when(
          loading: () => const _ReservationsLoading(),
          error: (error, _) =>
              _ReservationsError(error: error, onRetry: onRetry),
          data: (list) {
            final displayList = upcomingReservations(list);
            if (displayList.isEmpty) {
              return const _EmptyReservations();
            }
            final hidden =
                list.where((r) => r.status.holdsCovers).length -
                displayList.length;
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < displayList.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 16, color: AppColors.border),
                    _ReservationTile(
                      reservation: displayList[i],
                      venueId: venueId,
                    ),
                  ],
                  if (hidden > 0) ...[
                    Divider(height: 1, indent: 16, color: AppColors.border),
                    _MoreReservationsRow(count: hidden),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The rows that did not fit in the preview, one tap to the day board.
class _MoreReservationsRow extends StatelessWidget {
  const _MoreReservationsRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).pushReplacementNamed('${AppRoute.service}?tab=reservations'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.more_horiz,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                '$count more ${count == 1 ? 'booking' : 'bookings'} today',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationsLoading extends StatelessWidget {
  const _ReservationsLoading();

  @override
  Widget build(BuildContext context) {
    return const SectionSkeleton(rows: 3);
  }
}

/// A failed read, with the retry next to it instead of behind a full screen.
class _ReservationsError extends StatelessWidget {
  const _ReservationsError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unable to load reservations',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  error.toString(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyReservations extends StatelessWidget {
  const _EmptyReservations();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available,
            size: 28,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No upcoming reservations',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            'New bookings appear here as soon as guests reserve through '
            'the Customer App or you take a phone booking. Share your QR '
            'code to start receiving reservations.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation, required this.venueId});

  final Reservation reservation;
  final String venueId;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(reservation.startAt);
    final timeStr = time.format(context);

    return InkWell(
      onTap: () => showReservationSheet(context, reservation, venueId: venueId),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: AppTextStyles.numericMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reservation.partyLabel,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Container(width: 1, height: 32, color: AppColors.border),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reservation.guestName,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reservation.isPhoneIn ? 'Phone booking' : 'Customer App',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            StatusChip(
              status: reservation.status.wire,
              label: reservation.status.label,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Needs Attention ───────────────────────────────────────────────────────

/// What the desk should work next, most actionable first.
///
/// The order *is* the priority: a booking waiting for a confirmation holds a
/// table, a host request waits for a decision, an unverified venue cannot sell
/// anything, and unread notifications are informational, so they come last.
class NeedsAttentionSection extends StatelessWidget {
  const NeedsAttentionSection({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = _buildNeedsAttentionList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(title: 'NEEDS ATTENTION'),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'All caught up',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 56, color: AppColors.border),
                  _NeedsAttentionTile(item: items[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  List<_NeedsAttentionItem> _buildNeedsAttentionList() {
    final items = <_NeedsAttentionItem>[];
    final venue = snapshot.venue;

    final pending = snapshot.today.reservations.pending;
    if (pending > 0) {
      items.add(
        _NeedsAttentionItem(
          icon: Icons.event_available,
          color: AppColors.warning,
          title: pending == 1
              ? '1 reservation to confirm'
              : '$pending reservations to confirm',
          subtitle: 'Awaiting confirmation',
          route: '${AppRoute.service}?tab=reservations',
        ),
      );
    }

    final requests = snapshot.events.pendingRequests;
    if (requests > 0) {
      items.add(
        _NeedsAttentionItem(
          icon: Icons.pending_actions,
          color: AppColors.primary,
          title: requests == 1
              ? '1 host request to review'
              : '$requests host requests to review',
          subtitle: 'Waiting for a decision',
          route: '${AppRoute.experiences}?tab=requests',
        ),
      );
    }

    // Verification blocks every selling surface, so it outranks a half-filled
    // profile, and both outrank a notification nobody is waiting on.
    if (!venue.verified) {
      items.add(
        _NeedsAttentionItem(
          icon: Icons.verified_outlined,
          color: AppColors.danger,
          title: 'Venue not verified',
          subtitle: 'Verification is required to sell',
          route: AppRoute.verification,
          replace: false,
        ),
      );
    } else if (venue.profileCompletion < 100) {
      items.add(
        _NeedsAttentionItem(
          icon: Icons.storefront_outlined,
          color: AppColors.info,
          title: 'Profile ${venue.profileCompletion}% complete',
          subtitle: 'Finish your venue profile',
          route: '${AppRoute.business}?tab=profile',
        ),
      );
    }

    final unread = snapshot.unreadNotifications;
    if (unread > 0) {
      items.add(
        _NeedsAttentionItem(
          icon: Icons.notifications,
          color: AppColors.info,
          title: unread == 1
              ? '1 unread notification'
              : '$unread unread notifications',
          subtitle: 'Unread messages',
          route: '${AppRoute.inbox}?tab=notifications',
        ),
      );
    }

    return items.take(3).toList();
  }
}

class _NeedsAttentionItem {
  const _NeedsAttentionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
    this.replace = true,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;

  /// Whether the destination replaces the Home route (a primary surface) or
  /// is pushed on top of it (a detail screen the desk comes back from).
  final bool replace;
}

class _NeedsAttentionTile extends StatelessWidget {
  const _NeedsAttentionTile({required this.item});

  final _NeedsAttentionItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (item.replace) {
          Navigator.of(context).pushReplacementNamed(item.route);
        } else {
          Navigator.of(context).pushNamed(item.route);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Hourly timeline ───────────────────────────────────────────────────────

/// A compact horizontal bar chart showing reservation density by hour.
///
/// The current hour is highlighted with a dot. Hours with no data are shown
/// as empty slots so the desk can see gaps at a glance. Only the next 6 hours
/// from the current time are displayed to keep the strip compact.
class _HourlyTimeline extends StatelessWidget {
  const _HourlyTimeline({required this.trend});

  final List<HourlyTrend> trend;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentHour = now.hour;

    // Show the next 6 hours starting from the current hour (or the earliest
    // data hour if it is earlier than now).
    final earliestHour = trend.isEmpty
        ? currentHour
        : trend.map((e) => e.hour).reduce((a, b) => a < b ? a : b);
    final startHour = earliestHour < currentHour ? earliestHour : currentHour;
    final hours = List.generate(6, (i) => startHour + i);

    final maxCount = trend.isEmpty
        ? 1
        : trend.map((e) => e.count).reduce((a, b) => a > b ? a : b).clamp(1, 99);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final hour in hours) ...[
            Expanded(
              child: _TimelineSlot(
                hour: hour,
                count: _countForHour(hour),
                maxCount: maxCount,
                isCurrent: hour == currentHour,
              ),
            ),
            if (hour != hours.last) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  int _countForHour(int hour) {
    final match = trend.where((e) => e.hour == hour);
    return match.isEmpty ? 0 : match.first.count;
  }
}

class _TimelineSlot extends StatelessWidget {
  const _TimelineSlot({
    required this.hour,
    required this.count,
    required this.maxCount,
    required this.isCurrent,
  });

  final int hour;
  final int count;
  final int maxCount;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final barHeight = count > 0 ? (count / maxCount) * 24.0 : 2.0;
    final barColor = count > 0 ? AppColors.primary : AppColors.border;
    final label = '${hour.toString().padLeft(2, '0')}:00';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count > 0)
          Text(
            '$count',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          const SizedBox(height: 10),
        const SizedBox(height: 2),
        Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isCurrent ? AppColors.primary : AppColors.textTertiary,
                fontSize: 8,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (isCurrent)
              Positioned(
                bottom: -4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// ─── Skeleton ──────────────────────────────────────────────────────────────

/// The Home skeleton.
///
/// It is a scroll view, not a column: the same blocks have to fit a short
/// landscape window as well as a tall phone, and a skeleton that overflows is
/// the first thing the desk sees on a slow connection.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const radius = AppSpacing.radiusMd;
    Widget block(double height, {double? width}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.paddingScreen),
      children: [
        block(184),
        const SizedBox(height: AppSpacing.lg),
        block(14, width: 120),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: block(96)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: block(96)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: block(96)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: block(96)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        block(14, width: 100),
        const SizedBox(height: AppSpacing.sm),
        block(84),
        const SizedBox(height: AppSpacing.lg),
        block(180),
        const SizedBox(height: AppSpacing.lg),
        block(120),
      ],
    );
  }
}
