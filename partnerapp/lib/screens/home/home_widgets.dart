import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/operations.dart';
import '../../navigation/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/status_chip.dart';
import '../service/reservation_detail_sheet.dart';
import 'home_sections.dart';

/// ─── Today's Overview ──────────────────────────────────────────────────────

/// A small green dot that marks the dashboard numbers as live.
///
/// It is deliberately not an animation. The 30-second refresh is the pulse: a
/// repeating controller would schedule a frame for as long as Home is on
/// screen, which both costs a phone that holds the board open all evening and
/// stops `pumpAndSettle` from ever returning in a widget test.
class LivePulseIndicator extends StatelessWidget {
  const LivePulseIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Updating automatically',
      child: const SizedBox(
        width: 6,
        height: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// The four numbers the desk checks first: bookings, tables, live deals and
/// the evening book.
///
/// Every value is a live dashboard counter. Each tile taps through to the
/// surface that explains it, so the overview is a doorway rather than a report:
/// deals management stays in Deals and the analytics stay in Insights.
class TodaysOverview extends StatelessWidget {
  const TodaysOverview({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final today = snapshot.today;
    final counters = today.reservations;
    final pending = counters.pending;
    final activeDeals = snapshot.deals.active;
    final upcomingExperiences = snapshot.events.upcoming;

    final cards = <Widget>[
      _KpiCard(
        value: '${counters.booked}',
        label: 'Reservations',
        icon: Icons.event_available,
        color: AppColors.primary,
        caption: pending > 0 ? '$pending to confirm' : 'All confirmed',
        captionColor: pending > 0 ? AppColors.warning : AppColors.success,
        onTap: () => _go(context, '${AppRoute.service}?tab=reservations'),
      ),
      _KpiCard(
        value: '${today.tables}',
        label: 'Tables',
        icon: Icons.table_restaurant_outlined,
        color: AppColors.info,
        caption: today.hasCapacityConfigured
            ? 'of ${today.capacity} seats'
            : (today.tables == 0 ? 'Not set up' : 'In service'),
        onTap: () => _go(context, '${AppRoute.service}?tab=tables'),
      ),
      _KpiCard(
        value: '$activeDeals',
        label: 'Active Deals',
        icon: Icons.local_offer_outlined,
        color: AppColors.gold,
        caption: activeDeals == 0 ? 'None live' : 'Live now',
        onTap: () => _go(context, '${AppRoute.business}?tab=deals'),
      ),
      _KpiCard(
        value: '$upcomingExperiences',
        label: 'Experiences',
        icon: Icons.auto_awesome_outlined,
        color: AppColors.success,
        caption: upcomingExperiences == 0 ? 'None upcoming' : 'Upcoming',
        onTap: () => _go(context, '${AppRoute.experiences}?tab=experiences'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionLabel(title: "Today's Overview")),
            const SizedBox(width: AppSpacing.sm),
            const LivePulseIndicator(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        _KpiGrid(cards: cards),
      ],
    );
  }

  void _go(BuildContext context, String route) =>
      Navigator.of(context).pushReplacementNamed(route);
}

/// Four tiles across a wide window, two by two on a phone, one column only when
/// a card can no longer hold its own label.
///
/// Paired cards share the taller height, so a caption on one side never leaves
/// the row looking like two different components.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth >= 700 && scale < 1.3
            ? 4
            : (scale >= 1.8 || constraints.maxWidth < 300 ? 1 : 2);
        if (columns == 1) {
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
        for (var i = 0; i < cards.length; i += columns) {
          final row = cards.sublist(
            i,
            (i + columns).clamp(0, cards.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < row.length; j++) ...[
                    if (j > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: row[j]),
                  ],
                  // A short final row keeps the same tile width as a full one.
                  for (var j = row.length; j < columns; j++) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
          if (i + columns < cards.length) {
            rows.add(const SizedBox(height: AppSpacing.sm));
          }
        }
        return Column(children: rows);
      },
    );
  }
}

/// One metric tile: a small tinted icon, the counter, and one line that says
/// what the counter means.
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.caption,
    this.captionColor,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String caption;
  final Color? captionColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXs + 3),
                      ),
                      child: Icon(icon, color: color, size: 15),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppTextStyles.numericLarge.copyWith(
                      fontSize: 24,
                      height: 1.05,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  caption,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: captionColor ?? AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── Quick Actions ─────────────────────────────────────────────────────────

/// The four things a desk does between tables.
///
/// Every tile lands on a registered route: the menu and QR tiles on a `?tab=`
/// of the Business section, *Create Deal* asking its destination to open the
/// creation form, and *Reservations* opening the day board. The destinations
/// still own the venue-verification and role rules, so an unverified venue sees
/// why an action is unavailable instead of being walked into a form it cannot
/// submit.
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _QuickActionTile(
        tileKey: const ValueKey('home-quick-reservations'),
        icon: Icons.event_note,
        label: 'Reservations',
        color: AppColors.primary,
        onTap: () =>
            Navigator.of(context)
                .pushReplacementNamed('${AppRoute.service}?tab=reservations'),
      ),
      _QuickActionTile(
        tileKey: const ValueKey('home-quick-menu'),
        icon: Icons.restaurant_menu,
        label: 'Edit Menu',
        color: AppColors.info,
        onTap: () =>
            Navigator.of(context)
                .pushReplacementNamed('${AppRoute.business}?tab=menu'),
      ),
      _QuickActionTile(
        tileKey: const ValueKey('home-quick-deal'),
        icon: Icons.local_offer_outlined,
        label: 'Create Deal',
        color: AppColors.gold,
        onTap: () => Navigator.of(context)
            .pushReplacementNamed('${AppRoute.business}?tab=deals&create=1'),
      ),
      _QuickActionTile(
        tileKey: const ValueKey('home-quick-qr'),
        icon: Icons.qr_code_2,
        label: 'Show QR',
        color: AppColors.success,
        onTap: () =>
            Navigator.of(context)
                .pushReplacementNamed('${AppRoute.business}?tab=qr'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(title: 'Quick Actions'),
        const SizedBox(height: AppSpacing.sm + 2),
        _QuickActionGrid(tiles: tiles),
      ],
    );
  }
}

