import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_routes.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_tabs.dart';
import '../auth/auth_gate.dart';
import 'experiences_list.dart';
import 'hosts_tab.dart';
import 'proposals_tab.dart';
import 'request_inbox.dart';

/// Experiences: what hosts propose, what you run, and who you work with.
///
/// Three primary surfaces behind `?tab=`: Requests (approvals, venue-scoped),
/// Proposals (two-way collaboration, venue-scoped) and Experiences (the events
/// this account operates). Host discovery is not a fourth tab: it is where a
/// proposal starts, so it opens from Proposals and from the empty outbox, and
/// the section keeps the three destinations the product promises.
///
/// `?tab=hosts` still opens host discovery, so an existing Home link or a saved
/// web URL lands where it used to.
class ExperiencesSectionScreen extends ConsumerStatefulWidget {
  const ExperiencesSectionScreen({super.key});

  @override
  ConsumerState<ExperiencesSectionScreen> createState() =>
      _ExperiencesSectionScreenState();
}

class _ExperiencesSectionScreenState
    extends ConsumerState<ExperiencesSectionScreen> {
  bool _hostsHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hostsHandled || !mounted) return;
      if (routeQuery(context)['tab'] != 'hosts') return;
      _hostsHandled = true;
      openHostDiscovery(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(selectedVenueProvider) == null) return const AuthGate();
    final tab = routeQuery(context)['tab'];
    return AppShell(
      active: PrimaryDestination.business,
      child: SectionTabs(
        initialTab: tab,
        scrollable: true,
        tabs: [
          const SectionTab(
            key: 'requests',
            label: 'Requests',
            icon: Icons.pending_actions_outlined,
            child: RequestInbox(),
          ),
          SectionTab(
            key: 'proposals',
            label: 'Proposals',
            icon: Icons.handshake_outlined,
            child: ProposalsTab(onFindHost: () => openHostDiscovery(context)),
          ),
          const SectionTab(
            key: 'experiences',
            label: 'Experiences',
            icon: Icons.auto_awesome_outlined,
            child: ExperiencesScreen(),
          ),
        ],
      ),
    );
  }
}

/// Host discovery, opened from Proposals or from a `?tab=hosts` link.
///
/// A sheet rather than a fourth tab or a new route: the five primary
/// destinations stay untouched and host discovery stays one gesture from the
/// outbox it serves, while the composer inside it can still open on top.
Future<void> openHostDiscovery(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.radiusSheet),
      ),
    ),
    builder: (_) => const _HostDiscoverySheet(),
  );
}

class _HostDiscoverySheet extends StatelessWidget {
  const _HostDiscoverySheet();

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.paddingScreen,
                AppSpacing.md,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Find a host', style: AppTextStyles.headlineSmall),
                        Text(
                          'Professional hosts you can propose an experience to.',
                          style: AppTextStyles.bodySmall,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Expanded(child: HostsTab()),
          ],
        ),
      ),
    );
  }
}
