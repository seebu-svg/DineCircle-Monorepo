
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_routes.dart';
import '../../providers/venue_scope_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_tabs.dart';
import '../auth/auth_gate.dart';
import 'analytics_tab.dart';
import 'deals_tab.dart';
import 'menu_tab.dart';
import 'profile_tab.dart';
import 'qr_tab.dart';
import 'subscription_tab.dart';
import 'workspace_tab.dart';

/// Business management destination.
///
/// Preserves:
/// - Existing venue access gate
/// - All seven business tabs
/// - Existing tab keys and deep links
/// - Existing AppShell navigation
/// - Existing module functionality
class BusinessSectionScreen extends ConsumerWidget {
  const BusinessSectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(selectedVenueProvider);

    if (venue == null) {
      return const AuthGate();
    }

    final requestedTab = routeQuery(context)['tab'];

    return AppShell(
      active: PrimaryDestination.business,
      title: 'Business',
      child: SectionTabs(
        initialTab: requestedTab,
        tabs: const [
          SectionTab(
            key: 'workspace',
            label: 'Workspace',
            icon: Icons.dashboard_customize_outlined,
            child: WorkspaceTab(),
          ),
          SectionTab(
            key: 'profile',
            label: 'Profile',
            icon: Icons.storefront_outlined,
            child: ProfileTab(),
          ),
          SectionTab(
            key: 'menu',
            label: 'Menu',
            icon: Icons.restaurant_menu_rounded,
            child: MenuTab(),
          ),
          SectionTab(
            key: 'deals',
            label: 'Deals',
            icon: Icons.local_offer_outlined,
            child: DealsTab(),
          ),
          SectionTab(
            key: 'qr',
            label: 'QR Code',
            icon: Icons.qr_code_2_rounded,
            child: QrTab(),
          ),
          SectionTab(
            key: 'analytics',
            label: 'Analytics',
            icon: Icons.insights_outlined,
            child: AnalyticsTab(),
          ),
          SectionTab(
            key: 'subscription',
            label: 'Subscription',
            icon: Icons.workspace_premium_outlined,
            child: SubscriptionTab(),
          ),
        ],
      ),
    );
  }
}
