import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subscription.dart';
import '../../models/venue.dart';
import '../../navigation/app_routes.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/business_hours.dart';
import '../../widgets/async_views.dart';
import '../../widgets/media_image.dart';

/// The Business workspace: one compact hub per venue.
///
/// The [AppShell] header already owns the brand mark, the venue switcher, the
/// notification bell and the account menu, and it renders the "Business" title,
/// so this surface starts straight at the restaurant identity card. Repeating
/// the branding or the venue name here would print the same information twice
/// on one screen.
///
/// Every row points at a screen that already exists. Nothing on this page
/// invents a destination, and no entry appears in both the shortcut strip and
/// one of the lists below.
class WorkspaceTab extends ConsumerWidget {
  const WorkspaceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueId = ref.watch(selectedVenueIdProvider);

    if (venueId.isEmpty) {
      return const EmptyState(
        title: 'No venue selected',
        message: 'Choose a venue to open its business workspace.',
        icon: Icons.storefront_outlined,
      );
    }

    final detail = ref.watch(venueDetailProvider(venueId));
    // Watched separately so a slow or failing subscription call never blocks
    // the management lists the operator actually came here for.
    final subscription = ref.watch(subscriptionProvider(venueId));

    return detail.when(
      loading: () => const LoadingSkeleton(count: 4, showHeader: true),
      error: (error, _) => ErrorView(
        error: error,
        onRetry: () => ref.invalidate(venueDetailProvider(venueId)),
      ),
      data: (data) => _WorkspaceBody(
        venue: data.venue,
        subscription: subscription,
      ),
    );
  }
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({required this.venue, required this.subscription});

  final Venue venue;
  final AsyncValue<VenueSubscription> subscription;

  @override
  Widget build(BuildContext context) {
    final status = BusinessHoursStatus.evaluate(
      hours: venue.openingHours,
      serviceDay: DateTime.now(),
      clock: DateTime.now(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide windows keep a readable measure instead of stretching the rows
        // across a desktop monitor; phones use the full width.
        final maxWidth = constraints.maxWidth >= 900 ? 760.0 : double.infinity;

        return SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _IdentityCard(venue: venue, status: status),
                      const _SectionLabel('Quick access'),
                      const _QuickAccessRow(),
                      const _SectionLabel('Restaurant management'),
                      const _CompactGroup(rows: _managementRows),
                      const _SectionLabel('Business operations'),
                      const _CompactGroup(rows: _operationRows),
                      const _SectionLabel('Subscription'),
                      _SubscriptionCard(subscription: subscription),
                      const _SectionLabel('Account and support'),
                      const _CompactGroup(rows: _accountRows),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Restaurant identity ────────────────────────────────────────────────────

/// Compact identity card: logo, name, role, verification and trading status.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.venue, required this.status});

  final Venue venue;
  final BusinessHoursStatus status;

  /// Prefers the square brand mark and falls back to the cover photo, so a
  /// venue that has only uploaded one image still gets a real thumbnail.
  String get _imageSource =>
      venue.logo.isNotEmpty ? venue.logo : venue.coverImage;

  String get _roleAndCity {
    final role = venue.myRole.label;
    if (venue.city.isEmpty) return role;
    return '$role, ${venue.city}';
  }

  @override
  Widget build(BuildContext context) {
    // Trading status: green only for a venue that is actually open. A venue
    // with no configured hours says so instead of pretending to be closed.
    final (IconData statusIcon, String statusLabel, Color statusColor) =
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: _imageSource.isEmpty
                      ? _LogoFallback()
                      : MediaImage(
                          source: _imageSource,
                          fallbackIcon: Icons.storefront_rounded,
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _roleAndCity,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InfoPill(
                icon: venue.verified
                    ? Icons.verified_rounded
                    : Icons.gpp_maybe_outlined,
                label: venue.verified ? 'Verified' : 'Not verified',
                color: venue.verified
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              _InfoPill(
                icon: statusIcon,
                label: statusLabel,
                color: statusColor,
              ),
              // "Open until 22:00" / "Opens at 18:00": the next trading window
              // when the venue is shut, so the desk does not have to open the
              // hours editor to answer that question.
              if (status.detail.isNotEmpty)
                Text(
                  status.detail,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
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
          // Flexible so a long label at 2.0 text scale wraps inside the pill
          // instead of pushing the Row past the screen edge.
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick access ───────────────────────────────────────────────────────────

/// The three destinations an operator opens most often.
class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow();

  @override
  Widget build(BuildContext context) {
    final items = [
      const _Shortcut(
        icon: Icons.storefront_outlined,
        label: 'Restaurant Profile',
        route: '${AppRoute.business}?tab=profile',
      ),
      const _Shortcut(
        icon: Icons.qr_code_2,
        label: 'QR Codes',
        route: '${AppRoute.business}?tab=qr',
      ),
      const _Shortcut(
        icon: Icons.card_membership_outlined,
        label: 'Subscription',
        route: '${AppRoute.business}?tab=subscription',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        // Two columns only below 300dp, where three tiles would squeeze the
        // labels into ellipses on a small phone at large text scale.
        final columns = constraints.maxWidth < 300 ? 2 : 3;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _ShortcutTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _Shortcut {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.item});

  final _Shortcut item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => Navigator.of(context).pushNamed(item.route),
        child: Container(
          // A minimum, not a fixed height: the tile grows at 2.0 text scale
          // instead of clipping its label.
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTapTarget + 20,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: AppColors.primary, size: 22),
              const SizedBox(height: 6),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Settings-style lists ───────────────────────────────────────────────────

/// One navigable row inside a [_CompactGroup].
class _Row {
  const _Row({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

/// Restaurant Profile is deliberately absent: it is the first quick-access
/// shortcut, and listing it twice on one screen is the duplication the redesign
/// is meant to remove.
///
/// Booking Policies and Amenities both live inside the venue profile, so each
/// row deep-links to that section rather than opening the same top of page.
const List<_Row> _managementRows = [
  _Row(
    icon: Icons.restaurant_menu_outlined,
    label: 'Menu Configuration',
    route: '${AppRoute.business}?tab=menu',
  ),
  _Row(
    icon: Icons.policy_outlined,
    label: 'Booking Policies',
    route: '${AppRoute.business}?tab=profile&section=policies',
  ),
  _Row(
    icon: Icons.schedule_outlined,
    label: 'Operating Hours',
    route: '${AppRoute.service}?tab=tables',
  ),
  _Row(
    icon: Icons.widgets_outlined,
    label: 'Amenities and Facilities',
    route: '${AppRoute.business}?tab=profile&section=amenities',
  ),
];

/// QR management is intentionally not repeated here; it is a quick-access
/// shortcut above.
const List<_Row> _operationRows = [
  _Row(
    icon: Icons.event_available_outlined,
    label: 'Reservations Management',
    route: '${AppRoute.service}?tab=reservations',
  ),
  _Row(
    icon: Icons.auto_awesome_outlined,
    label: 'Dining Experiences',
    route: '${AppRoute.experiences}?tab=experiences',
  ),
  _Row(
    icon: Icons.how_to_reg_outlined,
    label: 'Check-in',
    route: '${AppRoute.service}?tab=checkin',
  ),
];

/// Settings and support sit below the subscription block, per the workspace
/// hierarchy.
const List<_Row> _accountRows = [
  _Row(
    icon: Icons.settings_outlined,
    label: 'Account settings',
    route: AppRoute.settings,
  ),
  _Row(
    icon: Icons.support_agent_outlined,
    label: 'Help and Support',
    route: '${AppRoute.inbox}?tab=support',
  ),
];

/// A joined list of rows drawn as one dark surface with hairline dividers.
class _CompactGroup extends StatelessWidget {
  const _CompactGroup({required this.rows});

  final List<_Row> rows;

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
            _RowTile(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(row.route),
        child: Container(
          // 52dp keeps every row above the 48dp accessible minimum while
          // staying compact, and the row still grows with text scaling.
          constraints: const BoxConstraints(minHeight: 52),
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
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Subscription ───────────────────────────────────────────────────────────

/// Partner Pro summary: status, plan, renewal date and the one action that
/// matters. Values come from the server subscription row; nothing is assumed
/// when that row cannot be read.
class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final AsyncValue<VenueSubscription> subscription;

  @override
  Widget build(BuildContext context) {
    final sub = subscription.valueOrNull;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md - 2),
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
                child: Text(
                  'Partner Pro',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _SubscriptionPill(subscription: subscription),
            ],
          ),
          if (sub?.plan != null) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              '${sub!.plan!.label} plan, ${_pkr(sub.pricePkr)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (sub?.plan != null && sub?.periodEnd != null) ...[
            const SizedBox(height: 2),
            Text(
              '${sub!.autoRenew ? 'Renews on' : 'Ends on'} ${_shortDate(sub.periodEnd!)}',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
          if (sub == null && !subscription.isLoading) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Subscription details could not be loaded.',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
          if (sub == null && subscription.isLoading) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            Container(
              height: 12,
              width: 150,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm + 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed(
                '${AppRoute.business}?tab=subscription',
              ),
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Manage Subscription'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status pill for the subscription row. Uses the model's own label so the
/// card, the subscription screen and the docs cannot drift apart.
class _SubscriptionPill extends StatelessWidget {
  const _SubscriptionPill({required this.subscription});

  final AsyncValue<VenueSubscription> subscription;

  Color get _color {
    final sub = subscription.valueOrNull;
    if (sub == null) return AppColors.textTertiary;
    return switch (sub.status) {
      SubscriptionStatus.active => AppColors.success,
      SubscriptionStatus.trialing => AppColors.info,
      SubscriptionStatus.pastDue => AppColors.warning,
      SubscriptionStatus.cancelled => AppColors.danger,
      SubscriptionStatus.none => AppColors.textTertiary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final sub = subscription.valueOrNull;
    if (sub == null) {
      // Unknown is not a status; an empty box holds the space while the row
      // loads or after a failed read.
      return const SizedBox.shrink();
    }

    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        sub.status.label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Shared bits ────────────────────────────────────────────────────────────

/// Uppercase group label above a list. Deliberately lighter than the shared
/// [SectionHeader]: this screen is a settings page, not a marketing surface.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w700,
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
