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

/// ─── Restaurant header ─────────────────────────────────────────────────────

/// The compact identity block at the top of Home.
///
/// Everything it shows is real: the logo comes from the venue record, the
/// open/closed pill is derived from the *configured* weekly hours, and the
/// subscription pill only appears once the server has answered. A venue with no
/// logo gets the storefront fallback rather than a broken image or a stock
/// picture.
///
/// It is deliberately short. It used to be a full-bleed photograph with the
/// venue name set at display size and a four-cell service pulse strip under it,
/// which spent half a phone screen on branding and repeated numbers that the
/// overview below already owns. What is left is the restaurant's name, its
/// state and the date the board is showing.
///
/// The notification bell is not here: the shell header already renders one with
/// the live unread badge. Two bells a thumb-width apart, both opening the same
/// inbox, is one control too many.
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
    // header must never guess a billing state it has not been told.
    final subscription =
        ref.watch(subscriptionProvider(snapshot.venue.id)).valueOrNull;

    final name = (venue?.name ?? '').trim().isEmpty
        ? snapshot.venue.name
        : venue!.name.trim();
    final identity = _identityLine(venue);

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _logoTile(venue),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DisplayDate.dayLong(serviceDay),
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      name,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (identity.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        identity,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: pills,
            ),
          ],
        ],
      ),
    );
  }

  /// The venue logo, or its cover, or the storefront fallback.
  Widget _logoTile(Venue? venue) {
    final logo = (venue?.logo ?? '').trim();
    final cover = (venue?.coverImage ?? '').trim();
    return Container(
      width: 42,
      height: 42,
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

  /// "Pakistani · BBQ · Karachi", whichever of those the venue actually has.
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

/// ─── Pills ─────────────────────────────────────────────────────────────────

/// One state pill in the header: verification, trading hours, subscription.
///
/// Tappable pills get [onTap]; decorative ones stay inert so a status can never
/// look like a button it is not. The pill carries no outline: a tinted fill is
/// enough definition on a dark surface, and three bordered capsules in a row
/// read as a toolbar rather than as state.
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
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
                letterSpacing: 0.1,
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
