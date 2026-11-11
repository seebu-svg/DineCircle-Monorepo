import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/experience.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../utils/money.dart';
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/media_image.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';
import 'experiences_widgets.dart';

/// Host proposals awaiting this venue (`GET …/event-requests`).
///
/// Approve publishes the event; decline with a reason is the only counter-offer
/// channel the API gives (there is no in-thread menu or capacity negotiation).
/// A `409` on a replayed decision surfaces as "already decided" rather than a
/// generic failure, because two desks can be looking at the same request.
///
/// All three queues are read at once so the rail's counts are measured rather
/// than guessed, and so switching To review / Approved / Declined is instant.
/// The row is a summary on purpose: the detail sheet loads the full record
/// (`GET …/event-requests/:eventId`) so the venue decides having seen the menu,
/// the gallery, the audience gate and the host's note.
class RequestInbox extends ConsumerStatefulWidget {
  const RequestInbox({super.key});

  @override
  ConsumerState<RequestInbox> createState() => _RequestInboxState();
}

class _RequestInboxState extends ConsumerState<RequestInbox> {
  String _status = 'requested';

  static const _labels = {
    'requested': 'To review',
    'confirmed': 'Approved',
    'declined': 'Declined',
  };

  AsyncValue<List<ExperienceRequest>> _read(String venueId, String status) =>
      ref.watch(eventRequestsProvider((venue: venueId, status: status)));

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
      _invalidateAll(venueId);
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
      _invalidateAll(venueId);
    } catch (error) {
      if (mounted) reportError(context, error, prefix: 'Could not decline:');
    }
  }

  /// A decision moves the row from one queue to another, so every queue is
  /// re-read: refreshing only the visible one leaves a stale count on the rail.
  void _invalidateAll(String venueId) {
    for (final status in _labels.keys) {
      ref.invalidate(eventRequestsProvider((venue: venueId, status: status)));
    }
  }

  /// Opens the full record behind a request so the decision is informed.
  void _openDetail(String venueId, ExperienceRequest request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequestDetailSheet(
        venueId: venueId,
        summary: request,
        onDecided: () => _invalidateAll(venueId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    final venue = ref.watch(selectedVenueProvider);
    final reads = {
      for (final status in _labels.keys) status: _read(venueId, status),
    };
    final current = reads[_status]!;
    final counts = {
      for (final entry in reads.entries)
        entry.key: entry.value.valueOrNull?.length,
    };
    final toReview = counts['requested'];

    final rows = current.valueOrNull ?? const <ExperienceRequest>[];

    // One scroll view for header, rail and queue: the photo header has to be
    // able to scroll away instead of pinning the queue into a sliver of screen
    // on a small phone or at 2x text.
    return RefreshIndicator(
      onRefresh: () async => _invalidateAll(venueId),
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
                subtitle: toReview == null
                    ? 'Host proposals for your table. Loading the queue.'
                    : toReview == 0
                    ? 'No host is waiting on you. New proposals land here first.'
                    : '$toReview host proposal${toReview == 1 ? '' : 's'} '
                          'waiting on your decision.',
                metrics: [
                  (
                    value: toReview?.toString() ?? '-',
                    label: 'To review',
                  ),
                  (
                    value: counts['confirmed']?.toString() ?? '-',
                    label: 'Approved',
                  ),
                  (
                    value: counts['declined']?.toString() ?? '-',
                    label: 'Declined',
                  ),
                ],
                artAsset: 'assets/images/hero_tasting.png',
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ExperienceFilterRail(
              selected: _status,
              options: [
                for (final entry in _labels.entries)
                  ExperienceFilterOption(
                    key: entry.key,
                    label: entry.value,
                    count: counts[entry.key],
                  ),
              ],
              onSelected: (key) {
                if (key == null) return;
                setState(() => _status = key);
              },
            ),
          ),
          if (current.hasError)
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.paddingScreen),
              sliver: SliverToBoxAdapter(
                child: ErrorView(
                  error: current.error!,
                  onRetry: () => ref.invalidate(
                    eventRequestsProvider((venue: venueId, status: _status)),
                  ),
                ),
              ),
            )
          else if (!current.hasValue)
            const SliverToBoxAdapter(
              child: LoadingSkeleton(count: 3, itemHeight: 148),
            )
          else if (rows.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.paddingScreen,
                0,
                AppSpacing.paddingScreen,
                AppSpacing.xl,
              ),
              sliver: SliverToBoxAdapter(
                child: ExperienceEmpty(
                  title: _status == 'requested'
                      ? 'Nothing to review'
                      : 'No $_status requests',
                  message: _status == 'requested'
                      ? 'New host proposals for this venue appear here for '
                            'approval.'
                      : 'You have no '
                            '${_status == 'confirmed' ? 'approved' : 'declined'} '
                            'proposals for this venue.',
                  icon: _status == 'requested'
                      ? Icons.pending_actions_outlined
                      : Icons.task_alt,
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
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final request = rows[index];
                  return _RequestCard(
                    request: request,
                    onOpen: () => _openDetail(venueId, request),
                    onApprove: () => _approve(venueId, request),
                    onDecline: () => _decline(venueId, request),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onOpen,
    required this.onApprove,
    required this.onDecline,
  });

  final ExperienceRequest request;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return ExperienceCard(
      key: ValueKey('request-card-${r.id}'),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExperienceArt(
            source: r.coverImage,
            type: r.type,
            overlay: Align(
              alignment: Alignment.topRight,
              child: StatusChip(
                status: r.status.wire,
                label: r.status.label,
                dense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.paddingCard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: AppTextStyles.titleMedium),
                if (r.tagline.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    r.tagline,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                ExperienceHostIdentity(
                  name: r.hostName.isNotEmpty ? r.hostName : r.host.name,
                  handle: r.host.handle,
                  avatarUrl: r.host.avatarUrl,
                  caption: 'Hosting at your venue',
                ),
                const SizedBox(height: AppSpacing.sm),
                ExperienceMetaRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Requested date',
                  value: DisplayDate.dateTime(r.startAt),
                ),
                ExperienceMetaRow(
                  icon: Icons.group_outlined,
                  label: 'Capacity',
                  value: r.capacityLabel,
                ),
                ExperienceMetaRow(
                  icon: Icons.payments_outlined,
                  label: 'Price',
                  // Rupees, like every other amount on the partner surface.
                  value:
                      '${formatMoney(r.pricePerSeat, currency: 'PKR', decimals: 0)}'
                      ' / seat',
                ),
                if (r.changedSinceApproval) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const StatusChip(
                    status: 'pending',
                    label: 'Changed since your last approval',
                    dense: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (r.isAwaitingDecision)
                  RoleGateBuilder(
                    capability: Capability.approveRequests,
                    builder: (context, allowed, denial) => Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton(
                          key: ValueKey('request-decline-${r.id}'),
                          onPressed: allowed ? onDecline : null,
                          child: const Text('Decline'),
                        ),
                        Tooltip(
                          message: allowed ? 'Publish this experience' : denial,
                          child: FilledButton(
                            key: ValueKey('request-approve-${r.id}'),
                            onPressed: allowed ? onApprove : null,
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: ValueKey('request-details-${r.id}'),
                    onPressed: onOpen,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(0, AppSpacing.minTapTarget),
                    ),
                    icon: const Icon(Icons.menu_book_outlined, size: 16),
                    label: const Text('View details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The full proposal, exactly as the diner would see it once published.
///
/// Approving from the list meant saying yes to a title, a date and a price. The
/// venue now gets the menu in running order, the gallery, the audience gate, the
/// inclusions, the dress code and the host's own note, and decides here.
class _RequestDetailSheet extends ConsumerWidget {
  const _RequestDetailSheet({
    required this.venueId,
    required this.summary,
    required this.onDecided,
  });

  final String venueId;
  final ExperienceRequest summary;
  final VoidCallback onDecided;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Approve ${summary.title}?',
      message: 'Publishing makes the experience bookable by guests from '
          '${DisplayDate.day(summary.startAt)}.',
      confirmLabel: 'Approve',
    );
    if (!ok || !context.mounted) return;
    Navigator.of(context).pop();
    try {
      await ref
          .read(experienceRepositoryProvider)
          .approve(venueId, summary.id);
      onDecided();
    } catch (error) {
      if (context.mounted) {
        reportError(context, error, prefix: 'Could not approve:');
      }
    }
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DeclineSheet(request: summary),
    );
    if (reason == null || !context.mounted) return;
    Navigator.of(context).pop();
    try {
      await ref
          .read(experienceRepositoryProvider)
          .decline(venueId, summary.id, reason: reason);
      onDecided();
    } catch (error) {
      if (context.mounted) {
        reportError(context, error, prefix: 'Could not decline:');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      eventRequestDetailProvider((venue: venueId, request: summary.id)),
    );
    final r = detail.valueOrNull ?? summary;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.title, style: AppTextStyles.headlineSmall),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusChip(status: r.status.wire, label: r.status.label),
              ],
            ),
            if (detail.isLoading && detail.valueOrNull == null)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.md),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (r.changedSinceApproval)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: StatusBanner(
                  title: 'Edited after your last decision',
                  message: 'The host changed this experience since you last '
                      'approved it, so it is back in your queue.',
                  icon: Icons.edit_calendar_outlined,
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: MediaImage(
                          source: r.coverImage.trim().isEmpty
                              ? experienceArtAsset(r.type)
                              : r.coverImage,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.dinner_dining_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ExperienceHostIdentity(
                      name: r.hostName.isNotEmpty ? r.hostName : r.host.name,
                      handle: r.host.handle,
                      avatarUrl: r.host.avatarUrl,
                      caption: r.type.label,
                    ),
                    if (r.tagline.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(r.tagline, style: AppTextStyles.bodyMedium),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    ExperienceMetaRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'When',
                      value: DisplayDate.dateTime(r.startAt),
                    ),
                    if (r.durationMinutes > 0)
                      ExperienceMetaRow(
                        icon: Icons.schedule_outlined,
                        label: 'Duration',
                        value: '${r.durationMinutes} minutes',
                      ),
                    ExperienceMetaRow(
                      icon: Icons.group_outlined,
                      label: 'Capacity',
                      value: r.capacityLabel,
                    ),
                    ExperienceMetaRow(
                      icon: Icons.payments_outlined,
                      label: 'Price',
                      value:
                          '${formatMoney(r.pricePerSeat, currency: 'PKR', decimals: 0)}'
                          ' / seat',
                    ),
                    ExperienceMetaRow(
                      icon: Icons.local_dining_outlined,
                      label: 'Format',
                      value: r.type.label,
                    ),
                    if (r.audience.isNotEmpty)
                      ExperienceMetaRow(
                        icon: Icons.visibility_outlined,
                        label: 'Audience',
                        value: _audienceLabel(r.audience),
                      ),
                    if (r.menuStyle.isNotEmpty)
                      ExperienceMetaRow(
                        icon: Icons.restaurant_menu_outlined,
                        label: 'Service',
                        value: menuStyleLabel(r.menuStyle),
                      ),
                    if (r.dressCode.isNotEmpty)
                      ExperienceMetaRow(
                        icon: Icons.checkroom_outlined,
                        label: 'Dress code',
                        value: r.dressCode,
                      ),
                    if (r.language.isNotEmpty)
                      ExperienceMetaRow(
                        icon: Icons.translate_outlined,
                        label: 'Language',
                        value: r.language,
                      ),
                    if (r.description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(r.description, style: AppTextStyles.bodySmall),
                    ],
                    if (r.included.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Included', style: AppTextStyles.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      for (final item in r.included)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(item, style: AppTextStyles.bodySmall),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (r.menu.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Menu', style: AppTextStyles.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      for (final course in r.menu)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      course.name,
                                      style: AppTextStyles.bodyMedium,
                                    ),
                                  ),
                                  if (course.isSignature)
                                    const StatusChip(
                                      status: 'live',
                                      label: 'Signature',
                                      dense: true,
                                    ),
                                ],
                              ),
                              if (course.description.isNotEmpty)
                                Text(
                                  course.description,
                                  style: AppTextStyles.bodySmall,
                                ),
                              if (course.pairing.isNotEmpty)
                                Text(
                                  'Pairing: ${course.pairing}',
                                  style: AppTextStyles.bodySmall,
                                ),
                            ],
                          ),
                        ),
                    ] else if (!detail.isLoading) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const DisabledTile(
                        title: 'No menu listed',
                        reason: 'The host has not added courses to this '
                            'experience, so there is nothing more to read.',
                        icon: Icons.restaurant_menu_outlined,
                      ),
                    ],
                    if (r.gallery.length > 1) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Photos', style: AppTextStyles.titleSmall),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        height: 96,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final shot in r.gallery)
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.sm,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                  child: SizedBox(
                                    width: 128,
                                    child: MediaImage(
                                      source: shot,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (r.hostNote.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text('Note from the host', style: AppTextStyles.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text(r.hostNote, style: AppTextStyles.bodySmall),
                    ],
                    if (r.declineReason.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      ExperienceMetaRow(
                        icon: Icons.block,
                        label: 'Declined',
                        value: r.declineReason,
                        tone: AppColors.danger,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (r.isAwaitingDecision) ...[
              const SizedBox(height: AppSpacing.md),
              RoleGateBuilder(
                capability: Capability.approveRequests,
                builder: (context, allowed, denial) => Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: allowed ? () => _decline(context, ref) : null,
                      child: const Text('Decline'),
                    ),
                    Tooltip(
                      message: allowed ? 'Publish this experience' : denial,
                      child: FilledButton(
                        onPressed: allowed ? () => _approve(context, ref) : null,
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

/// The audience gate in desk words, mirroring the customer app's labels.
String _audienceLabel(String wire) => switch (wire) {
  'public' => 'Open to everyone',
  'friends' => 'Friends of the host',
  'followers' => 'The host\'s followers',
  'inviteOnly' => 'Invite only',
  _ => wire,
};

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
