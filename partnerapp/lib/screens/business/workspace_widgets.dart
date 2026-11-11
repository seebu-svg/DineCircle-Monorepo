import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subscription.dart';
import '../../models/venue.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/business_hours.dart';
import '../../widgets/media_image.dart';

/// ─── Header ────────────────────────────────────────────────────────────────

/// The page's purpose line.
///
/// [AppShell] already renders the "Business" title, the brand mark, the venue
/// switcher and the account menu, so this block does not repeat any of them.
/// It says what the surface is for, in the same compact card shape Deals and
/// Insights use at the top of their pages.
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
            ),
            child: const Icon(
              Icons.dashboard_customize_outlined,
              size: 19,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Restaurant hub',
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
                  'Manage your restaurant, settings and account.',
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
    );
  }
}

/// ─── Identity ──────────────────────────────────────────────────────────────

/// Who these controls belong to: photo, name, location, verification and
/// whether the kitchen is trading. The whole card is the profile door, so the
/// most important shortcut on the page is also the largest target.
class WorkspaceIdentityCard extends StatelessWidget {
  const WorkspaceIdentityCard({
    super.key,
    required this.venue,
    required this.status,
    required this.onOpenProfile,
  });

  final Venue venue;
  final BusinessHoursStatus status;
  final VoidCallback onOpenProfile;

  /// Prefers the square brand mark and falls back to the cover photo, so a
  /// venue that has uploaded only one image still gets a real thumbnail.
  String get _image => venue.logo.trim().isNotEmpty
      ? venue.logo
      : venue.coverImage;