/// Two by two on a phone, four across when the window can hold them.
///
/// Four-across was the original phone shape and it never worked: at 320 dp a
/// column is 70 dp wide, so a two-word label broke over three lines. Two tiles
/// with room to breathe read faster from across a dining room than four
/// cramped ones.
class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth >= 700 && scale < 1.3
            ? 4
            : (constraints.maxWidth < 300 || scale >= 1.8 ? 1 : 2);
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                tiles[i],
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += columns) {
          final row = tiles.sublist(
            i,
            (i + columns).clamp(0, tiles.length),
          );
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < row.length; j++) ...[
                    if (j > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: row[j]),
                  ],
                  for (var j = row.length; j < columns; j++) ...[
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              ),
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

/// One quick action: a tinted icon and the verb it performs.
///
/// No caption. The label is the whole invitation, and a second line under it
/// ("Dishes & prices", "Menu on the table") was four pieces of prose competing
/// with four verbs on the same screen.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusMd);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          key: tileKey,
          onTap: onTap,
          child: ConstrainedBox(
            // 32 dp chip plus 12 above and below clears the 44 dp tap target
            // without a second wrapper.
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 6,
                vertical: AppSpacing.sm + 4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Text(
                      label,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── Today's Reservations ──────────────────────────────────────────────────

/// The bookings that still hold a table: pending, confirmed or seated.
///
/// Cancelled, completed and no-show rows are history, not upcoming, so they are
/// dropped. A *pending* booking is kept, it still needs a confirmation, and
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
  });

  final AsyncValue<List<Reservation>> reservations;
  final String venueId;

  /// Re-reads the day list without touching the rest of the screen.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: "Today's Reservations",
          trailing: SectionLink(
            label: 'View all',
            onPressed: () => Navigator.of(context)
                .pushReplacementNamed('${AppRoute.service}?tab=reservations'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        reservations.when(
          skipLoadingOnRefresh: true,
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
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < displayList.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: AppSpacing.md,
                        color: AppColors.border,
                      ),
                    _ReservationTile(
                      reservation: displayList[i],
                      venueId: venueId,
                    ),
                  ],
                  if (hidden > 0) ...[
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: AppSpacing.md,
                      color: AppColors.border,
                    ),
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
      onTap: () =>
          Navigator.of(context)
              .pushReplacementNamed('${AppRoute.service}?tab=reservations'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.more_horiz,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '$count more ${count == 1 ? 'booking' : 'bookings'} today',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
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
    return const SectionSkeleton(rows: 2, height: 64);
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Unable to load reservations',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

/// One line that says the day is clear, and nothing more.
///
/// The previous version spent four lines explaining how reservations arrive,
/// on the screen a busy venue sees last before opening. The absence of work
/// does not need a paragraph.
class _EmptyReservations extends StatelessWidget {
  const _EmptyReservations();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Text(
              'No reservations today',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
    // At a large text scale the trailing pill would squeeze the guest name to
    // an ellipsis, so it moves under the source line and the row keeps its
    // hierarchy on one thumb-wide column.
    final inlineChip = MediaQuery.textScalerOf(context).scale(1) < 1.6;
    final chip = StatusChip(
      status: reservation.status.wire,
      label: reservation.status.label,
      dense: true,
    );

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
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reservation.partyLabel,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Container(width: 1, height: 30, color: AppColors.border),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!inlineChip) ...[
                    const SizedBox(height: AppSpacing.xs + 2),
                    Align(alignment: Alignment.centerLeft, child: chip),
                  ],
                ],
              ),
            ),
            if (inlineChip) ...[
              const SizedBox(width: AppSpacing.sm),
              chip,
            ],
          ],
        ),
      ),
    );
  }
}

