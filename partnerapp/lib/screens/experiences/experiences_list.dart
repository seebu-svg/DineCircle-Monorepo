import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/experience.dart';
import '../../navigation/app_routes.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../repositories/experience_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../utils/money.dart';
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/image_upload_field.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';
import 'experiences_widgets.dart';

/// Experiences this account operates (`GET /partner/events`).
///
/// Account-wide, so the list spans every venue and labels itself as such. The
/// lifecycle is driven by the three transition routes — `cancel`, `complete`,
/// `reopen` — and never by writing `status` on the edit endpoint, which the
/// server rejects with a `400` precisely so a dropdown cannot take an experience
/// past a step the host or the approval gate owns. Editing is a partial write, so
/// only the keys the operator touched are sent (an empty body is a `400`). Seat
/// counters stay read-only: they move when guests book.
///
/// One read feeds the whole screen; the rail filters it locally so the counts
/// behind every chip are measured and switching chips is instant.
class ExperiencesScreen extends ConsumerStatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  ConsumerState<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends ConsumerState<ExperiencesScreen> {
  /// `null` is every status; the rest are wire values.
  String? _status;
  bool _autoCreateHandled = false;

  /// The four filters the product promises, plus drafts because a draft is the
  /// only experience a venue can attach to a proposal and it must stay visible.
  static const _filters = <String?, String>{
    null: 'All',
    'confirmed': 'Confirmed',
    'live': 'Live',
    'completed': 'Past',
    'draft': 'Drafts',
  };

  @override
  void initState() {
    super.initState();
    // `/experiences?tab=experiences&create=1` (the Home "Create Experience"
    // tile) opens the creation form straight away. The rules stay here: an
    // unverified venue or a role that may not create experiences leaves the
    // operator on the list rather than in a form that cannot be submitted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenCreateForm());
  }

  void _maybeOpenCreateForm() {
    if (_autoCreateHandled || !mounted) return;
    if (routeQuery(context)['create'] != '1') return;
    _autoCreateHandled = true;
    final venue = ref.read(selectedVenueProvider);
    if (venue == null || !venue.verified) return;
    if (!ref.read(roleGateProvider).can(Capability.createExperiences)) return;
    _openForm(context, null);
  }