  String get _location {
    final parts = [venue.neighborhood, venue.city]
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? 'Location not set' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final (IconData tradeIcon, String tradeLabel, Color tradeColor) =
        switch (status.status) {
          VenueOpenStatus.open => (
              Icons.circle,
              'Open now',
              AppColors.success,
            ),
          VenueOpenStatus.closed => (
              Icons.circle_outlined,
              'Closed',
              AppColors.textSecondary,
            ),
          VenueOpenStatus.notConfigured => (
              Icons.circle_outlined,
              'Hours not set',
              AppColors.textTertiary,
            ),
        };

    return Semantics(
      button: true,
      label: 'Open restaurant profile',
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onOpenProfile,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        child: SizedBox(
                          width: 52,
                          height: 52,
                          child: _image.trim().isEmpty
                              ? const _LogoFallback()
                              : MediaImage(
                                  source: _image,
                                  fallbackIcon: Icons.storefront_rounded,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            venue.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 12,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  _location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _InfoPill(
                      icon: venue.verified
                          ? Icons.verified_rounded
                          : Icons.gpp_maybe_outlined,
                      label: venue.verified ? 'Verified' : 'Not verified',
                      color: venue.verified
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    _InfoPill(
                      icon: tradeIcon,
                      label: tradeLabel,
                      color: tradeColor,
                    ),
                    if (status.detail.isNotEmpty && status.isConfigured)
                      Text(
                        status.detail,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
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

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: const Icon(
        Icons.storefront_rounded,
        size: 24,
        color: AppColors.primary,
      ),
    );
  }
}

/// A small bordered pill: one fact, one colour.
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Shortcuts ─────────────────────────────────────────────────────────────

class WorkspaceShortcut {
  const WorkspaceShortcut({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

/// Three doors an operator opens most often, in one row.
class WorkspaceShortcutGrid extends StatelessWidget {
  const WorkspaceShortcutGrid({
    super.key,
    required this.items,
    required this.onOpen,
  });

  final List<WorkspaceShortcut> items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        // Two columns only where three would turn every label into an ellipsis:
        // a very narrow phone, or any phone at a large text scale.
        final columns = constraints.maxWidth < 300 || scale >= 1.6 ? 2 : 3;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _ShortcutTile(item: item, onOpen: onOpen),
              ),
          ],
        );
      },
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.item, required this.onOpen});

  final WorkspaceShortcut item;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => onOpen(item.route),
        child: Container(
          // A minimum, not a fixed height: the tile grows at 2.0 text scale
          // instead of clipping its label.
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: AppColors.primary, size: 20),
              const SizedBox(height: 6),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 10.5,
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─── Section shell ─────────────────────────────────────────────────────────

/// A human-readable group title. Deliberately sentence case at 15dp: the old
/// uppercase 11dp labels read as machine keys rather than headings, and the
/// page has enough chrome around it already.
class WorkspaceSectionHeader extends StatelessWidget {
  const WorkspaceSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTextStyles.titleMedium.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// ─── Row group ─────────────────────────────────────────────────────────────

/// One navigable destination. [trailing] is a short live fact ("Open until
/// 22:00"); nothing else belongs in the row, so every row reads the same.
class WorkspaceDestination {
  const WorkspaceDestination({
    required this.icon,
    required this.label,
    required this.route,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String route;
  final String? trailing;
}

/// A joined list of rows on one surface, separated by hairlines.
class WorkspaceGroup extends StatelessWidget {
  const WorkspaceGroup({super.key, required this.rows, required this.onOpen});

  final List<WorkspaceDestination> rows;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 52,
                color: AppColors.border,
              ),
            _RowTile(row: rows[i], onOpen: onOpen),
          ],
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.onOpen});

  final WorkspaceDestination row;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final trailing = row.trailing;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onOpen(row.route),
        child: Container(
          // 50dp keeps every row above the 48dp accessible minimum while
          // staying compact, and the row still grows with text scaling.
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md - 2,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(row.icon, size: 19, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md - 4),
              Expanded(
                child: Text(
                  row.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null && trailing.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  trailing,
                  maxLines: 1,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─── Subscription ──────────────────────────────────────────────────────────

/// Partner Pro at a glance: status, plan, price and the date that matters.
///
/// The card is the door to the subscription screen, so it replaces both the old
/// large "Manage Subscription" button and the separate shortcut that pointed at
/// the same page. Values come from the server row; nothing is assumed while the
/// read is in flight or after it fails.
class WorkspaceSubscriptionCard extends StatelessWidget {
  const WorkspaceSubscriptionCard({
    super.key,
    required this.subscription,
    required this.onOpen,
    required this.onRetry,
  });

  final AsyncValue<VenueSubscription> subscription;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  String get _planLine {
    final sub = subscription.valueOrNull;
    if (sub == null) {
      if (subscription.isLoading) return 'Reading subscription…';
      if (subscription.hasError) return 'Details unavailable';
      return 'No plan active';
    }
    final plan = sub.plan;
    if (plan == null) return 'No plan active';
    return '${plan.label} plan, ${_pkr(sub.pricePkr)}';
  }

  String? get _renewalLine {
    final sub = subscription.valueOrNull;
    final end = sub?.periodEnd;
    if (sub == null || end == null) return null;
    return '${sub.autoRenew ? 'Renews on' : 'Ends on'} ${_shortDate(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final sub = subscription.valueOrNull;

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm + 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 18,
                      color: AppColors.gold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Partner Pro',
                          style: AppTextStyles.titleSmall.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _planLine,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _SubscriptionPill(subscription: sub),
                  ],
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
              if (_renewalLine != null) ...[
                const SizedBox(height: 6),
                Text(
                  _renewalLine!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
              if (subscription.hasError) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Subscription details could not be loaded.',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      child: Text(
                        'Retry',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Status pill using the model's own label, so the hub, the subscription screen
/// and the docs cannot drift apart.
class _SubscriptionPill extends StatelessWidget {
  const _SubscriptionPill({required this.subscription});

  final VenueSubscription subscription;

  Color get _color => switch (subscription.status) {
    SubscriptionStatus.active => AppColors.success,
    SubscriptionStatus.trialing => AppColors.info,
    SubscriptionStatus.pastDue => AppColors.warning,
    SubscriptionStatus.cancelled => AppColors.danger,
    SubscriptionStatus.none => AppColors.textTertiary,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        subscription.status.label,
        maxLines: 1,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// `5000` -> `PKR 5,000`, matching the subscription screen's own formatting.
String _pkr(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return 'PKR $buffer';
}

/// ISO-ish `yyyy-MM-dd` in the device's timezone, the format the subscription
/// screen already uses.
String _shortDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
