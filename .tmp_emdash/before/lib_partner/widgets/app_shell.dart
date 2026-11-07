import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/app_routes.dart';
import '../providers/app_providers.dart';
import '../providers/module_providers.dart';
import '../providers/venue_scope_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'brand.dart';

/// One header action offered by a screen (a "Refresh", a "New deal").
///
/// Actions are declared as data, not widgets, so the shell can render them
/// inline when there is room and fold them into an overflow menu on a tight
/// phone or at large text scale — the action never disappears, only the icon
/// does.
class ShellAction {
  const ShellAction({
    required this.icon,
    required this.label,
    this.onPressed,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Renders a spinner instead of the icon while the action works.
  final bool busy;
}

/// The one chrome every signed-in screen sits inside.
///
/// Same content, three shapes: a bottom bar on a phone, a rail in a small
/// window, and a persistent grouped sidebar on desktop web. Navigation always
/// goes through a named route, so a web URL is shareable and the browser back
/// button works, and the active destination is read back from the route rather
/// than duplicated in local state that could drift.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.active,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  /// Which of the five primary destinations this screen belongs to.
  final PrimaryDestination active;
  final String title;
  final Widget child;

  /// Extra header actions for the current screen (a "New deal" button, …).
  final List<ShellAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = AppLayout.windowSize(context);
    final header = _ShellHeader(title: title, actions: actions);

    if (size == WindowSize.expanded) {
      return Scaffold(
        body: Row(
          children: [
            const _Sidebar(),
            Expanded(
              child: Column(
                children: [
                  header,
                  const _OfflineStrip(),
                  Expanded(child: Center(child: _MaxWidth(child: child))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Compact and medium: the custom header stacks above the body so the venue
    // switcher and badge behave identically to the sidebar layout.
    return Scaffold(
      drawer: size == WindowSize.medium ? _RailDrawer(active: active) : null,
      body: Column(
        children: [
          header,
          const _OfflineStrip(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: size == WindowSize.compact
          ? _BottomBar(active: active)
          : null,
    );
  }
}

/// A custom top bar used instead of a Material [AppBar] so the venue switcher,
/// the live notification badge and the screen actions share one row at every
/// breakpoint, including the desktop sidebar layout which has no Scaffold app
/// bar.
class _ShellHeader extends ConsumerWidget implements PreferredSizeWidget {
  const _ShellHeader({required this.title, this.actions = const []});

  final String title;
  final List<ShellAction> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(venueScopeProvider).valueOrNull?.selected;

    // A phone at 320dp, or any surface at ~2.0 text scale, cannot fit the
    // switcher plus inline actions without ellipsis-mashing everything; the
    // overline already names the venue, so the switcher yields and the
    // actions fold into one overflow button.
    final width = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final tight = width < 360 || textScale >= 1.8;
    final showSwitcher = !tight && selected != null;

    // The switcher names the venue on this same row, so the overline carries
    // only the role rather than printing the venue twice. When the switcher
    // has yielded (a tight phone) this line is the only place the venue is
    // named, so it takes the name back.
    final String? overline;
    if (selected == null) {
      overline = null;
    } else if (showSwitcher) {
      overline = selected.myRole.label;
    } else {
      overline = '${selected.name} · ${selected.myRole.label}';
    }

    // Two lines at 1.5x+ text need more than the one-line 64; the bar grows
    // instead of ellipsis-clipping the title at large scale.
    final headerHeight = textScale >= 1.5 ? 88.0 : 64.0;

    return Material(
      color: AppColors.bg,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              const BrandMark(),
              if (showSwitcher) ...[
                const SizedBox(width: AppSpacing.sm),
                const Flexible(child: _VenueSwitcher()),
              ],
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (overline != null)
                      Text(
                        overline,
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      title,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                if (tight)
                  _OverflowActions(actions: actions)
                else
                  for (final action in actions) _ActionButton(action: action),
              ],
              const _NotificationBell(),
              const _AccountMenu(),
            ],
          ),
        ),
      ),
    );
  }
}

/// One header action rendered as an icon button.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final ShellAction action;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: action.label,
      onPressed: action.onPressed,
      icon: action.busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(action.icon),
    );
  }
}

/// The tight-layout form of the header actions: one menu, same callbacks.
class _OverflowActions extends StatelessWidget {
  const _OverflowActions({required this.actions});

  final List<ShellAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'More actions',
      offset: const Offset(0, 52),
      icon: const Icon(Icons.more_vert),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].onPressed != null,
            child: Row(
              children: [
                Icon(actions[i].icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(actions[i].label, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
      ],
      onSelected: (i) => actions[i].onPressed?.call(),
    );
  }
}

/// Venue picker: the account's operated venues plus its role, switching which
/// rebuilds every venue-scoped provider.
///
/// Only a multi-venue account gets a menu. A single venue renders as a plain
/// label, because a chevron that opens nothing reads as a broken control.
class _VenueSwitcher extends ConsumerWidget {
  const _VenueSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(venueScopeProvider).valueOrNull;
    final selected = scope?.selected;
    final venues = scope?.venues ?? const [];
    if (selected == null) return const SizedBox.shrink();

    final label = _VenueLabel(
      name: selected.name,
      expandable: venues.length > 1,
    );
    if (venues.length < 2) {
      return KeyedSubtree(
        key: const ValueKey('shell-venue-label'),
        child: label,
      );
    }

    return PopupMenuButton<String>(
      key: const ValueKey('shell-venue-switcher'),
      tooltip: 'Switch venue',
      offset: const Offset(0, 52),
      onSelected: (id) =>
          ref.read(venueScopeProvider.notifier).select(id),
      itemBuilder: (context) => [
        for (final venue in venues)
          PopupMenuItem<String>(
            value: venue.id,
            enabled: venue.id != selected.id,
            child: Row(
              children: [
                Icon(
                  venue.id == selected.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: venue.id == selected.id
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(venue.name, style: AppTextStyles.bodyMedium),
                      Text(
                        '${venue.myRole.label} · ${venue.city}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      child: label,
    );
  }
}

/// The name of the venue the desk is currently operating.
class _VenueLabel extends StatelessWidget {
  const _VenueLabel({required this.name, required this.expandable});

  final String name;

  /// Whether tapping this opens a venue menu (draws the chevron).
  final bool expandable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: AppTextStyles.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (expandable) const Icon(Icons.expand_more, size: 18),
        ],
      ),
    );
  }
}

/// Unread count from the polling badge; taps through to the inbox.
///
/// Pushes rather than replaces: the bell is chrome on every screen, so
/// replacing the current page would leave the operator with nothing to go
/// back to. Tapping it while the inbox is already open is a no-op instead of
/// stacking a second inbox.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  static const String _inboxRoute = '${AppRoute.inbox}?tab=notifications';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationBadgeProvider).valueOrNull ?? 0;
    return IconButton(
      key: const ValueKey('shell-notifications'),
      tooltip: 'Notifications',
      onPressed: () {
        final current = ModalRoute.of(context)?.settings.name ?? '';
        if (rootOf(current) == AppRoute.inbox) return;
        Navigator.of(context).pushNamed(_inboxRoute);
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.notifications_none),
      ),
    );
  }
}

/// Sign-out and the secondary destinations a phone has no room to show in the
/// bar. Also the entry to Admin and Settings.
class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isPlatformAdminProvider);
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 52),
      icon: CircleAvatar(
        radius: 15,
        backgroundColor: AppColors.surfaceHigh,
        child: Text(
          user?.initials ?? '?',
          style: AppTextStyles.labelMedium,
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user?.name ?? 'Signed in', style: AppTextStyles.titleSmall),
              Text(user?.email ?? '', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: AppRoute.settings,
          child: Text('Settings & security'),
        ),
        if (isAdmin)
          const PopupMenuItem(
            value: AppRoute.verification,
            child: Text('Verification queue'),
          ),
        const PopupMenuItem(value: 'signout', child: Text('Sign out')),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'signout':
            await ref.read(sessionProvider.notifier).signOut();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoute.login,
                (route) => false,
              );
            }
          default:
            Navigator.of(context).pushNamed(value);
        }
      },
    );
  }
}