  List<PartnerExperience> _visible(List<PartnerExperience> all) {
    final status = _status;
    if (status == null) return all;
    return all
        .where((row) => row.status.wire == status)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final experiences = ref.watch(experiencesProvider(null));
    final venue = ref.watch(selectedVenueProvider);
    final rows = experiences.valueOrNull ?? const <PartnerExperience>[];
    final visible = _visible(rows);

    int? countOf(String? status) => experiences.hasError
        ? null
        : rows.where((row) => status == null || row.status.wire == status).length;

    final live = countOf('live') ?? 0;
    final upcoming = rows
        .where(
          (row) =>
              row.status == ExperienceStatus.confirmed && !row.isPast,
        )
        .length;

    // Header, rail and book share one scroll view. A pinned photo header plus a
    // bounded list left the cards no room at all on a 320dp phone at 2x text,
    // and an experience desk is read by scrolling, not by paging a window.
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(experiencesProvider(null)),
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
                subtitle: experiences.hasError
                    ? 'The experiences this account operates.'
                    : rows.isEmpty
                    ? 'Host a dinner, tasting or workshop and sell seats at '
                          'your table.'
                    : '$upcoming confirmed ahead · $live live now · '
                          '${rows.length} in total across your venues.',
                metrics: [
                  (value: countOf(null)?.toString() ?? '-', label: 'Total'),
                  (
                    value: countOf('confirmed')?.toString() ?? '-',
                    label: 'Confirmed',
                  ),
                  (value: live.toString(), label: 'Live'),
                ],
                artAsset: 'assets/images/dish_steak.png',
                action: RoleGateBuilder(
                  capability: Capability.createExperiences,
                  builder: (context, allowed, denial) => Tooltip(
                    message: denial ?? 'Publish a new dining experience',
                    child: FilledButton.icon(
                      key: const ValueKey('experience-create'),
                      onPressed: allowed ? () => _openForm(context, null) : null,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Create experience'),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ExperienceFilterRail(
              selected: _status,
              options: [
                for (final entry in _filters.entries)
                  ExperienceFilterOption(
                    key: entry.key,
                    label: entry.value,
                    count: countOf(entry.key),
                  ),
              ],
              onSelected: (key) => setState(() => _status = key),
            ),
          ),
          if (experiences.hasError)
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.paddingScreen),
              sliver: SliverToBoxAdapter(
                child: ErrorView(
                  error: experiences.error!,
                  onRetry: () => ref.invalidate(experiencesProvider(null)),
                ),
              ),
            )
          else if (!experiences.hasValue)
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
                child: rows.isEmpty
                    ? ExperienceEmpty(
                        title: 'No experiences yet',
                        message:
                            'Create a dinner, tasting or workshop to start '
                            'selling seats at your table.',
                        action: RoleGateBuilder(
                          capability: Capability.createExperiences,
                          builder: (context, allowed, denial) => Tooltip(
                            message: denial ?? 'Publish a new dining experience',
                            child: FilledButton.icon(
                              onPressed: allowed
                                  ? () => _openForm(context, null)
                                  : null,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create experience'),
                            ),
                          ),
                        ),
                      )
                    : ExperienceEmpty(
                        title: 'Nothing in ${_filters[_status]}',
                        message: _status == 'draft'
                            ? 'Drafts are experiences you have not published '
                                  'yet. They can be attached to a proposal '
                                  'from Find a host.'
                            : 'No experience is in this state right now. '
                                  'Switch to All to see the whole book.',
                        icon: Icons.event_note_outlined,
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
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final experience = visible[index];
                  return _ExperienceCard(
                    experience: experience,
                    onManage: () => _openForm(context, experience),
                    onAction: (kind) => _onAction(experience, kind),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, PartnerExperience? e) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExperienceFormSheet(experience: e),
    );
    if (saved == true) ref.invalidate(experiencesProvider(null));
  }

  /// Runs one lifecycle transition and refreshes the account-wide read, because
  /// a transition moves the row out of the filter the operator is standing on.
  Future<void> _transition(
    PartnerExperience e, {
    required String title,
    required String message,
    required String confirmLabel,
    required String doneLabel,
    required bool destructive,
    required Future<ExperienceTransition> Function(ExperienceRepository repo)
    action,
  }) async {
    final ok = await confirmAction(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    );
    if (!ok) return;
    if (!mounted) return;
    try {
      await action(ref.read(experienceRepositoryProvider));
      if (!mounted) return;
      ref.invalidate(experiencesProvider(null));
      showToast(context, doneLabel);
    } catch (error) {
      if (!mounted) return;
      reportError(context, error, prefix: 'Could not update the experience:');
    }
  }

  /// Soft cancel keeps the row, the guests and the money trail; the only thing
  /// lost is publication, so the reason is captured for the host and the diners.
  Future<void> _cancel(PartnerExperience e) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CancelReasonSheet(experience: e),
    );
    if (reason == null || !mounted) return;
    await _transition(
      e,
      title: 'Cancel ${e.title}?',
      message: 'The experience is delisted and cannot be booked. Guests who '
          'hold a seat are told it was cancelled by the venue.',
      confirmLabel: 'Cancel experience',
      doneLabel: '${e.title} cancelled',
      destructive: true,
      action: (repo) => repo.cancelEvent(e.id, reason: reason),
    );
  }

  void _onAction(PartnerExperience e, ExperienceActionKind kind) {
    switch (kind) {
      case ExperienceActionKind.cancel:
        _cancel(e);
      case ExperienceActionKind.complete:
        _transition(
          e,
          title: 'Mark ${e.title} complete?',
          message: 'Completing closes the experience for bookings and moves it '
              'into past events. It can be reopened afterwards.',
          confirmLabel: 'Complete',
          doneLabel: '${e.title} completed',
          destructive: false,
          action: (repo) => repo.completeEvent(e.id),
        );
      case ExperienceActionKind.reopen:
        _transition(
          e,
          title: 'Reopen ${e.title}?',
          message: 'Reopening puts the experience back to confirmed so seats '
              'can be booked again.',
          confirmLabel: 'Reopen',
          doneLabel: '${e.title} reopened',
          destructive: false,
          action: (repo) => repo.reopenEvent(e.id),
        );
    }
  }
}

/// The lifecycle actions the server will actually accept for this status: cancel
/// from anything not already cancelled, complete only from confirmed or live,
/// reopen only from completed.
enum ExperienceActionKind { cancel, complete, reopen }

List<({ExperienceActionKind kind, String label})> transitionOptions(
  ExperienceStatus status,
) => switch (status) {
  ExperienceStatus.draft || ExperienceStatus.requested => [
    (kind: ExperienceActionKind.cancel, label: 'Cancel experience'),
  ],
  ExperienceStatus.confirmed || ExperienceStatus.live => [
    (kind: ExperienceActionKind.complete, label: 'Mark complete'),
    (kind: ExperienceActionKind.cancel, label: 'Cancel experience'),
  ],
  ExperienceStatus.completed => [
    (kind: ExperienceActionKind.reopen, label: 'Reopen for bookings'),
  ],
  ExperienceStatus.cancelled || ExperienceStatus.declined => const [],
};

