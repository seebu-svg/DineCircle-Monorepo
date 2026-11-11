import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/deals.dart';
import '../../models/venue.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../widgets/media_image.dart';

/// ─── Summary ───────────────────────────────────────────────────────────────

/// The figures the deals header reports.
///
/// Folded from the deals actually loaded for this venue, so a number on the
/// screen is always a number the partner could tap through to.
/// `redemptionsKnown` exists because an absent counter must read as "not
/// measured", never as zero uses: the same rule [Deal.redemptionLabel] follows.
class DealSummary {
  const DealSummary({
    required this.total,
    required this.active,
    required this.drafts,
    required this.paused,
    required this.expired,
    required this.expiringSoon,
    required this.redemptions,
    required this.redemptionsKnown,
  });

  factory DealSummary.of(List<Deal> deals) {
    var redemptions = 0;
    var redemptionsKnown = false;
    for (final deal in deals) {
      if (deal.redemptionsReported) {
        redemptionsKnown = true;
        redemptions += deal.redemptions;
      }
    }
    int count(DealStatus status) =>
        deals.where((deal) => deal.status == status).length;
    return DealSummary(
      total: deals.length,
      active: count(DealStatus.active),
      drafts: count(DealStatus.draft),
      paused: count(DealStatus.paused),
      expired: count(DealStatus.expired),
      expiringSoon: deals.where((deal) => deal.isExpiringSoon).length,
      redemptions: redemptions,
      redemptionsKnown: redemptionsKnown,
    );
  }

  final int total;
  final int active;
  final int drafts;
  final int paused;
  final int expired;
  final int expiringSoon;
  final int redemptions;
  final bool redemptionsKnown;

  int countFor(DealStatus? status) => switch (status) {
    null => total,
    DealStatus.active => active,
    DealStatus.draft => drafts,
    DealStatus.paused => paused,
    DealStatus.expired => expired,
  };
}

/// ─── Header ────────────────────────────────────────────────────────────────

/// The compact identity block at the top of Deals & Offers.
///
/// It states whose offers these are and what the screen is for, then carries
/// the three figures a partner acts on: what is running, what guests have used,
/// and what is still waiting to be published. Each figure doubles as its own
/// filter, so the numbers are a doorway rather than a report.
///
/// It replaced a title row above four separate statistic cards. Those cards
/// spent a third of a phone screen repeating counts that now live in one
/// bordered strip, and their coloured fills competed with the orange offer
/// value on every promotion below them.
class DealsHeaderCard extends StatelessWidget {
  const DealsHeaderCard({
    super.key,
    required this.venue,
    required this.description,
    required this.summary,
    required this.selectedStatus,
    required this.byPopularity,
    required this.onSelectStatus,
    required this.onTogglePopularity,
  });

  final Venue? venue;

  /// What this screen is, in the venue's own terms.
  final String description;

  final DealSummary summary;

  /// The status the list is narrowed to, so the matching figure reads as
  /// selected even after the chips have scrolled out of reach.
  final DealStatus? selectedStatus;

  /// True while the list is ordered by most redeemed.
  final bool byPopularity;

  final ValueChanged<DealStatus> onSelectStatus;
  final VoidCallback onTogglePopularity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _venueTile(),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Deals & Offers',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          _Indicators(
            cells: [
              _IndicatorCell(
                label: 'Active deals',
                value: '${summary.active}',
                selected: !byPopularity && selectedStatus == DealStatus.active,
                onTap: () => onSelectStatus(DealStatus.active),
              ),
              _IndicatorCell(
                label: 'Redemptions',
                value: summary.redemptionsKnown ? '${summary.redemptions}' : '–',
                // An unmeasured counter is blank, not zero, and the hint says
                // why rather than leaving a dash to be guessed at.
                hint: summary.redemptionsKnown ? null : 'Not reported',
                selected: byPopularity,
                onTap: onTogglePopularity,
              ),
              _IndicatorCell(
                label: 'Drafts',
                value: '${summary.drafts}',
                selected: !byPopularity && selectedStatus == DealStatus.draft,
                onTap: () => onSelectStatus(DealStatus.draft),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The venue logo, its cover, or the storefront fallback.
  Widget _venueTile() {
    final logo = (venue?.logo ?? '').trim();
    final cover = (venue?.coverImage ?? '').trim();
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
        border: Border.all(color: AppColors.border),
      ),
      child: MediaImage(
        source: logo.isNotEmpty ? logo : cover,
        fallbackIcon: Icons.storefront,
      ),
    );
  }
}

