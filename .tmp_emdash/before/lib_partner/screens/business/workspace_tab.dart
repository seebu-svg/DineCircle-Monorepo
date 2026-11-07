
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/venue.dart';
import '../../navigation/app_routes.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../repositories/venue_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/business_hours.dart';

/// Business workspace with responsive management shortcuts.
/// Existing provider, venue status, and navigation contracts are retained.
class WorkspaceTab extends ConsumerWidget {
  const WorkspaceTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueId = ref.watch(selectedVenueProvider)?.id ?? '';
    final venueAsync = ref.watch(venueDetailProvider(venueId));

    return venueAsync.when(
      loading: () => const _WorkspaceSkeleton(),
      error: (_, _) => _WorkspaceError(
        onRetry: () => ref.invalidate(venueDetailProvider(venueId)),
      ),
      data: (venueDetail) =>
          _WorkspaceContent(venueDetail: venueDetail),
    );
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({required this.venueDetail});

  final VenueDetail venueDetail;

  @override
  Widget build(BuildContext context) {
    final venue = venueDetail.venue;
    final status = BusinessHoursStatus.evaluate(
      hours: venue.openingHours,
      serviceDay: DateTime.now(),
      clock: DateTime.now(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 360 ? 14.0 : 20.0;
        final maxWidth = constraints.maxWidth >= 700
            ? 680.0
            : double.infinity;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            padding,
            16,
            padding,
            36,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Workspace',
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Manage your restaurant in one place.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _BusinessIdentityCard(
                      venue: venue,
                      status: status,
                    ),
                    const SizedBox(height: 24),
                    const _SectionHeader(title: 'Quick access'),
                    const SizedBox(height: 12),
                    const _QuickAccessRow(),
                    const SizedBox(height: 26),
                    for (final group
                        in _buildWorkspaceSections(context)) ...[
                      _SectionHeader(title: group.title),
                      const SizedBox(height: 12),
                      _ModuleGroup(items: group.items),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BusinessIdentityCard extends StatelessWidget {
  const _BusinessIdentityCard({
    required this.venue,
    required this.status,
  });

  final Venue venue;
  final BusinessHoursStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      venue.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${venue.myRole.label} · ${venue.city}',
                      maxLines: 2,
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: venue.verified
                    ? Icons.verified_rounded
                    : Icons.info_outline_rounded,
                label: venue.verified
                    ? 'Verified'
                    : 'Not verified',
                color: venue.verified
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              _StatusPill(
                icon: status.isOpen
                    ? Icons.circle
                    : Icons.circle_outlined,
                label: status.isOpen ? 'Open now' : 'Closed',
                color: status.isOpen
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
            ],
          ),
          if (status.detail.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              status.detail,
              softWrap: true,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow();

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickAccessItem(
        icon: Icons.storefront_outlined,
        label: 'Profile',
        onTap: () =>
            Navigator.of(context).pushNamed('/business?tab=profile'),
      ),
      _QuickAccessItem(
        icon: Icons.location_city_outlined,
        label: 'Branches',
        onTap: () =>
            Navigator.of(context).pushNamed('/business?tab=branches'),
      ),
      _QuickAccessItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        onTap: () =>
            Navigator.of(context).pushNamed(AppRoute.settings),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth < 290 ? 2 : 3;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _QuickAccessTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAccessItem {
  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({required this.item});

  final _QuickAccessItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: AppColors.primary,
                size: 25,
              ),
              const SizedBox(height: 9),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: AppTextStyles.labelSmall.copyWith(
        color: AppColors.textTertiary,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup({required this.items});

  final List<_ModuleItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 66,
                color: AppColors.border,
              ),
            _ModuleTile(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.item});

  final _ModuleItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  softWrap: true,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceSkeleton extends StatelessWidget {
  const _WorkspaceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 155,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 94,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 26),
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: 170,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _WorkspaceError extends StatelessWidget {
  const _WorkspaceError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 44,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unable to load workspace',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceSection {
  const _WorkspaceSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_ModuleItem> items;
}

class _ModuleItem {
  const _ModuleItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

List<_WorkspaceSection> _buildWorkspaceSections(
  BuildContext context,
) {
  void go(String route) {
    Navigator.of(context).pushNamed(route);
  }

  return [
    _WorkspaceSection(
      title: 'Business Management',
      items: [
        _ModuleItem(
          icon: Icons.store_outlined,
          label: 'Venue Profile',
          onTap: () => go('/business?tab=profile'),
        ),
        _ModuleItem(
          icon: Icons.location_city_outlined,
          label: 'Branches',
          onTap: () => go('/business?tab=branches'),
        ),
        _ModuleItem(
          icon: Icons.qr_code_2,
          label: 'QR Codes',
          onTap: () => go('/business?tab=qr'),
        ),
        _ModuleItem(
          icon: Icons.payments_outlined,
          label: 'Packages & Billing',
          onTap: () => go('/business?tab=packages'),
        ),
      ],
    ),
    _WorkspaceSection(
      title: 'Operations',
      items: [
        _ModuleItem(
          icon: Icons.event_available_outlined,
          label: 'Reservations',
          onTap: () => go('/service?tab=reservations'),
        ),
        _ModuleItem(
          icon: Icons.confirmation_number_outlined,
          label: 'Bookings & Check-in',
          onTap: () => go('/service?tab=bookings'),
        ),
        _ModuleItem(
          icon: Icons.table_restaurant_outlined,
          label: 'Tables & Hours',
          onTap: () => go('/service?tab=tables'),
        ),
      ],
    ),
    _WorkspaceSection(
      title: 'Experiences',
      items: [
        _ModuleItem(
          icon: Icons.pending_actions_outlined,
          label: 'Experience Requests',
          onTap: () => go('/experiences?tab=requests'),
        ),
        _ModuleItem(
          icon: Icons.auto_awesome_outlined,
          label: 'Experiences & Hosts',
          onTap: () => go('/experiences?tab=experiences'),
        ),
      ],
    ),
    _WorkspaceSection(
      title: 'Account & Support',
      items: [
        _ModuleItem(
          icon: Icons.star_outline_rounded,
          label: 'Reviews',
          onTap: () => go('/inbox?tab=reviews'),
        ),
        _ModuleItem(
          icon: Icons.notifications_none_rounded,
          label: 'Notifications',
          onTap: () => go('/inbox?tab=notifications'),
        ),
        _ModuleItem(
          icon: Icons.support_agent_outlined,
          label: 'Help & Support',
          onTap: () => go('/inbox?tab=support'),
        ),
        _ModuleItem(
          icon: Icons.settings_outlined,
          label: 'Account Settings',
          onTap: () => go(AppRoute.settings),
        ),
      ],
    ),
  ];
}