class _CancelReasonSheet extends StatefulWidget {
  const _CancelReasonSheet({required this.experience});

  final PartnerExperience experience;

  @override
  State<_CancelReasonSheet> createState() => _CancelReasonSheetState();
}

class _CancelReasonSheetState extends State<_CancelReasonSheet> {
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
          Text('Cancel ${widget.experience.title}',
              style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The reason is sent to the host and to every guest holding a seat. '
            'It is optional, but it is the only explanation they will get.',
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
              hintText: 'Kitchen maintenance, double booking, staff shortage…',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_controller.text.trim()),
            child: const Text('Cancel experience'),
          ),
        ],
      ),
    );
  }
}

/// The lifecycle menu on an experience card.
///
/// Gated on `approveRequests`, because moving an experience through its lifecycle
/// is the same authority that decides an incoming request. When the caller lacks
/// it the menu is shown disabled rather than hidden, so the operator can tell a
/// permission gap from a missing feature.
class _TransitionMenu extends StatelessWidget {
  const _TransitionMenu({required this.experience, required this.onAction});

  final PartnerExperience experience;
  final ValueChanged<ExperienceActionKind> onAction;

  @override
  Widget build(BuildContext context) {
    final options = transitionOptions(experience.status);
    if (options.isEmpty) return const SizedBox.shrink();
    return RoleGateBuilder(
      capability: Capability.approveRequests,
      builder: (context, allowed, denial) => PopupMenuButton<
        ({ExperienceActionKind kind, String label})
      >(
        enabled: allowed,
        tooltip: denial ?? 'Lifecycle',
        icon: const Icon(Icons.more_horiz, size: 20),
        onSelected: (option) => onAction(option.kind),
        itemBuilder: (context) => [
          for (final option in options)
            PopupMenuItem(
              value: option,
              child: Text(
                option.label,
                style: option.kind == ExperienceActionKind.cancel
                    ? AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.danger,
                      )
                    : AppTextStyles.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.experience,
    required this.onManage,
    required this.onAction,
  });

  final PartnerExperience experience;
  final VoidCallback onManage;
  final ValueChanged<ExperienceActionKind> onAction;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return ExperienceCard(
      key: ValueKey('experience-card-${e.id}'),
      onTap: onManage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExperienceArt(
            source: e.coverImage,
            type: e.type,
            height: 128,
            overlay: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusChip(
                  status: e.status.wire,
                  label: e.status.label,
                  dense: true,
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bg.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(
                        color: AppColors.borderLight.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      e.type.label,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.paddingCard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(e.title, style: AppTextStyles.titleMedium),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _TransitionMenu(experience: e, onAction: onAction),
                  ],
                ),
                Text(
                  e.restaurantName.trim().isEmpty
                      ? 'Your venue'
                      : e.restaurantName,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                ExperienceMetaRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'When',
                  value: DisplayDate.dateTime(e.startAt),
                ),
                ExperienceMetaRow(
                  icon: Icons.payments_outlined,
                  label: 'Price',
                  // PKR is the only trading currency on the partner surface (see
                  // utils/money.dart); the default formatter would have labelled
                  // a rupee price in dollars.
                  value:
                      '${formatMoney(e.pricePerSeat, currency: 'PKR', decimals: 0)}'
                      ' / seat',
                ),
                const SizedBox(height: AppSpacing.sm),
                ExperienceFillBar(booked: e.seatsBooked, total: e.seatsTotal),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: ValueKey('experience-manage-${e.id}'),
                    onPressed: onManage,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(0, AppSpacing.minTapTarget),
                    ),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Manage'),
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

/// Create or edit an experience.
///
/// The server accepts a format, a tagline and a cover photo on both routes and
/// the venue previously could not set any of them from the app. The cover is
/// uploaded through the same venue-image pipeline the menu and deals use, so a
/// card can eventually show the event's own photograph instead of the format's.
class _ExperienceFormSheet extends ConsumerStatefulWidget {
  const _ExperienceFormSheet({this.experience});

  final PartnerExperience? experience;

  @override
  ConsumerState<_ExperienceFormSheet> createState() =>
      _ExperienceFormSheetState();
}

class _ExperienceFormSheetState extends ConsumerState<_ExperienceFormSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _tagline;
  late final TextEditingController _seats;
  late final TextEditingController _price;
  late DateTime _start;
  late DateTime _end;
  late ExperienceType _type;
  late String _cover;

  bool get _isEdit => widget.experience != null;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.experience;
    _title = TextEditingController(text: e?.title ?? '');
    _tagline = TextEditingController(text: e?.tagline ?? '');
    _seats = TextEditingController(text: '${e?.seatsTotal ?? 12}');
    _price = TextEditingController(
      text: (e?.pricePerSeat ?? 60).toStringAsFixed(2),
    );
    _start = e?.startAt ?? DateTime.now().add(const Duration(days: 7));
    _end = _start.add(const Duration(hours: 3));
    _type = e?.type ?? ExperienceType.dinner;
    _cover = e?.coverImage ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _tagline.dispose();
    _seats.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final base = start ? _start : _end;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _start = picked;
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 3));
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(experienceRepositoryProvider);
    final seats = int.tryParse(_seats.text.trim()) ?? 0;
    final price = double.tryParse(_price.text.trim().replaceAll(',', '')) ?? 0;
    try {
      if (_isEdit) {
        final e = widget.experience!;
        final changes = <String, dynamic>{};
        if (_title.text.trim() != e.title) {
          changes['title'] = _title.text.trim();
        }
        if (_tagline.text.trim() != e.tagline) {
          changes['tagline'] = _tagline.text.trim();
        }
        if (_type != e.type) changes['type'] = _type.wire;
        if (_cover != e.coverImage) changes['coverImage'] = _cover;
        if (seats != e.seatsTotal) changes['seatsTotal'] = seats;
        if ((price - e.pricePerSeat).abs() > 0.001) {
          changes['pricePerSeat'] = price;
        }
        if (!_start.toUtc().toIso8601String().contains(
          e.startAt.toUtc().toIso8601String().substring(0, 16),
        )) {
          changes['startAt'] = _start.toUtc().toIso8601String();
          changes['endAt'] = _end.toUtc().toIso8601String();
        }
        // `status` is deliberately not sent. The server answers a status write
        // on this route with a 400; the lifecycle lives in the transition
        // routes, which are the only path that runs the guards.
        if (changes.isEmpty) {
          if (mounted) Navigator.of(context).pop(false);
          return;
        }
        await repo.updateExperience(e.id, changes);
      } else {
        final venueId = ref.read(selectedVenueIdProvider);
        await repo.createExperience(
          ExperienceInput(
            restaurantId: venueId,
            title: _title.text,
            tagline: _tagline.text,
            startAt: _start,
            endAt: _end,
            seatsTotal: seats,
            pricePerSeat: price,
            type: _type.wire,
            coverImage: _cover,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not save:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // A venue-owned row can belong to another venue on a multi-venue account;
    // the upload has to land on the venue that owns the experience.
    final owningVenue = widget.experience?.restaurantId.trim() ?? '';
    final venueId = owningVenue.isNotEmpty
        ? owningVenue
        : ref.read(selectedVenueIdProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEdit ? 'Edit experience' : 'New experience',
                      style: AppTextStyles.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _isEdit
                    ? 'Only the fields you change are sent. Guests who hold a '
                          'seat are told about any timing change.'
                    : 'This publishes to your venue immediately. Hosts and '
                          'guests can book seats as soon as it is confirmed.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              ImageUploadField(
                venueId: venueId,
                label: 'Cover photo',
                value: _cover,
                kind: 'gallery',
                enabled: !_busy,
                helperText: 'Shown on the experience card and to guests.',
                onChanged: (value) => setState(() => _cover = value),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title *'),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    Validators.text(v, field: 'Title', min: 3, max: 120),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _tagline,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tagline',
                  hintText: 'One line the guest sees first',
                ),
              ),
              Text('Format', style: AppTextStyles.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final type in ExperienceType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _type == type,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start',
                      value: _start,
                      onTap: () => _pick(start: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _DateField(
                      label: 'End',
                      value: _end,
                      onTap: () => _pick(start: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _seats,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Seats total *'),
                validator: (v) => Validators.integer(
                  v,
                  field: 'Seats',
                  min: 1,
                  max: Validators.eventSeatsMax,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price per seat *',
                ),
                validator: (v) => Validators.money(
                  v,
                  field: 'Price',
                  max: Validators.pricePerSeatMax.toDouble(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Create experience'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time, size: 18),
        ),
        child: Text(
          DisplayDate.dateTime(value),
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