/// ─── Needs Attention ───────────────────────────────────────────────────────

/// The decisions the desk owes, shown only when there are any.
///
/// The section used to hold a permanent "All caught up" card, which spent a
/// dashboard row telling an operator that nothing needed doing. It now renders
/// nothing at all, so the space belongs to work.
///
/// The order *is* the priority: a booking waiting for a confirmation holds a
/// table, a host request waits for a decision, and an unverified venue cannot
/// sell anything. Unread messages are not listed here: the header bell already
/// carries that count and opens the inbox, and a second copy on Home was one
/// thing to read twice.
class NeedsAttentionSection extends StatelessWidget {
  const NeedsAttentionSection({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = _buildNeedsAttentionList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(title: 'Needs attention'),
          const SizedBox(height: AppSpacing.sm + 2),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 56,
                      color: AppColors.border,
                    ),
                  _NeedsAttentionTile(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
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
    // profile.
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(item.icon, color: item.color, size: 17),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    maxLines: 1,
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

/// ─── Skeleton ──────────────────────────────────────────────────────────────

/// The Home skeleton.
///
/// It is a scroll view, not a column: the same blocks have to fit a short
/// landscape window as well as a tall phone, and a skeleton that overflows is
/// the first thing the desk sees on a slow connection. The block heights trace
/// the real sections so the page never jumps when the data lands.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const radius = AppSpacing.radiusLg;
    Widget block(double height, {double? width}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
    );

    // Section headings are a thin bar, not a card.
    Widget label(double width) => Container(
      height: 11,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      ),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.paddingScreen),
      children: [
        block(108),
        const SizedBox(height: AppSpacing.lg),
        label(118),
        const SizedBox(height: AppSpacing.sm + 2),
        Row(
          children: [
            Expanded(child: block(104)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: block(104)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: block(104)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: block(104)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        label(96),
        const SizedBox(height: AppSpacing.sm + 2),
        Row(
          children: [
            Expanded(child: block(56)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: block(56)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: block(56)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: block(56)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        label(150),
        const SizedBox(height: AppSpacing.sm + 2),
        block(72),
        const SizedBox(height: AppSpacing.sm),
        block(72),
      ],
    );
  }
}
