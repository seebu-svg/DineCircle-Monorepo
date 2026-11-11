import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_routes.dart';
import '../../providers/venue_scope_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_tabs.dart';
import '../auth/auth_gate.dart';
import 'notifications_screen.dart';
import 'reviews_screen.dart';
import 'support_screen.dart';

/// The Inbox: alerts, guest feedback and the support channel.
///
/// Three surfaces behind one destination, opened by `?tab=`. Notifications and
/// support are account-wide; reviews resolve per experience but sit with the
/// venue the switcher points at.
class InboxSectionScreen extends ConsumerWidget {
  const InboxSectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(selectedVenueProvider) == null) return const AuthGate();
    final tab = routeQuery(context)['tab'];
    return AppShell(
      active: PrimaryDestination.business,
      child: SectionTabs(
        initialTab: tab,
        tabs: const [
          SectionTab(
            key: 'notifications',
            label: 'Notifications',
            icon: Icons.notifications_none,
            child: NotificationsScreen(),
          ),
          SectionTab(
            key: 'reviews',
            label: 'Reviews',
            icon: Icons.star_outline,
            child: ReviewsScreen(),
          ),
          SectionTab(
            key: 'support',
            label: 'Support',
            icon: Icons.support_agent_outlined,
            child: SupportScreen(),
          ),
        ],
      ),
    );
  }
}
