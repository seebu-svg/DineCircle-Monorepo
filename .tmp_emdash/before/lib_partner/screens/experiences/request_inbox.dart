import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Host proposals awaiting this venue (`GET …/event-requests`).
///
/// Approve publishes the event; decline with a reason is the only counter-offer
/// channel the API gives (there is no in-thread menu or capacity negotiation).
/// A `409` on a replayed decision surfaces as "already decided" rather than a
/// generic failure, because two desks can be looking at the same request.
class RequestInbox extends ConsumerStatefulWidget {
  const RequestInbox({super.key});

  @override
  ConsumerState<RequestInbox> createState() => _RequestInboxState();
}

class _RequestInboxState extends ConsumerState<RequestInbox> {
  String _status = 'requested';

  Future<void> _approve(String venueId, ExperienceRequest request) async {
    final ok = await confirmAction(
      context,
      title: 'Approve ${request.title}?',
      message: 'Publishing makes the experience bookable by guests from '
          '${DisplayDate.day(request.startAt)}.',
      confirmLabel: 'Approve',
    );
    if (!ok) return;
    try {
      await ref
          .read(experienceRepositoryProvider)
          .approve(venueId, request.id);
      ref.invalidate(eventRequestsProvider((venue: venueId, status: _status)));
    } catch (error) {
      if (mounted) {
        reportError(context, error, prefix: 'Could not approve:');
      }
    }
  }

  Future<void> _decline(String venueId, ExperienceRequest request) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DeclineSheet(request: request),
    );
    if (reason == null) return;
    try {
      await ref
          .read(experienceRepositoryProvider)
          .decline(venueId, request.id, reason: reason);
      ref.invalidate(eventRequestsProvider((venue: venueId, status: _status)));
    } catch (error) {
      if (mounted) reportError(context, error, prefix: 'Could not decline:');
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    final requests =
        ref.watch(eventRequestsProvider((venue: venueId, status: _status)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.md,
            AppSpacing.paddingScreen,
            AppSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final entry in const {
                      'requested': 'To review',
                      'confirmed': 'Approved',
                      'declined': 'Declined',
                    }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _status == entry.key,
                    onSelected: (_) => setState(() => _status = entry.key),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AsyncView<List<ExperienceRequest>>(
            value: requests,
            onRetry: () => ref.invalidate(
              eventRequestsProvider((venue: venueId, status: _status)),
            ),
            emptyState: EmptyState(
              title: _status == 'requested'
                  ? 'Nothing to review'
                  : 'No $_status requests',
              message: _status == 'requested'
                  ? 'New host proposals for this venue will appear here.'
                  : 'You have no $_status proposals for this venue.',
              icon: Icons.pending_actions_outlined,
            ),
            builder: (context, rows) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(
                eventRequestsProvider((venue: venueId, status: _status)),
              ),
              child: TileList(
                children: [
                  for (final request in rows)
                    _RequestTile(
                      request: request,
                      venueId: venueId,
                      onApprove: () => _approve(venueId, request),
                      onDecline: () => _decline(venueId, request),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.venueId,
    required this.onApprove,
    required this.onDecline,
  });

  final ExperienceRequest request;
  final String venueId;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.title, style: AppTextStyles.titleMedium),
                ),
                StatusChip(status: r.status.wire, label: r.status.label),
              ],
            ),
            if (r.tagline.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(r.tagline, style: AppTextStyles.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            InfoRow(label: 'Host', value: r.hostName),
            InfoRow(label: 'When', value: DisplayDate.dateTime(r.startAt)),
            InfoRow(label: 'Capacity', value: r.capacityLabel),
            InfoRow(
              label: 'Price',
              value: '${formatMoney(r.pricePerSeat)} / seat',
            ),
            if (r.description.isNotEmpty)
              InfoRow(label: 'About', value: r.description, maxLines: 4),
            if (r.declineReason.isNotEmpty)
              InfoRow(label: 'Declined', value: r.declineReason),
            if (r.isAwaitingDecision) ...[
              const SizedBox(height: AppSpacing.md),
              RoleGateBuilder(
                capability: Capability.approveRequests,
                builder: (context, allowed, _) => Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: allowed ? onDecline : null,
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: allowed ? onApprove : null,
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeclineSheet extends ConsumerStatefulWidget {
  const _DeclineSheet({required this.request});

  final ExperienceRequest request;

  @override
  ConsumerState<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends ConsumerState<_DeclineSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Decline ${widget.request.title}',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The reason is shared with the host. It is the venue\'s only '
            'chance to say why a proposal does not work.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            maxLength: Validators.declineReasonMax,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Date clash, capacity, style…',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
            child: const Text('Send decline'),
          ),
        ],
      ),
    );
  }
}
