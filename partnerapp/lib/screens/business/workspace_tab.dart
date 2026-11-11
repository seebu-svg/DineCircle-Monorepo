import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subscription.dart';
import '../../models/venue.dart';
import '../../navigation/app_routes.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_spacing.dart';
import '../../utils/business_hours.dart';
import '../../widgets/async_views.dart';
import 'workspace_widgets.dart';

/// The Business workspace: one compact hub per venue.
///
/// The [AppShell] header already owns the brand mark, the venue switcher, the
/// notification bell, the account menu and the "Business" title, so this page
/// opens with a purpose line and the restaurant's identity rather than a second
/// copy of any of that chrome.
///
/// Audit notes this layout keeps true:
///  * every row opens a screen that already exists, with no invented
///    destination and no duplicate row inside the page;
///  * Restaurant Profile is reachable from the identity card and the shortcut
///    strip, so it is deliberately absent from the settings group;
///  * QR and Subscription are shortcuts, then the subscription status card
///    sits in Account, because one is a door and the other is a status;
///  * Menu, Deals and Insights are main tabs. Only *Menu Configuration* is
///    linked here, as the settings doorway the product model asks for;
///  * the Trading status, plan, price and renewal date all come from server
///    reads. Nothing is inferred when a read is loading or has failed.
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
        onRetrySubscription: () => ref.invalidate(subscriptionProvider(venueId)),
      ),
    );
  }
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({
    required this.venue,
    required this.subscription,
    required this.onRetrySubscription,
  });

  final Venue venue;
  final AsyncValue<VenueSubscription> subscription;
  final VoidCallback onRetrySubscription;

  @override
  Widget build(BuildContext context) {
    final status = BusinessHoursStatus.evaluate(
      hours: venue.openingHours,
      serviceDay: DateTime.now(),
      clock: DateTime.now(),
    );
    final horizontal = MediaQuery.sizeOf(context).width < 360
        ? AppSpacing.md
        : AppSpacing.paddingScreen;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide windows keep a readable measure instead of stretching the rows
        // across a desktop monitor; phones use the full width.
        final maxWidth = constraints.maxWidth >= 900 ? 760.0 : double.infinity;

        void open(String route) => Navigator.of(context).pushNamed(route);

        return SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.sm + 4,
              horizontal,
              AppSpacing.xl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const WorkspaceHeader(),
                      const SizedBox(height: AppSpacing.sm + 4),
                      WorkspaceIdentityCard(
                        venue: venue,
                        status: status,
                        onOpenProfile: () => open(_profileRoute),
                      ),
                      const WorkspaceSectionHeader('Quick access'),
                      WorkspaceShortcutGrid(items: _shortcuts, onOpen: open),
                      const WorkspaceSectionHeader('Restaurant settings'),
                      WorkspaceGroup(rows: _settingsRows(status), onOpen: open),
                      const WorkspaceSectionHeader('Business operations'),
                      WorkspaceGroup(rows: _operationRows, onOpen: open),
                      const WorkspaceSectionHeader('Account and support'),
                      WorkspaceSubscriptionCard(
                        subscription: subscription,
                        onOpen: () => open(_subscriptionRoute),
                        onRetry: onRetrySubscription,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      WorkspaceGroup(rows: _accountRows, onOpen: open),
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

// ─── Destinations ───────────────────────────────────────────────────────────

const String _profileRoute = '${AppRoute.business}?tab=profile';
const String _subscriptionRoute = '${AppRoute.business}?tab=subscription';

/// The three surfaces an operator opens most often.
const List<WorkspaceShortcut> _shortcuts = [
  WorkspaceShortcut(
    icon: Icons.storefront_outlined,
    label: 'Restaurant Profile',
    route: _profileRoute,
  ),
  WorkspaceShortcut(
    icon: Icons.qr_code_2,
    label: 'QR Code',
    route: '${AppRoute.business}?tab=qr',
  ),
  WorkspaceShortcut(
    icon: Icons.card_membership_outlined,
    label: 'Subscription',
    route: _subscriptionRoute,
  ),
];

/// Restaurant-level configuration, in the order an owner configures it: when it
/// trades, how it takes bookings, what it offers, then what it sells.
///
/// Booking policies and amenities live inside the venue profile, so each row
/// deep-links to that section rather than opening the same top of page. Hours
/// live on the Service desk's Tables & hours surface.
List<WorkspaceDestination> _settingsRows(BusinessHoursStatus status) => [
  WorkspaceDestination(
    icon: Icons.schedule_outlined,
    label: 'Operating Hours',
    route: '${AppRoute.service}?tab=tables',
    // "Open until 22:00" is the answer the desk needs; an unconfigured week
    // says so instead of leaving the row blank.
    trailing: status.isConfigured && status.detail.isNotEmpty
        ? status.detail
        : 'Not set',
  ),
  const WorkspaceDestination(
    icon: Icons.policy_outlined,
    label: 'Booking Policies',
    route: '${AppRoute.business}?tab=profile&section=policies',
  ),
  const WorkspaceDestination(
    icon: Icons.widgets_outlined,
    label: 'Amenities and Facilities',
    route: '${AppRoute.business}?tab=profile&section=amenities',
  ),
  const WorkspaceDestination(
    icon: Icons.restaurant_menu_outlined,
    label: 'Menu Configuration',
    route: '${AppRoute.business}?tab=menu',
  ),
];

/// The day-to-day desk surfaces.
const List<WorkspaceDestination> _operationRows = [
  WorkspaceDestination(
    icon: Icons.event_available_outlined,
    label: 'Reservations Management',
    route: '${AppRoute.service}?tab=reservations',
  ),
  WorkspaceDestination(
    icon: Icons.auto_awesome_outlined,
    label: 'Dining Experiences',
    route: '${AppRoute.experiences}?tab=experiences',
  ),
  WorkspaceDestination(
    icon: Icons.how_to_reg_outlined,
    label: 'Guest Check-in',
    route: '${AppRoute.service}?tab=checkin',
  ),
];

/// Account and support. Subscription is the card above this group.
const List<WorkspaceDestination> _accountRows = [
  WorkspaceDestination(
    icon: Icons.support_agent_outlined,
    label: 'Help and Support',
    route: '${AppRoute.inbox}?tab=support',
  ),
  WorkspaceDestination(
    icon: Icons.settings_outlined,
    label: 'Account Settings',
    route: AppRoute.settings,
  ),
];
