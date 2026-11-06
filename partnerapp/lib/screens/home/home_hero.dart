import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/operations.dart';
import '../../models/subscription.dart';
import '../../models/venue.dart';
import '../../navigation/app_routes.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/business_hours.dart';
import '../../utils/date_time.dart';
import '../../widgets/media_image.dart';

/// ─── Venue hero ────────────────────────────────────────────────────────────

/// The branded identity block at the top of Home.
///
/// Everything it shows is real: the cover and logo come from the venue record,
/// the open/closed pill is derived from the *configured* weekly hours, and the
/// subscription pill only appears once the server has answered. A venue with no
/// photo gets the brand gradient rather than a broken image or a stock picture.
class HomeHero extends ConsumerWidget {
  const HomeHero({super.key, required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(selectedVenueProvider);
    final serviceDay = ServiceDate.parse(snapshot.today.date);
    final hours = venue == null
        ? null
        : BusinessHoursStatus.evaluate(
            hours: venue.openingHours,
            serviceDay: serviceDay,
            clock: DateTime.now(),
          );
    // A failed or pending subscription read simply means "no pill yet": the
    // hero must never guess a billing state it has not been told.
    final subscription =
        ref.watch(subscriptionProvider(snapshot.venue.id)).valueOrNull;

    final name = (venue?.name ?? '').trim().isEmpty
        ? snapshot.venue.name
        : venue!.name.trim();
    final identity = _identityLine(venue);
    final greeting =
        '${greetingFor(DateTime.now())} · ${DisplayDate.dayLong(serviceDay)}';

    final pills = <Widget>[
      HeroPill(
        icon: snapshot.venue.verified ? Icons.verified : Icons.verified_outlined,
        label: snapshot.venue.verified
            ? 'Verified'
            : _partnershipLabel(snapshot.venue.partnershipStatus),
        color: snapshot.venue.verified
            ? AppColors.success
            : AppColors.forStatus(snapshot.venue.partnershipStatus),
      ),
      if (hours != null) _hoursPill(hours),
      if (subscription != null) _subscriptionPill(context, subscription),
    ];

    final panel = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: _cover(venue)),
          // Warm brand tint, then the scrim that keeps the copy readable on a
          // busy photograph. Both are decoration only.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.26),
                    AppColors.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bg.withValues(alpha: 0.12),
                    AppColors.bg.withValues(alpha: 0.66),
                    AppColors.bg.withValues(alpha: 0.95),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _logoTile(venue),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            style: AppTextStyles.displaySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              height: 1.15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (identity.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              identity,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (pills.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: pills,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                ServicePulseStrip(today: snapshot.today),
              ],
            ),
          ),
        ],
      ),
    );

    // Subtle settle-in when the dashboard mounts; skipped when the device asks
    // for reduced motion.
    if (MediaQuery.disableAnimationsOf(context)) return panel;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.985, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: panel,
    );
  }

  Widget _cover(Venue? venue) {
    final cover = (venue?.coverImage ?? '').trim();
    if (cover.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surfaceHigh, AppColors.surface],
          ),
        ),
      );
    }
    return MediaImage(source: cover, fallbackIcon: Icons.storefront);
  }

  Widget _logoTile(Venue? venue) {
    final logo = (venue?.logo ?? '').trim();
    final cover = (venue?.coverImage ?? '').trim();
    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: MediaImage(
        source: logo.isNotEmpty ? logo : cover,
        fallbackIcon: Icons.storefront,
      ),
    );
  }

  /// "Pakistani · BBQ · Karachi" — whichever of those the venue actually has.
  String _identityLine(Venue? venue) {
    if (venue == null) return '';
    final parts = <String>[
      ...venue.cuisines.take(2),
      if (venue.city.trim().isNotEmpty) venue.city.trim(),
    ];
    return parts.join(' · ');
  }

  HeroPill _hoursPill(BusinessHoursStatus hours) {
    final color = switch (hours.status) {
      VenueOpenStatus.open => AppColors.success,
      VenueOpenStatus.closed => AppColors.warning,
      VenueOpenStatus.notConfigured => AppColors.textTertiary,
    };
    return HeroPill(icon: Icons.schedule, label: hours.detail, color: color);
  }

  HeroPill _subscriptionPill(
    BuildContext context,
    VenueSubscription subscription,
  ) {
    final plan = subscription.plan?.label;
    final (label, color) = switch (subscription.status) {
      SubscriptionStatus.active => (
        plan == null ? 'Partner Pro' : 'Pro · $plan',
        AppColors.gold,
      ),
      SubscriptionStatus.trialing => ('Pro trial', AppColors.warning),
      SubscriptionStatus.pastDue => ('Pro · payment due', AppColors.danger),
      SubscriptionStatus.cancelled => ('Pro cancelled', AppColors.textTertiary),
      SubscriptionStatus.none => ('No active plan', AppColors.textTertiary),
    };
    return HeroPill(
      icon: Icons.workspace_premium,
      label: label,
      color: color,
      onTap: () => Navigator.of(
        context,
      ).pushReplacementNamed('${AppRoute.business}?tab=subscription'),
    );
  }

  static String _partnershipLabel(String status) => switch (status) {
    'verified' => 'Verified',
    'pending_review' => 'Pending review',
    'rejected' => 'Rejected',
    _ => 'Unverified',
  };
}

/// ─── Service pulse ─────────────────────────────────────────────────────────

/// Today at a glance inside the hero: covers seated, tables in service and —
/// only when a capacity is actually configured — occupancy.
///
/// A venue with no seats set up would otherwise be shown a 0% occupancy that
/// reads like a dead night, so the cell is omitted instead of faked.
class ServicePulseStrip extends StatelessWidget {
  const ServicePulseStrip({super.key, required this.today});

  final TodayService today;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      _PulseCell(
        label: 'Covers today',
        value: '${today.covers}',
        caption: today.hasCapacityConfigured
            ? 'of ${today.capacity} seats'
            : 'capacity not set',
      ),
      _PulseCell(
        label: 'Tables',
        value: '${today.tables}',
        caption: today.tables == 0 ? 'none set up' : 'in service',
      ),
      if (today.hasCapacityConfigured)
        _PulseCell(
          label: 'Occupancy',
          value: '${(today.occupancy.clamp(0.0, 1.0) * 100).round()}%',
          caption: 'of the room',
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (scale >= 1.6 || constraints.maxWidth < 300) {
          final width = (constraints.maxWidth - AppSpacing.md) / 2;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              for (final cell in cells) SizedBox(width: width, child: cell),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) ...[
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(child: cells[i]),
            ],
          ],
        );
      },
    );
  }
}

class _PulseCell extends StatelessWidget {
  const _PulseCell({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textTertiary,
            fontSize: 9,
            letterSpacing: 0.8,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTextStyles.numericMedium.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        Text(
          caption,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// ─── Pills ─────────────────────────────────────────────────────────────────

/// One state pill inside the hero: verification, trading hours, subscription.
///
/// Tappable pills get [onTap]; decorative ones stay inert so a status can never
/// look like a button it is not.
class HeroPill extends StatelessWidget {
  const HeroPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            // Loose so the pill keeps its natural width inside a Wrap and
            // still ellipsises instead of overflowing at a large text scale.
            fit: FlexFit.loose,
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: content,
        ),
      ),
    );
  }
}
