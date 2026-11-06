import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_routes.dart';
import '../../providers/venue_scope_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_tabs.dart';
import '../auth/auth_gate.dart';
import 'experiences_list.dart';
import 'hosts_tab.dart';
import 'request_inbox.dart';

/// Experiences: what hosts propose, what you run, and who you work with.
///
/// One destination, three surfaces behind `?tab=`. Approvals are venue-scoped,
/// the experience list is account-wide, and hosts are derived from the requests.
class ExperiencesSectionScreen extends ConsumerWidget {
  const ExperiencesSectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(selectedVenueProvider) == null) return const AuthGate();
    final tab = routeQuery(context)['tab'];
    return AppShell(
      active: PrimaryDestination.business,
      title: 'Experiences',
      child: SectionTabs(
        initialTab: tab,
        tabs: const [
          SectionTab(
            key: 'requests',
            label: 'Requests',
            icon: Icons.pending_actions_outlined,
            child: RequestInbox(),
          ),
          SectionTab(
            key: 'experiences',
            label: 'Experiences',
            icon: Icons.auto_awesome_outlined,
            child: ExperiencesScreen(),
          ),
          SectionTab(
            key: 'hosts',
            label: 'Hosts',
            icon: Icons.person_outline,
            child: HostsTab(),
          ),
        ],
      ),
    );
  }
}
