import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exception.dart';
import '../../models/collab.dart';
import '../../models/comms.dart';
import '../../models/experience.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../utils/money.dart';
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/data_widgets.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

/// The people this venue can start a collaboration with (module 11).
///
/// The list is a discovery read rather than a derived one:
/// `GET …/discover-hosts` returns professional hosts and already leaves out
/// anybody covered by an active collaboration, so every name here is a name the
/// composer will accept. Deriving hosts from event requests, as this tab used to
/// do, meant a venue could only see a host after that host had already written
/// to them, and the "Send proposal" action had no target to aim at.
///
/// The composer can attach a draft experience the venue holds for that host,
/// which is the only way an event created on the partner side reaches a host
/// without being published first.
class HostsTab extends ConsumerStatefulWidget {
  const HostsTab({super.key});

  @override
  ConsumerState<HostsTab> createState() => _HostsTabState();
}

class _HostsTabState extends ConsumerState<HostsTab> {
  final _search = TextEditingController();
  String? _selectedHostId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ({String venue, String query}) _key(String venueId) =>
      (venue: venueId, query: _search.text.trim());

  /// Direction B: hand a draft to a host and let them publish it.
  Future<void> _propose(String venueId, DiscoverableHost host) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProposalComposer(venueId: venueId, host: host),
    );
    if (sent != true || !mounted) return;
    // The pair is now covered by an active proposal, so the host drops out of
    // discovery, and the same proposal appears in the venue's outbox. The feed
    // is invalidated through the shared key the Proposals tab renders; a
    // direction-scoped record would be a different cache entry and leave the
    // outbox showing the list from before this send.
    ref.invalidate(discoverHostsProvider(_key(venueId)));
    ref.invalidate(collabProposalsProvider(proposalFeedKey(venueId)));
    setState(() {
      if (_selectedHostId == host.id) _selectedHostId = null;
    });
    showToast(context, 'Proposal sent to ${host.displayName}');
  }

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    final hosts = ref.watch(discoverHostsProvider(_key(venueId)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.md,
            AppSpacing.paddingScreen,
            AppSpacing.sm,
          ),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search hosts by name or @handle',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: AsyncView<List<DiscoverableHost>>(
            value: hosts,
            onRetry: () => ref.invalidate(discoverHostsProvider(_key(venueId))),
            emptyState: EmptyState(
              title: _search.text.trim().isEmpty
                  ? 'No hosts to propose to'
                  : 'No host matches that search',
              message: _search.text.trim().isEmpty
                  ? 'Professional hosts who are not already collaborating with '
                        'this venue appear here, ready to receive a proposal.'
                  : 'Try a shorter name, or clear the search to see everyone.',
              icon: Icons.person_search_outlined,
            ),
            builder: (context, rows) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(discoverHostsProvider(_key(venueId))),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.paddingScreen),
                children: [
                  Text('Hosts', style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${rows.length} professional '
                    '${rows.length == 1 ? 'host' : 'hosts'} open to a proposal '
                    'at this venue.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final host in rows)
                    _HostTile(
                      host: host,
                      selected: _selectedHostId == host.id,
                      onSelect: () => setState(
                        () => _selectedHostId =
                            _selectedHostId == host.id ? null : host.id,
                      ),
                      onPropose: () => _propose(venueId, host),
                    ),
                  if (_selectedHostId != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _HostSummary(hostId: _selectedHostId!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HostTile extends StatelessWidget {
  const _HostTile({
    required this.host,
    required this.selected,
    required this.onSelect,
    required this.onPropose,
  });

  final DiscoverableHost host;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) {
    final handle = host.handle.trim().isEmpty
        ? ''
        : '@${host.handle.trim().replaceFirst('@', '')}';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          ListTile(
            selected: selected,
            leading: CircleAvatar(child: Text(host.initials)),
            title: Text(host.displayName, style: AppTextStyles.bodyLarge),
            subtitle: Text(
              [
                if (handle.isNotEmpty) handle,
                if (host.hasWorkedHere)
                  '${host.eventsTogether} event'
                      '${host.eventsTogether == 1 ? '' : 's'} here before',
                if (!host.hasWorkedHere && host.followersCount > 0)
                  '${host.followersCount} followers',
              ].join('  ·  '),
              style: AppTextStyles.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onSelect,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.paddingCard,
              0,
              AppSpacing.paddingCard,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: RoleGateBuilder(
                capability: Capability.createExperiences,
                builder: (context, allowed, denial) => Tooltip(
                  message: denial ?? 'Propose an experience to this host',
                  child: OutlinedButton.icon(
                    onPressed: allowed ? onPropose : null,
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send proposal'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Direction-B composer: a title, a message, and optionally a draft.
///
/// Only drafts this venue holds *for this host* are offered, because the server
/// rejects an attachment whose `restaurant_id` or `host_id` does not match
/// (422), and offering a draft that would be refused wastes the venue's only
/// proposal slot for the pair.
class _ProposalComposer extends ConsumerStatefulWidget {
  const _ProposalComposer({required this.venueId, required this.host});

  final String venueId;
  final DiscoverableHost host;

  @override
  ConsumerState<_ProposalComposer> createState() => _ProposalComposerState();
}

class _ProposalComposerState extends ConsumerState<_ProposalComposer> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  String? _experienceId;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  /// The venue's drafts that belong to the host being proposed to.
  List<PartnerExperience> _attachable(List<PartnerExperience> all) => all
      .where(
        (e) =>
            e.status == ExperienceStatus.draft &&
            e.restaurantId == widget.venueId &&
            e.hostId == widget.host.id,
      )
      .toList();

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(experienceRepositoryProvider)
          .proposeToHost(
            venueId: widget.venueId,
            hostId: widget.host.id,
            title: _title.text,
            message: _message.text,
            experienceId: _experienceId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        reportError(context, error, prefix: 'Could not send the proposal:');
      }
    } catch (error) {
      if (mounted) {
        reportError(context, error, prefix: 'Could not send the proposal:');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(experiencesProvider('draft'));
    final hostName = widget.host.displayName;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Propose to $hostName', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The host receives this as an incoming proposal. Nothing is '
              'published until they accept and, if the venue requires it, '
              'approve the experience themselves.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              validator: (value) => Validators.text(
                value,
                field: 'Title',
                min: 3,
                max: 120,
              ),
              decoration: const InputDecoration(
                labelText: 'Proposal title',
                hintText: 'Chef\'s table with the host of …',
              ),
            ),
            TextFormField(
              controller: _message,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => Validators.text(
                value,
                field: 'Message',
                min: 1,
                max: 1000,
              ),
              decoration: const InputDecoration(
                labelText: 'Message to the host',
                hintText: 'What you are offering, when, and why this host',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            drafts.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (_, _) => const DisabledTile(
                title: 'Drafts unavailable',
                reason: 'The venue\'s own drafts could not be loaded, so this '
                    'proposal can only be sent without one.',
                icon: Icons.cloud_off_outlined,
              ),
              data: (all) {
                final attachable = _attachable(all);
                if (attachable.isEmpty) {
                  return const DisabledTile(
                    title: 'No draft to attach',
                    reason: 'Only a draft this venue holds for this host can be '
                        'attached. Send the proposal as a message, or create '
                        'the experience first.',
                    icon: Icons.event_busy_outlined,
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: _experienceId,
                  decoration: const InputDecoration(
                    labelText: 'Attach a draft',
                    helperText: 'Optional — the host publishes it after accepting',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No experience attached'),
                    ),
                    for (final draft in attachable)
                      DropdownMenuItem<String>(
                        value: draft.id,
                        child: Text(
                          '${draft.title.trim().isEmpty ? 'Untitled draft' : draft.title}'
                          '  ·  ${DisplayDate.day(draft.startAt)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _experienceId = value),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_busy ? 'Sending…' : 'Send proposal'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The host's public numbers, opened from a selected row.
///
/// `GET /hosts/:id/summary` answers `403` when the platform keeps these private;
/// that is a normal outcome here and is rendered as an explanation, never as a
/// failure screen with a retry button.
class _HostSummary extends ConsumerWidget {
  const _HostSummary({required this.hostId});

  final String hostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(hostSummaryProvider(hostId));
    return summary.when(
      loading: () => const LoadingSkeleton(count: 1),
      error: (error, _) => DisabledTile(
        title: 'Host numbers are private',
        reason: error is ApiException
            ? '${error.message} This venue can still propose to the host.'
            : 'This venue supplied the space but is not the host, so the '
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
                    Text(
                      '@${host.handle.replaceFirst('@', '')}',
                      style: AppTextStyles.bodySmall,
                    ),
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
      ],
    );
  }
}