class _OfflineStrip extends ConsumerWidget {
  const _OfflineStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);
    if (!offline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Offline. Showing the last data read',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.active});

  final PrimaryDestination active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = PrimaryDestination.indexOf(
      ModalRoute.of(context)?.settings.name,
    );
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) {
        final dest = PrimaryDestination.values[i];
        // Menu/Deals/Insights share the /business root and differ only by
        // ?tab=, so the *full* route decides whether a tap is a real move.
        final current = ModalRoute.of(context)?.settings.name ?? '';
        if (dest.route != current) {
          Navigator.of(context).pushReplacementNamed(dest.route);
        }
      },
      destinations: [
        for (final dest in PrimaryDestination.values)
          NavigationDestination(
            icon: Icon(dest.icon),
            selectedIcon: Icon(dest.selectedIcon),
            label: dest.label,
          ),
      ],
    );
  }
}

/// Medium windows get the rail as a permanent drawer.
class _RailDrawer extends StatelessWidget {
  const _RailDrawer({required this.active});

  final PrimaryDestination active;

  @override
  Widget build(BuildContext context) {
    final index = PrimaryDestination.indexOf(
      ModalRoute.of(context)?.settings.name,
    );
    return Drawer(
      width: 96,
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          children: [
            for (var i = 0; i < PrimaryDestination.values.length; i++)
              _RailItem(
                dest: PrimaryDestination.values[i],
                selected: i == index,
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.dest, required this.selected});

  final PrimaryDestination dest;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushReplacementNamed(dest.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? dest.selectedIcon : dest.icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              dest.label,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The persistent desktop sidebar: primary row plus every grouped destination.
class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ModalRoute.of(context)?.settings.name ?? '';
    final root = rootOf(current);
    return Container(
      width: AppSpacing.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: const BrandLockup(
                badgeHeight: 40,
                wordmarkHeight: 22,
                showEyebrow: true,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  for (final group in sidebarGroups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.xs,
                      ),
                      child: Text(
                        group.first.group.toUpperCase(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    for (final item in group)
                      _SidebarItem(
                        item: item,
                        selected: _matches(root, current, item),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _matches(String root, String current, SecondaryDestination item) {
    if (item.tab == null) return root == item.route && root != AppRoute.today;
    // A tabbed destination is selected only when the query matches.
    return current == item.fullRoute ||
        (root == item.route && queryOf(current)['tab'] == item.tab);
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.selected});

  final SecondaryDestination item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: () => Navigator.of(context).pushReplacementNamed(item.fullRoute),
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 1,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                item.label,
                style: AppTextStyles.bodyMedium.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps expanded-layout content to a readable measure.
class _MaxWidth extends StatelessWidget {
  const _MaxWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: child,
      ),
    );
  }
}
