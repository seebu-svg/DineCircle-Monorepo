import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comms.dart';
import '../../models/experience.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/money.dart';
import '../../widgets/async_views.dart';
import '../../widgets/data_widgets.dart';
import '../../widgets/status_chip.dart';

/// The people proposing experiences at this venue (module 11).
///
/// There is no partner "hosts" list on the API; a host is whoever appears on an
/// event request. Their performance is private to the host relationship, so
/// `GET /hosts/:id/summary` answers `403` for a venue that only supplied the
/// space — that is rendered as "numbers not shared", never as an error screen.
/// Coordination is approve/decline plus notifications; a live chat thread only
/// exists when this account is itself the event's host.
class HostsTab extends ConsumerStatefulWidget {
  const HostsTab({super.key});

  @override
  ConsumerState<HostsTab> createState() => _HostsTabState();
}

class _HostsTabState extends ConsumerState<HostsTab> {
  String? _selectedHostId;

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    final requests =
        ref.watch(eventRequestsProvider((venue: venueId, status: 'requested')));
    final decided =
        ref.watch(eventRequestsProvider((venue: venueId, status: 'confirmed')));

    final hosts = <String, String>{};
    void collect(List<ExperienceRequest>? rows) {
      if (rows == null) return;
      for (final r in rows) {
        if (r.hostId.isNotEmpty) hosts[r.hostId] = r.hostName;
      }
    }

    collect(requests.valueOrNull);
    collect(decided.valueOrNull);

    return requests.when(
      skipLoadingOnRefresh: true,
      loading: () => const LoadingSkeleton(count: 3),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () {
          ref.invalidate(
              eventRequestsProvider((venue: venueId, status: 'requested')));
          ref.invalidate(
              eventRequestsProvider((venue: venueId, status: 'confirmed')));
        },
      ),
      data: (_) {
        if (hosts.isEmpty) {
          return const EmptyState(
            title: 'No hosts yet',
            message: 'Hosts appear here once someone proposes an experience '
                'at this venue.',
            icon: Icons.person_outline,
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Hosts', style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final entry in hosts.entries)
                    ListTile(
                      selected: _selectedHostId == entry.key,
                      leading: CircleAvatar(
                        child: Text(entry.value.isEmpty
                            ? '?'
                            : entry.value[0].toUpperCase()),
                      ),
                      title: Text(
                        entry.value.isEmpty ? 'Host' : entry.value,
                        style: AppTextStyles.bodyLarge,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => setState(() => _selectedHostId = entry.key),
                    ),
                ],
              ),
            ),
            if (_selectedHostId != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _HostSummary(
                hostId: _selectedHostId!,
                name: hosts[_selectedHostId] ?? 'Host',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HostSummary extends ConsumerWidget {
  const _HostSummary({required this.hostId, required this.name});

  final String hostId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(hostSummaryProvider(hostId));
    return summary.when(
      loading: () => const LoadingSkeleton(count: 1),
      error: (_, _) => const DisabledTile(
        title: 'Host numbers are private',
        reason: 'This venue supplied the space but is not the host, so the '
            'platform does not share their earnings with you.',
        icon: Icons.lock_outline,
      ),
      data: (host) => _HostCard(host: host),
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.host});

  final HostProfile host;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              child: Text(
                host.name.isEmpty ? '?' : host.name[0].toUpperCase(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(host.name, style: AppTextStyles.headlineSmall),
                  if (host.handle.isNotEmpty)
                    Text('@${host.handle.replaceFirst('@', '')}',
                        style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const StatusChip(status: 'active', label: 'Host'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        DataGrid(
          minTileWidth: 160,
          children: [
            KpiCard(
              label: 'Hosted',
              value: '${host.hostedCount}',
              icon: Icons.event,
            ),
            KpiCard(
              label: 'Seats sold',
              value: '${host.seatsSold}',
              icon: Icons.groups,
            ),
            KpiCard(
              label: 'Lifetime gross',
              value: formatMoney(host.lifetimeGross, decimals: 0),
              icon: Icons.payments,
            ),
            KpiCard(
              label: 'Avg fill rate',
              value: '${(host.averageFillRate * 100).toStringAsFixed(0)}%',
              icon: Icons.donut_large,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const DisabledTile(
          title: 'Direct messaging',
          reason: 'A coordination thread is only available when this account is '
              'the host of the event. Approve or decline proposals and the host '
              'is notified.',
          icon: Icons.chat_bubble_outline,
        ),
      ],
    );
  }
}