/// Three figures in one hairline strip.
///
/// Side by side while a cell can hold its own label; stacked into label/value
/// rows once the text scale or the width would truncate "Redemptions" into
/// "Redempt…". A count nobody can read is not a performance indicator.
class _Indicators extends StatelessWidget {
  const _Indicators({required this.cells});

  final List<_IndicatorCell> cells;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = constraints.maxWidth < 300 || scale >= 1.5;
        final body = stacked
            ? Column(
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    cells[i].buildRow(context),
                  ],
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cells.length; i++) ...[
                      if (i > 0) Container(width: 1, color: AppColors.border),
                      Expanded(child: cells[i].buildCell(context)),
                    ],
                  ],
                ),
              );
        return Material(
          color: AppColors.surfaceElevated,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: const BorderSide(color: AppColors.border),
          ),
          child: body,
        );
      },
    );
  }
}

/// One figure, and the filter it stands for.
///
/// Not a widget: the strip asks it for one of two layouts, and a widget could
/// only answer with a single `build` whose layout depends on constraints it
/// would then have to rediscover inside itself.
class _IndicatorCell {
  const _IndicatorCell({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  /// Explains a figure that cannot be shown, in the cell rather than nowhere.
  final String? hint;

  /// Wide layout: the figure over its label.
  Widget buildCell(BuildContext context) {
    return _shell(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // A three-digit counter at 2x text would push the strip wider than
            // the phone; it scales down instead of overflowing its cell.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: AppTextStyles.numericMedium.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint ?? label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Narrow or large-text layout: label on the left, figure on the right.
  Widget buildRow(BuildContext context) {
    return _shell(
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12.5,
                    color: secondaryText(selected),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                value,
                maxLines: 2,
                style: AppTextStyles.numericMedium.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color secondaryText(bool selected) =>
      selected ? AppColors.primary : AppColors.textSecondary;

  Widget _shell(Widget child) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label: $value',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          child: InkWell(onTap: onTap, child: child),
        ),
      ),
    );
  }
}

/// ─── Primary action ────────────────────────────────────────────────────────

/// The one action this screen exists for, at a size a thumb cannot miss.
class DealsActionBar extends StatelessWidget {
  const DealsActionBar({
    super.key,
    required this.canManage,
    required this.onAdd,
    required this.reason,
  });

  final bool canManage;
  final VoidCallback onAdd;

  /// Why the button is disabled, shown as the tooltip.
  final String reason;

  @override
  Widget build(BuildContext context) {
    // Past ~1.6x the label no longer fits beside the icon on a phone, and an
    // ellipsised verb ("New de…") is worse than the short one.
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return Tooltip(
      message: canManage ? '' : reason,
      child: ConstrainedBox(
        key: const ValueKey('deals-add'),
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: FilledButton.icon(
          onPressed: canManage ? onAdd : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.surfaceHigh,
            disabledForegroundColor: AppColors.textTertiary,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            large ? 'New' : 'New deal',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// ─── Status filters ────────────────────────────────────────────────────────

/// Horizontally scrollable status filters.
///
/// Counts are deliberately absent: the header strip already carries the figures
/// that matter, and a chip repeating "Active 3" next to a card wearing an
/// "Active" badge is the third place the same word appears in one screenful.
class DealStatusRail extends StatelessWidget {
  const DealStatusRail({
    super.key,
    required this.selected,
    required this.expiringOnly,
    required this.onSelect,
    required this.onExpiring,
    this.horizontalInset = AppSpacing.paddingScreen,
  });

  /// Null means "All".
  final DealStatus? selected;
  final bool expiringOnly;
  final void Function(DealStatus? status) onSelect;
  final VoidCallback onExpiring;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.minTapTarget - 8,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalInset),
        children: [
          for (final entry in const <MapEntry<DealStatus?, String>>[
            MapEntry(null, 'All'),
            MapEntry(DealStatus.active, 'Active'),
            MapEntry(DealStatus.draft, 'Drafts'),
            MapEntry(DealStatus.paused, 'Paused'),
            MapEntry(DealStatus.expired, 'Expired'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _RailChip(
                label: entry.value,
                selected: !expiringOnly && selected == entry.key,
                onTap: () => onSelect(entry.key),
              ),
            ),
          _RailChip(
            icon: Icons.timer_outlined,
            label: 'Ending soon',
            selected: expiringOnly,
            onTap: onExpiring,
          ),
        ],
      ),
    );
  }
}

class _RailChip extends StatelessWidget {
  const _RailChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 13,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    maxLines: 1,
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 11.5,
                      letterSpacing: 0.1,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

/// One line naming what the list is showing, with the way back.
class DealsFilterSummary extends StatelessWidget {
  const DealsFilterSummary({
    super.key,
    required this.caption,
    required this.onClear,
  });

  final String caption;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            caption,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: onClear,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

/// ─── Status badge ──────────────────────────────────────────────────────────

/// The one place a deal states where it sits in its lifecycle.
///
/// Timing, limits and scheduled starts are facts about the offer, phrased as
/// sentences under the value; they are not a second status badge, so a card
/// never reads "Paused" twice in two different colours.
class DealStatusPill extends StatelessWidget {
  const DealStatusPill({super.key, required this.status});

  final DealStatus status;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status.wire);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              status.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.1,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Card ──────────────────────────────────────────────────────────────────

/// One promotion: what the guest saves, whether it is live, when it ends and
/// how much of it has been used.
///
/// Presentational on purpose. Every action is a callback and every write is
/// owned by the screen, which holds the in-flight set, so two cards cannot
/// disagree about who is busy and the list refreshes from one place.
///
/// The card has no fixed height and no cover band. A deal without a banner used
/// to reserve 132dp for a grey placeholder, which on a phone pushed the only
/// two actions on the row below the fold; now the banner is a 44dp thumbnail
/// and a deal with no photo simply has none.
class DealCard extends StatelessWidget {
  const DealCard({
    super.key,
    required this.deal,
    required this.canManage,
    required this.canRedeem,
    required this.onOpen,
    required this.onEdit,
    required this.onDuplicate,
    required this.onPreview,
    required this.onStatus,
    required this.onDelete,
    required this.onRedeem,
    this.busy = false,
  });

  final Deal deal;

  /// Manager, and the venue may sell. Drives edit, duplicate and lifecycle.
  final bool canManage;

  /// Staff is enough to count a redemption, matching the redeem route.
  final bool canRedeem;

  /// Opens the details view: everything the card has no room for.
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onPreview;
  final void Function(DealStatus next) onStatus;
  final VoidCallback onDelete;
  final VoidCallback onRedeem;
  final bool busy;

  bool get _canRedeem => canRedeem && deal.isRedeemable;

  @override
  Widget build(BuildContext context) {
    final d = deal;
    final hasImage = d.imageUrl.trim().isNotEmpty;
    final radius = BorderRadius.circular(AppSpacing.radiusMd);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onOpen,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.marginItem),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage) ...[
                      _DealThumb(imageUrl: d.imageUrl),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  d.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                    letterSpacing: -0.1,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 92),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: DealStatusPill(status: d.status),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.valueLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.numericMedium.copyWith(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              color: d.status == DealStatus.expired
                                  ? AppColors.textTertiary
                                  : AppColors.primary,
                            ),
                          ),
                          if (d.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              d.description.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 12.5,
                                height: 1.35,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                _FactLine(
                  icon: Icons.event_outlined,
                  text: dealEndLabel(d),
                  color: d.isExpiringSoon ? AppColors.warning : null,
                ),
                const SizedBox(height: 6),
                _RedemptionLine(deal: d),
                const SizedBox(height: AppSpacing.sm + 2),
                // The row is always there, even when neither action applies: a
                // staff member on a draft cannot redeem or edit it, but can
                // still read it and preview it as a guest, and those live in
                // the menu.
                if (busy)
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Updating…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_canRedeem)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onRedeem,
                            icon: const Icon(Icons.how_to_reg_outlined,
                                size: 16),
                            label: const Text('Redeem'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                              side: BorderSide(
                                color: AppColors.primary.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_canRedeem && canManage)
                        const SizedBox(width: AppSpacing.sm),
                      if (canManage)
                        Expanded(
                          child: TextButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                              ),
                            ),
                          ),
                        ),
                      if (_canRedeem || canManage)
                        const SizedBox(width: AppSpacing.xs),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: DealActionsMenu(
                          deal: d,
                          busy: busy,
                          canManage: canManage,
                          onOpen: onOpen,
                          onEdit: onEdit,
                          onDuplicate: onDuplicate,
                          onPreview: onPreview,
                          onStatus: onStatus,
                          onDelete: onDelete,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One icon + sentence line under a card's value.
class _FactLine extends StatelessWidget {
  const _FactLine({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color ?? AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 11.5,
              color: color ?? AppColors.textSecondary,
              fontWeight: color == null ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// How much of a capped offer has been spent, or the honest reason there is no
/// meter to draw.
class _RedemptionLine extends StatelessWidget {
  const _RedemptionLine({required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    if (!deal.redemptionsReported) {
      return const _FactLine(
        icon: Icons.redeem_outlined,
        text: 'Redemptions not reported',
      );
    }
    final cap = deal.maxRedemptions;
    final progress = deal.redemptionProgress;
    if (cap == null || progress == null) {
      return _FactLine(
        icon: Icons.redeem_outlined,
        text: deal.redemptions == 1
            ? '1 redemption · no limit'
            : '${deal.redemptions} redemptions · no limit',
      );
    }
    final left = deal.redemptionsLeft ?? 0;
    final color = deal.isLimitReached
        ? AppColors.danger
        : (progress >= 0.8 ? AppColors.warning : AppColors.primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.redeem_outlined, size: 13, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${deal.redemptions} of $cap redeemed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              deal.isLimitReached ? 'Limit reached' : '$left left',
              maxLines: 1,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 11,
                letterSpacing: 0.1,
                fontWeight: FontWeight.w600,
                color: deal.isLimitReached ? AppColors.danger : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

/// The promotion's banner, at the size a list row can afford.
class _DealThumb extends StatelessWidget {
  const _DealThumb({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
      child: SizedBox(
        width: 44,
        height: 44,
        child: MediaImage(
          source: imageUrl,
          fallbackIcon: Icons.local_offer_outlined,
          cacheWidth: 220,
        ),
      ),
    );
  }
}

/// ─── Actions ───────────────────────────────────────────────────────────────

/// The secondary operations, in one menu.
///
/// Built from the transition map, so nothing here can offer a move the server
/// would answer with `409`. The primary pair (Redeem, Edit) stays on the card;
/// what does not fit there lives here rather than in a row of four buttons that
/// a 320dp phone cannot hold.
class DealActionsMenu extends StatelessWidget {
  const DealActionsMenu({
    super.key,
    required this.deal,
    required this.busy,
    required this.canManage,
    required this.onOpen,
    required this.onEdit,
    required this.onDuplicate,
    required this.onPreview,
    required this.onStatus,
    required this.onDelete,
    this.iconSize = 18,
  });

  final Deal deal;
  final bool busy;
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onPreview;
  final void Function(DealStatus next) onStatus;
  final VoidCallback onDelete;
  final double iconSize;

  static String _transitionLabel(Deal deal, DealStatus to) {
    if (to == DealStatus.expired) return 'Retire deal';
    if (to == DealStatus.paused) return 'Pause deal';
    return deal.status == DealStatus.paused ? 'Resume deal' : 'Publish deal';
  }

  @override
  Widget build(BuildContext context) {
    final d = deal;
    // A retired deal has no move left, so the lifecycle block disappears on its
    // own; the entries that stay readable and duplicable remain offered.
    final hasLifecycle = canManage && d.allowedTransitions.isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: 'Deal actions',
      // Details and preview need no role beyond reading the venue's own offers,
      // so the menu is only ever closed by an in-flight write.
      enabled: !busy,
      padding: EdgeInsets.zero,
      color: AppColors.surfaceElevated,
      icon: Icon(
        Icons.more_horiz,
        size: iconSize,
        color: AppColors.textTertiary,
      ),
      onSelected: (action) => switch (action) {
        'details' => onOpen(),
        'edit' => onEdit(),
        'duplicate' => onDuplicate(),
        'preview' => onPreview(),
        'delete' => onDelete(),
        _ => onStatus(DealStatus.parse(action)),
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'details', child: Text('Deal details')),
        const PopupMenuItem(value: 'preview', child: Text('Preview as guest')),
        if (canManage) ...[
          PopupMenuItem(
            value: 'edit',
            child: Text(d.isDraft ? 'Edit draft' : 'Edit deal'),
          ),
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          if (hasLifecycle)
            for (final to in d.allowedTransitions)
              PopupMenuItem(
                value: to.wire,
                child: Text(_transitionLabel(d, to)),
              ),
          if (d.isDeleteable)
            const PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete draft',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ],
    );
  }
}

/// ─── Date wording ──────────────────────────────────────────────────────────

/// The line under a card's value: when the offer stops, or when it starts.
///
/// A scheduled deal names both dates, because "Ends 30 Nov" on an offer nobody
/// can use yet is true and useless. A deal that has run out says so in the past
/// tense rather than inviting a tap that would be refused.
String dealEndLabel(Deal deal) {
  final now = DateTime.now();
  final end = deal.endsAt.toLocal();
  if (!end.isAfter(now)) {
    final days = ServiceDate.daysBetween(end, now);
    return days <= 0 ? 'Ended today' : 'Ended $days ${_days(days)} ago';
  }
  final start = deal.startsAt.toLocal();
  if (start.isAfter(now)) {
    return 'Starts ${DisplayDate.monthDay(start)} · ends '
        '${DisplayDate.monthDay(end)}';
  }
  final days = ServiceDate.daysBetween(now, end);
  if (days <= 0) return 'Ends today';
  if (days <= 7) {
    return 'Ends ${DisplayDate.monthDay(end)} · in $days ${_days(days)}';
  }
  return 'Ends ${DisplayDate.full(end)}';
}

String _days(int count) => count == 1 ? 'day' : 'days';

/// `9 Nov 2026 – 30 Nov 2026 · ends in 21 days`.
///
/// Kept verbatim for the guest preview, which shows the whole window the way
/// the Customer App prints it.
String dealValidity(Deal deal) {
  final base = '${_shortDate(deal.startsAt)} – ${_shortDate(deal.endsAt)}';
  final now = DateTime.now();
  if (!deal.endsAt.isAfter(now)) {
    final overdue = now.difference(deal.endsAt).inDays;
    return '$base · ended ${overdue <= 0 ? 'today' : '$overdue d ago'}';
  }
  final days = deal.endsAt.difference(now).inDays;
  if (days == 0) return '$base · ends today';
  return '$base · $days d left';
}

String _shortDate(DateTime date) {
  final local = date.toLocal();
  return '${DisplayDate.monthDay(local)}, ${local.year}';
}

/// ─── Details ───────────────────────────────────────────────────────────────

/// Opens the full record of one promotion.
///
/// Tapping a card lands here rather than in the edit form: reading an offer is
/// the common case and editing it is the deliberate one.
Future<void> showDealDetails(
  BuildContext context, {
  required Deal deal,
  required String venueName,
  required bool canManage,
  required bool canRedeem,
  required bool busy,
  required VoidCallback onEdit,
  required VoidCallback onDuplicate,
  required VoidCallback onPreview,
  required VoidCallback onDelete,
  required void Function(DealStatus next) onStatus,
  required VoidCallback onRedeem,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => DealDetailsSheet(
    deal: deal,
    venueName: venueName,
    canManage: canManage,
    canRedeem: canRedeem,
    busy: busy,
    onEdit: onEdit,
    onDuplicate: onDuplicate,
    onPreview: onPreview,
    onDelete: onDelete,
    onStatus: onStatus,
    onRedeem: onRedeem,
  ),
);

/// Everything the card has no room for: the exact window, the conditions, the
/// promo code and the counter.
///
/// Actions close the sheet before they run. Every one of them either opens
/// another sheet, asks a question or changes the row underneath, and a details
/// sheet still showing the previous status while a publish request travels
/// would be the last place a partner sees the truth.
class DealDetailsSheet extends StatelessWidget {
  const DealDetailsSheet({
    super.key,
    required this.deal,
    required this.venueName,
    required this.canManage,
    required this.canRedeem,
    required this.busy,
    required this.onEdit,
    required this.onDuplicate,
    required this.onPreview,
    required this.onDelete,
    required this.onStatus,
    required this.onRedeem,
  });

  final Deal deal;
  final String venueName;
  final bool canManage;
  final bool canRedeem;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onPreview;
  final VoidCallback onDelete;
  final void Function(DealStatus next) onStatus;
  final VoidCallback onRedeem;

  /// The Customer App splits conditions on this marker into two headings, so
  /// the details view has to split the same way or the partner reads a
  /// different order here than the guest does.
  static const String _redeemMarker = 'how to redeem:';

  void _afterClose(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final d = deal;
    final terms = d.terms.trim();
    final marker = terms.toLowerCase().indexOf(_redeemMarker);
    final conditions = marker < 0 ? terms : terms.substring(0, marker).trim();
    final steps = marker < 0
        ? ''
        : terms.substring(marker + _redeemMarker.length).trim();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    final showRedeem = canRedeem && d.isRedeemable;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Deal details',
                          style: AppTextStyles.overline.copyWith(
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.title,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  DealActionsMenu(
                    deal: d,
                    busy: busy,
                    canManage: canManage,
                    iconSize: 20,
                    onOpen: () {},
                    onEdit: () => _afterClose(context, onEdit),
                    onDuplicate: () => _afterClose(context, onDuplicate),
                    onPreview: () => _afterClose(context, onPreview),
                    onStatus: (next) => _afterClose(context, () => onStatus(next)),
                    onDelete: () => _afterClose(context, onDelete),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          d.valueLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.numericLarge.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: d.status == DealStatus.expired
                                ? AppColors.textTertiary
                                : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      DealStatusPill(status: d.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.mechanicLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (d.description.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      d.description.trim(),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _SheetSection(
                    title: 'Validity',
                    children: [
                      _DetailFact(
                        label: 'Starts',
                        value: DisplayDate.full(d.startsAt.toLocal()),
                      ),
                      _DetailFact(
                        label: 'Ends',
                        value: DisplayDate.full(d.endsAt.toLocal()),
                      ),
                      _DetailFact(
                        label: 'Right now',
                        value: dealStatusSentence(d),
                      ),
                    ],
                  ),
                  _SheetSection(
                    title: 'Eligibility and conditions',
                    children: [
                      Text(
                        conditions.isEmpty
                            ? 'No conditions added. Guests see only the dates '
                                  'and the discount.'
                            : conditions,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 13,
                          height: 1.45,
                          color: conditions.isEmpty
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (steps.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _DetailFact(label: 'How to redeem', value: steps),
                      ],
                    ],
                  ),
                  _SheetSection(
                    title: 'Promotion code',
                    children: [
                      if (d.code?.isNotEmpty ?? false)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm + 2,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  d.code!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontSize: 13,
                                    letterSpacing: 1,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton(
                              tooltip: 'Copy code',
                              onPressed: () => _copyCode(context, d.code!),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              color: AppColors.textSecondary,
                            ),
                          ],
                        )
                      else
                        Text(
                          'No code. Guests redeem by mentioning the offer at '
                          'the table.',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                  _SheetSection(
                    title: 'Redemption activity',
                    children: [
                      _DetailFact(
                        label: 'Recorded',
                        value: d.redemptionsReported
                            ? '${d.redemptions}'
                            : 'Not reported',
                      ),
                      _DetailFact(
                        label: 'Usage limit',
                        value: d.maxRedemptions?.toString() ?? 'No limit',
                      ),
                      if (d.redemptionsLeft != null)
                        _DetailFact(
                          label: 'Remaining',
                          value: '${d.redemptionsLeft}',
                        ),
                      if (d.redemptionProgress != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusPill,
                          ),
                          child: LinearProgressIndicator(
                            value: d.redemptionProgress,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceHigh,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              d.isLimitReached ? AppColors.danger : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      // The platform counts uses; it does not store who used
                      // them. Saying that is better than a history section
                      // that is silently always empty.
                      Text(
                        'Redemptions are counted in total. Individual uses are '
                        'not stored, so there is no per-guest history to show.',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          venueName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            fontSize: 11.5,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showRedeem || canManage)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (showRedeem)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _afterClose(context, onRedeem),
                          icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                          label: const Text('Redeem'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, AppSpacing.minTapTarget),
                          ),
                        ),
                      ),
                    if (showRedeem && canManage)
                      const SizedBox(width: AppSpacing.sm),
                    if (canManage)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _afterClose(context, onEdit),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            minimumSize: const Size(0, AppSpacing.minTapTarget),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    var copied = true;
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } catch (_) {
      // A device without a clipboard channel still gets told something true,
      // and the code stays on screen to be read out either way.
      copied = false;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copied ? 'Code $code copied' : 'Code $code · copy by hand'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// One headed block inside the details sheet.
class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleSmall.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }
}

/// A label over its value: stacked, so a long rule or a long window never has
/// to share a row with its own heading on a narrow phone.
class _DetailFact extends StatelessWidget {
  const _DetailFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 11,
              letterSpacing: 0.1,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the offer sits in its lifecycle, written as a partner sentence.
String dealStatusSentence(Deal deal) {
  final now = DateTime.now();
  if (deal.status == DealStatus.draft) {
    return 'Draft · only you can see this offer';
  }
  if (deal.status == DealStatus.paused) {
    return 'Paused · hidden from guests, can be resumed';
  }
  if (deal.status == DealStatus.expired || !deal.endsAt.isAfter(now)) {
    return 'Ended · no longer shown to guests';
  }
  if (deal.startsAt.isAfter(now)) {
    return 'Scheduled · goes live ${DisplayDate.day(deal.startsAt.toLocal())}';
  }
  if (deal.isLimitReached) return 'Live · but fully redeemed';
  return 'Live · visible to guests now';
}

/// ─── Guest preview ─────────────────────────────────────────────────────────

/// Opens the guest-facing view of one deal.
Future<void> showDealPreview(
  BuildContext context, {
  required Deal deal,
  required String venueName,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => DealPreviewSheet(deal: deal, venueName: venueName),
);

/// What a guest sees, before the partner commits to it.
///
/// The public route answers `status = 'active' AND ends_at > now()`, and nothing
/// else, so the visibility line below is that predicate written out. It says
/// "fully redeemed" separately, because a capped-out offer is still listed even
/// though nobody can honour it any more, and finding that out at the table is
/// the kind of surprise this sheet exists to prevent.
class DealPreviewSheet extends StatelessWidget {
  const DealPreviewSheet({
    super.key,
    required this.deal,
    required this.venueName,
  });

  final Deal deal;
  final String venueName;

  (bool, String) get _visibility {
    final now = DateTime.now();
    if (deal.status != DealStatus.active) {
      return (
        false,
        switch (deal.status) {
          DealStatus.draft => 'Not published yet · guests cannot see this',
          DealStatus.paused => 'Paused · hidden from guests',
          DealStatus.expired => 'Retired · no longer shown to guests',
          DealStatus.active => '',
        },
      );
    }
    if (!deal.endsAt.isAfter(now)) {
      return (false, 'Past its end date · no longer shown to guests');
    }
    if (deal.startsAt.isAfter(now)) {
      return (
        true,
        'Live · starts publicly on ${DisplayDate.day(deal.startsAt.toLocal())}',
      );
    }
    if (deal.isLimitReached) {
      return (true, 'Live · but the redemption limit is reached');
    }
    return (true, 'Live · visible to guests now');
  }

  @override
  Widget build(BuildContext context) {
    final terms = deal.terms.trim();
    const marker = 'how to redeem:';
    final at = terms.toLowerCase().indexOf(marker);
    final conditions = at < 0 ? terms : terms.substring(0, at).trim();
    final steps = at < 0 ? '' : terms.substring(at + marker.length).trim();
    final (live, visibility) = _visibility;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    final hasImage = deal.imageUrl.trim().isNotEmpty;
    final tone = live ? AppColors.success : AppColors.warning;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Guest preview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: tone.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          live
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 16,
                          color: tone,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            visibility,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 11.5,
                              color: tone,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // No banner means the guest sees the venue cover, which the
                  // public route substitutes. A 168dp grey block here would
                  // read as a broken upload, so the sheet states the fact.
                  if (hasImage) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      child: SizedBox(
                        height: 168,
                        width: double.infinity,
                        child: MediaImage(
                          source: deal.imageUrl,
                          fallbackIcon: Icons.restaurant_menu,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.image_outlined,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Guests see your venue cover photo behind this '
                            'offer.',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    deal.title,
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    deal.valueLabel,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (deal.description.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      deal.description.trim(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _PreviewFact(
                    icon: Icons.calendar_today_outlined,
                    label: 'Valid',
                    value: dealValidity(deal),
                  ),
                  if (deal.code?.isNotEmpty ?? false)
                    _PreviewFact(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Code to quote',
                      value: deal.code!,
                    ),
                  if (conditions.isNotEmpty)
                    _PreviewFact(
                      icon: Icons.description_outlined,
                      label: 'Conditions',
                      value: conditions,
                    ),
                  if (steps.isNotEmpty)
                    _PreviewFact(
                      icon: Icons.how_to_reg_outlined,
                      label: 'How to redeem',
                      value: steps,
                    ),
                  _PreviewFact(
                    icon: Icons.storefront_outlined,
                    label: 'Venue',
                    value: venueName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewFact extends StatelessWidget {
  const _PreviewFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Loading ───────────────────────────────────────────────────────────────

/// The first-load skeleton: the same block heights the real screen uses, so
/// the header and the first card do not jump when the read lands.
class DealsSkeleton extends StatelessWidget {
  const DealsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingScreen,
        AppSpacing.md,
        AppSpacing.paddingScreen,
        AppSpacing.xl,
      ),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _block(134),
        const SizedBox(height: AppSpacing.sm + 2),
        _block(AppSpacing.minTapTarget),
        const SizedBox(height: AppSpacing.sm + 2),
        Row(
          children: const [
            Expanded(child: _PillBlock(width: 52)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _PillBlock(width: 68)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _PillBlock(width: 64)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: _PillBlock(width: 62)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _block(146),
        const SizedBox(height: AppSpacing.marginItem),
        _block(146),
        const SizedBox(height: AppSpacing.marginItem),
        _block(146),
      ],
    );
  }

  Widget _block(double height) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      border: Border.all(color: AppColors.border),
    ),
  );
}

class _PillBlock extends StatelessWidget {
  const _PillBlock({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}
