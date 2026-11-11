
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_routes.dart';
import '../../providers/venue_scope_provider.dart';
import '../../widgets/app_shell.dart';
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
/// - All seven business tabs accessible via route query
/// - Existing AppShell navigation
/// - Existing module functionality
///
/// The tab strip is intentionally omitted: the bottom nav (Menu, Deals,
/// Insights, Business) and the Workspace tab's links provide all navigation.
/// A horizontal strip of seven tabs below the header duplicated that chrome
/// and cluttered the screen.
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
      child: _tabFor(requestedTab),
    );
  }

  Widget _tabFor(String? requestedTab) {
    return switch (requestedTab) {
      'workspace' => const WorkspaceTab(),
      'profile' => const ProfileTab(),
      'menu' => const MenuTab(),
      'deals' => const DealsTab(),
      'qr' => const QrTab(),
      'analytics' => const AnalyticsTab(),
      'subscription' => const SubscriptionTab(),
      _ => const WorkspaceTab(),
    };
  }
}
