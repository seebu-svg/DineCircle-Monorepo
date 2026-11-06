import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comms.dart';
import '../../models/deals.dart';
import '../../models/experience.dart';
import '../../navigation/app_routes.dart';
import '../../providers/module_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../utils/money.dart';
import '../../widgets/status_chip.dart';

/// ─── Section label ─────────────────────────────────────────────────────────

/// The overline that opens every Home section: a short accent rule, then the
/// label, then an optional trailing action.
///
/// One widget instead of five copies of the same ad-hoc `letterSpacing: 1.0`
/// style keeps the vertical rhythm of the screen identical everywhere.
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.overline.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// The compact "View all" style used beside a [SectionLabel].
class SectionLink extends StatelessWidget {
  const SectionLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, AppSpacing.minTapTarget),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: AppTextStyles.labelSmall),
    );
  }
}

/// ─── Active deals ──────────────────────────────────────────────────────────

/// The live promotions a guest can redeem right now.
///
/// Only `isLive` rows are shown — an active-but-not-yet-started or expired deal
/// is not something the desk can tell a guest about — and the rail caps at
/// three so Home stays a dashboard rather than a deal list.
class ActiveDealsRail extends ConsumerWidget {
  const ActiveDealsRail({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({String venue, String? status}) query = (
      venue: venueId,
      status: 'active',
    );
    final deals = ref.watch(dealsProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: 'ACTIVE DEALS',
          trailing: SectionLink(
            label: 'Manage',
            onPressed: () => Navigator.of(
              context,
            ).pushReplacementNamed('${AppRoute.business}?tab=deals'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        deals.when(
          skipLoadingOnRefresh: true,
          loading: () => const SectionSkeleton(rows: 1, height: 96),
          error: (error, _) => SectionError(
            message: 'Unable to load deals',
            onRetry: () => ref.invalidate(dealsProvider(query)),
          ),
          data: (rows) {
            final live = rows.where((deal) => deal.isLive).take(3).toList();
            if (live.isEmpty) {
              return SectionEmpty(
                icon: Icons.local_offer_outlined,
                title: 'No live deal right now',
                message: 'Publish an offer and it appears here and in the '
                    'Customer App immediately.',
                actionLabel: 'Create a deal',
                onAction: () => Navigator.of(context).pushReplacementNamed(
                  '${AppRoute.business}?tab=deals&create=1',
                ),
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < live.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    _DealCard(deal: live[i]),
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

class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal});

  final Deal deal;

  /// Percent deals read as a rate; money deals read in PKR, the currency the
  /// whole partner surface quotes prices in.
  String get _valueLabel {
    if (deal.kind.isPercent) return '${deal.value.toStringAsFixed(0)}% off';
    return '${formatMoney(deal.value, currency: 'PKR', decimals: 0)} off';
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    return SizedBox(
      width: 232,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.gold.withValues(alpha: 0.16),
                AppColors.surface,
                AppColors.surfaceElevated,
              ],
            ),
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () => Navigator.of(
              context,
            ).pushReplacementNamed('${AppRoute.business}?tab=deals'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusPill,
                            ),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            _valueLabel,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.local_offer,
                        size: 14,
                        color: AppColors.gold.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    deal.title,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Ends ${DisplayDate.monthDay(deal.endsAt)}',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (deal.redemptionsReported) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${deal.redemptions} redeemed',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── Upcoming experiences ──────────────────────────────────────────────────

/// The next two dining experiences this venue is hosting.
///
/// The partner event feed is account-wide, so the list is filtered to the
/// active venue and to events that are still ahead of the clock — a venue that
/// hosts nothing gets an honest empty state instead of another venue's dinner.
class UpcomingExperiencesStrip extends ConsumerWidget {
  const UpcomingExperiencesStrip({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experiences = ref.watch(experiencesProvider(null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: 'UPCOMING EXPERIENCES',
          trailing: SectionLink(
            label: 'View all',
            onPressed: () => Navigator.of(
              context,
            ).pushReplacementNamed('${AppRoute.experiences}?tab=experiences'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        experiences.when(
          skipLoadingOnRefresh: true,
          loading: () => const SectionSkeleton(rows: 2),
          error: (error, _) => SectionError(
            message: 'Unable to load experiences',
            onRetry: () => ref.invalidate(experiencesProvider(null)),
          ),
          data: (rows) {
            final now = DateTime.now();
            final upcoming =
                rows
                    .where(
                      (event) =>
                          event.restaurantId == venueId &&
                          event.status.isUpcoming &&
                          event.startAt.isAfter(now),
                    )
                    .toList()
                  ..sort((a, b) => a.startAt.compareTo(b.startAt));
            if (upcoming.isEmpty) {
              return const SectionEmpty(
                icon: Icons.auto_awesome_outlined,
                title: 'No upcoming experience',
                message: 'Approve a host request or create your own dinner to '
                    'fill this slot.',
              );
            }
            final visible = upcoming.take(2).toList();
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 56, color: AppColors.border),
                    _ExperienceRow(experience: visible[i]),
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

class _ExperienceRow extends StatelessWidget {
  const _ExperienceRow({required this.experience});

  final PartnerExperience experience;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).pushReplacementNamed('${AppRoute.experiences}?tab=experiences'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    experience.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DisplayDate.dateTime(experience.startAt)} · '
                    '${experience.seatsBooked}/${experience.seatsTotal} seats',
                    style: AppTextStyles.bodySmall,
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

/// ─── Recent activity ───────────────────────────────────────────────────────

/// The three most recent notifications, newest first.
///
/// This is the "what just happened" feed: it is informational, so it sits below
/// the actionable sections, and an unread row carries a dot rather than a
/// second count that would compete with the header badge.
class RecentActivitySection extends ConsumerWidget {
  const RecentActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(notificationsProvider(false));
    void openInbox() => Navigator.of(
      context,
    ).pushReplacementNamed('${AppRoute.inbox}?tab=notifications');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: 'RECENT ACTIVITY',
          trailing: SectionLink(label: 'View all', onPressed: openInbox),
        ),
        const SizedBox(height: AppSpacing.sm),
        page.when(
          skipLoadingOnRefresh: true,
          loading: () => const SectionSkeleton(rows: 2),
          error: (error, _) => SectionError(
            message: 'Unable to load activity',
            onRetry: () => ref.invalidate(notificationsProvider(false)),
          ),
          data: (data) {
            final items = data.items.take(3).toList();
            if (items.isEmpty) {
              return SectionEmpty(
                icon: Icons.notifications_none,
                title: 'No recent activity',
                message: 'Bookings, deals and guest actions show up here as '
                    'they happen.',
                actionLabel: 'Open inbox',
                onAction: openInbox,
              );
            }
            return Container(
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
                    _ActivityRow(item: items[i], onTap: openInbox),
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

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item, required this.onTap});

  final PartnerNotification item;
  final VoidCallback onTap;

  static IconData _iconFor(String category) => switch (category) {
    'reservation' || 'booking' => Icons.event_available,
    'event_request' || 'request' => Icons.pending_actions,
    'deal' => Icons.local_offer,
    'payout' || 'earnings' => Icons.account_balance_wallet_outlined,
    'review' => Icons.star_outline,
    _ => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    final tint = item.read ? AppColors.textSecondary : AppColors.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(_iconFor(item.category), size: 18, color: tint),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!item.read) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: item.read
                                ? FontWeight.w500
                                : FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DisplayDate.relative(item.notificationTime),
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

/// ─── Section states ────────────────────────────────────────────────────────

/// Inline empty state: one line of truth plus the action that changes it.
class SectionEmpty extends StatelessWidget {
  const SectionEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, size: 18, color: AppColors.textTertiary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTextStyles.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!, style: AppTextStyles.labelSmall),
            ),
          ],
        ],
      ),
    );
  }
}

/// A failed section read. Home keeps working around it: this banner replaces
/// only its own block and carries its own retry.
class SectionError extends StatelessWidget {
  const SectionError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StatusBanner(
      message: message,
      tone: BannerTone.danger,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

/// Placeholder rows shaped like the content they replace.
class SectionSkeleton extends StatelessWidget {
  const SectionSkeleton({super.key, this.rows = 1, this.height = 56});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ],
      ],
    );
  }
}
