import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/collab.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../repositories/experience_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';
import 'experiences_widgets.dart';

/// The venue's two-way collaboration inbox (`GET …/collab-proposals`).
///
/// One surface for both halves of the conversation: proposals a host sent this
/// venue, which the venue answers, and proposals the venue sent a host, which
/// the venue can only withdraw. The whole feed is read once and split by
/// direction on the client so the rail can show how many rows sit behind each
/// half, and so switching sides never re-hits the API.
///
/// A `409` on a decision means the other side got there first, which is
/// reported as "no longer pending" instead of a generic failure, because two
/// desks really can be looking at the same invitation.
///
/// When the deployed server does not mount this router at all it answers
/// `404 Route not found`. That is rendered as a named capability gap with the
/// server's own words, never as "no proposals".
class ProposalsTab extends ConsumerStatefulWidget {
  const ProposalsTab({super.key, this.onFindHost});

  /// Opens host discovery. Hosts are not a fourth primary tab, they are the
  /// place a proposal starts from, so the entry point lives inside Proposals.
  final VoidCallback? onFindHost;

  @override
  ConsumerState<ProposalsTab> createState() => _ProposalsTabState();
}

class _ProposalsTabState extends ConsumerState<ProposalsTab> {
  ProposalDirection? _direction;

  Future<void> _answer(CollabProposal proposal, bool accept) async {
    final venueId = ref.read(selectedVenueIdProvider);
    if (accept) {
      final ok = await confirmAction(
        context,
        title: 'Accept "${proposal.title}"?',
        message:
            'Accepting starts the collaboration with '
            '${proposal.host.displayName} and lets them publish the '
            'experience at this venue.',
        confirmLabel: 'Accept',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    // Dismissing the sheet returns null, which means the desk backed out and no
    // decision was taken. Only the sheet's own button returns a string, and an
    // empty one is a deliberate decline without a reason.
    var reason = '';
    if (!accept) {
      final entered = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _DeclineProposalSheet(proposal: proposal),
      );
      if (entered == null) return;
      reason = entered;
    }
    if (!mounted) return;
    try {
      await ref
          .read(experienceRepositoryProvider)
          .answerProposal(venueId, proposal.id, accept: accept, reason: reason);
      // The tab reads the unfiltered feed once and splits it locally, so the
      // provider to re-read is the null-direction one, not the current chip.
      ref.invalidate(collabProposalsProvider(proposalFeedKey(venueId)));
    } catch (error) {
      if (mounted) {
        reportError(context, error, prefix: 'Could not answer:');
      }
    }
  }

  Future<void> _cancel(CollabProposal proposal) async {
    final venueId = ref.read(selectedVenueIdProvider);
    final ok = await confirmAction(
      context,
      title: 'Withdraw this invitation?',
      message:
          '${proposal.host.displayName} will no longer be able to '
          'accept "${proposal.title}".',
      confirmLabel: 'Withdraw',
    );
    if (!ok) return;
    try {
      await ref
          .read(experienceRepositoryProvider)
          .cancelProposal(venueId, proposal.id);
      ref.invalidate(collabProposalsProvider(proposalFeedKey(venueId)));
    } catch (error) {
      if (mounted) {
        reportError(context, error, prefix: 'Could not withdraw:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    final venue = ref.watch(selectedVenueProvider);
    final key = proposalFeedKey(venueId);
    final proposals = ref.watch(collabProposalsProvider(key));

    final rows = proposals.valueOrNull ?? const <CollabProposal>[];
    final incoming = rows.where(
      (row) => row.direction == ProposalDirection.incoming,
    );
    final outgoing = rows.where(
      (row) => row.direction == ProposalDirection.outgoing,
    );
    final toAnswer = incoming.where((row) => row.awaitsVenue).length;
    final waiting = outgoing.where((row) => row.awaitsHost).length;
    final accepted = rows.where((row) => row.status == ProposalStatus.accepted);

    final visible = switch (_direction) {
      null => rows,
      ProposalDirection.incoming => incoming.toList(growable: false),
      ProposalDirection.outgoing => outgoing.toList(growable: false),
    };

    // One scroll view for header, rail and feed, so the photo header can never
    // pin the feed into a sliver of screen on a small phone or at 2x text.
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(collabProposalsProvider(key)),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.paddingScreen,
              AppSpacing.md,
              AppSpacing.paddingScreen,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: ExperienceHeader(
                venueName: venue?.name ?? '',
                subtitle: proposals.hasError
                    ? 'Collaboration proposals between this venue and its hosts.'
                    : toAnswer == 0 && waiting == 0
                    ? 'No conversation is waiting on anybody right now.'
                    : '$toAnswer to answer · $waiting waiting on a host · '
                          '${accepted.length} accepted',
                metrics: [
                  (
                    value: proposals.hasError ? '-' : '$toAnswer',
                    label: 'To answer',
                  ),
                  (
                    value: proposals.hasError ? '-' : '$waiting',
                    label: 'Waiting on host',
                  ),
                  (
                    value: proposals.hasError ? '-' : '${accepted.length}',
                    label: 'Accepted',
                  ),
                ],
                artAsset: 'assets/images/venue_interior.png',
                action: widget.onFindHost == null
                    ? null
                    : OutlinedButton.icon(
                        onPressed: widget.onFindHost,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: AppColors.bg.withValues(alpha: 0.45),
                          side: const BorderSide(color: AppColors.borderLight),
                          minimumSize: const Size(0, AppSpacing.minTapTarget),
                        ),
                        icon: const Icon(Icons.person_search_outlined, size: 18),
                        label: const Text('Find a host'),
                      ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ExperienceFilterRail(
              selected: _direction?.wire,
              options: [
                ExperienceFilterOption(
                  key: null,
                  label: 'All',
                  count: proposals.hasError ? null : rows.length,
                ),
                ExperienceFilterOption(
                  key: ProposalDirection.incoming.wire,
                  label: 'Incoming',
                  count: proposals.hasError ? null : incoming.length,
                ),
                ExperienceFilterOption(
                  key: ProposalDirection.outgoing.wire,
                  label: 'Sent by you',
                  count: proposals.hasError ? null : outgoing.length,
                ),
              ],
              onSelected: (wire) => setState(
                () => _direction = wire == null
                    ? null
                    : ProposalDirection.parse(wire),
              ),
            ),
          ),
          if (proposals.hasError)
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.paddingScreen),
              sliver: SliverToBoxAdapter(
                child: _ProposalFailure(
                  error: proposals.error!,
                  onRetry: () =>
                      ref.invalidate(collabProposalsProvider(key)),
                ),
              ),
            )
          else if (!proposals.hasValue)
            const SliverToBoxAdapter(
              child: LoadingSkeleton(count: 3, itemHeight: 156),
            )
          else if (visible.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.paddingScreen,
                0,
                AppSpacing.paddingScreen,
                AppSpacing.xl,
              ),
              sliver: SliverToBoxAdapter(
                child: ExperienceEmpty(
                  title: _switchEmptyTitle(),
                  message: _switchEmptyMessage(),
                  icon: Icons.handshake_outlined,
                  action: widget.onFindHost == null
                      ? null
                      : OutlinedButton.icon(
                          onPressed: widget.onFindHost,
                          icon: const Icon(
                            Icons.person_search_outlined,
                            size: 18,
                          ),
                          label: const Text('Find a host'),
                        ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.paddingScreen,
                0,
                AppSpacing.paddingScreen,
                AppSpacing.xl,
              ),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final proposal = visible[index];
                  return _ProposalCard(
                    proposal: proposal,
                    onAccept: () => _answer(proposal, true),
                    onDecline: () => _answer(proposal, false),
                    onCancel: () => _cancel(proposal),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _switchEmptyTitle() => switch (_direction) {
    null => 'No proposals yet',
    ProposalDirection.incoming => 'Nothing to answer',
    ProposalDirection.outgoing => 'Nothing sent yet',
  };

  String _switchEmptyMessage() => switch (_direction) {
    null =>
      'Collaboration proposals between this venue and hosts appear '
          'here, whichever side asked first.',
    ProposalDirection.incoming =>
      'When a host proposes working together, '
          'it lands here for your decision.',
    ProposalDirection.outgoing =>
      'Invite a professional host from Find a host and their reply will '
          'show up here.',
  };
}

/// The three ways this feed can fail, said differently.
///
/// A missing router is not a network problem and not a permission problem, so
/// it gets the named-gap treatment. Everything else keeps the shared error view
/// with its retry.
class _ProposalFailure extends StatelessWidget {
  const _ProposalFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error is FeatureUnavailableException) {
      final gap = error as FeatureUnavailableException;
      return ExperienceUnavailable(
        title: '${gap.feature} are not on this server build',
        message:
            'The proposal inbox and host discovery are served by a router '
            'this API deployment does not include. Nothing is lost: the '
            'rows are in PostgreSQL and will appear as soon as the server '
            'that mounts /partner/restaurants/:id/collab-proposals is '
            'deployed. Meanwhile you can still review host requests and '
            'run experiences.',
        detail:
            'GET /api/partner/restaurants/:id/collab-proposals → '
            '${gap.detail.trim().isEmpty ? '404 Route not found' : gap.detail}',
        onRetry: onRetry,
      );
    }
    return ErrorView(error: error, onRetry: onRetry);
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onAccept,
    required this.onDecline,
    required this.onCancel,
  });

  final CollabProposal proposal;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = proposal;
    final experience = p.experience;
    final incoming = p.direction == ProposalDirection.incoming;
    final next = p.awaitsVenue
        ? 'Your decision'
        : p.awaitsHost
        ? 'Waiting on ${p.host.displayName}'
        : switch (p.status) {
            ProposalStatus.accepted => 'Collaboration accepted',
            ProposalStatus.declined => incoming
                // An incoming row was declined by this venue, so naming the
                // host as the decider would invert who turned down whom.
                ? 'Declined by your venue'
                : 'Declined by ${p.host.displayName}',
            ProposalStatus.cancelled => 'Withdrawn',
            ProposalStatus.completed => 'Completed',
            ProposalStatus.invited => 'Awaiting reply',
          };

    return ExperienceCard(
      key: ValueKey('proposal-card-${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (incoming ? AppColors.info : AppColors.gold)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        incoming
                            ? Icons.call_received
                            : Icons.call_made_outlined,
                        size: 13,
                        color: incoming ? AppColors.info : AppColors.gold,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        incoming ? 'Incoming' : 'Sent by you',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: incoming ? AppColors.info : AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: StatusChip(
                      status: p.statusTone,
                      label: p.awaitsVenue ? 'Your decision' : p.status.label,
                      dense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(p.title, style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ExperienceHostIdentity(
              name: p.host.displayName,
              handle: p.host.handle,
              avatarUrl: p.host.avatarUrl,
              caption: incoming
                  ? 'proposed this to your venue'
                  : 'was invited by your venue',
            ),
            if (p.message.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                p.message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (experience != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ExperienceMetaRow(
                icon: Icons.auto_awesome_outlined,
                label: 'Experience',
                value: experience.title,
              ),
              if (experience.startAt != null)
                ExperienceMetaRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'When',
                  value: DisplayDate.dateTime(experience.startAt!),
                ),
            ],
            if (p.createdAt != null)
              ExperienceMetaRow(
                icon: Icons.schedule_outlined,
                label: incoming ? 'Received' : 'Sent',
                value: DisplayDate.relative(p.createdAt!),
              ),
            if (p.declineReason.isNotEmpty)
              ExperienceMetaRow(
                icon: Icons.block,
                label: 'Reason',
                value: p.declineReason,
                tone: AppColors.danger,
              ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_forward,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs + 2),
                  Expanded(
                    child: Text(
                      'Next: $next',
                      style: AppTextStyles.labelSmall,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            if (p.status.isOpen) ...[
              const SizedBox(height: AppSpacing.md),
              if (incoming)
                RoleGateBuilder(
                  capability: Capability.approveRequests,
                  builder: (context, allowed, denial) => Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton(
                        key: ValueKey('proposal-decline-${p.id}'),
                        onPressed: allowed ? onDecline : null,
                        child: const Text('Decline'),
                      ),
                      Tooltip(
                        message: allowed ? 'Start the collaboration' : denial,
                        child: FilledButton(
                          key: ValueKey('proposal-accept-${p.id}'),
                          onPressed: allowed ? onAccept : null,
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    key: ValueKey('proposal-withdraw-${p.id}'),
                    onPressed: onCancel,
                    child: const Text('Withdraw invitation'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Captures the reason a venue turns a host down. Optional, but it is the only
/// reply channel the proposal has, so the field is focused on open.
class _DeclineProposalSheet extends ConsumerStatefulWidget {
  const _DeclineProposalSheet({required this.proposal});

  final CollabProposal proposal;

  @override
  ConsumerState<_DeclineProposalSheet> createState() =>
      _DeclineProposalSheetState();
}

class _DeclineProposalSheetState extends ConsumerState<_DeclineProposalSheet> {
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
          Text(
            'Decline "${widget.proposal.title}"',
            style: AppTextStyles.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The reason is shared with the host. It is the venue\'s only '
            'chance to say why the collaboration does not work.',
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
              hintText: 'Dates, capacity, concept…',
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
