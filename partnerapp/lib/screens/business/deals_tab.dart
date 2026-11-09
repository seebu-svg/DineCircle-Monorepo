import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/deals.dart';
import '../../navigation/app_routes.dart';
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
import '../../widgets/premium_cards.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

/// Venue promotions (`…/deals`), driven entirely by the transition map.
///
/// Create is disabled with a reason while the venue is unverified, the server
/// answers `403` regardless of the local role, so the gate is the `verified`
/// flag rather than [Capability.manageDeals] alone. Lifecycle buttons come from
/// [Deal.allowedTransitions], so the desk never taps a move that would return
/// `409`; delete means "drop the draft", anything live is retired to `expired`.
class DealsTab extends ConsumerStatefulWidget {
  const DealsTab({super.key});

  @override
  ConsumerState<DealsTab> createState() => _DealsTabState();
}

class _DealsTabState extends ConsumerState<DealsTab> {
  String? _status;
  bool _autoCreateHandled = false;

  ({String venue, String? status}) _key(String venueId) =>
      (venue: venueId, status: _status);

  @override
  void initState() {
    super.initState();
    // `/business?tab=deals&create=1` (the Home "Add Deal" tile) opens straight
    // into the creation form. The rules stay here: an unverified venue or a
    // role that may not manage deals keeps the disabled "New Deal" button.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenCreateForm());
  }

  Future<void> _maybeOpenCreateForm() async {
    if (_autoCreateHandled || !mounted) return;
    if (routeQuery(context)['create'] != '1') return;
    _autoCreateHandled = true;
    final venue = ref.read(selectedVenueProvider);
    if (venue == null || !venue.verified) return;
    if (!ref.read(roleGateProvider).can(Capability.manageDeals)) return;
    await _openDealForm(context, venue.id);
  }

  Future<void> _refresh(String venueId) async {
    try {
      ref.invalidate(dealsProvider(_key(venueId)));
      await ref.read(dealsProvider(_key(venueId)).future);
    } catch (error) {
      if (mounted) {
        reportError(context, error, prefix: 'Could not refresh deals:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(selectedVenueProvider);
    final venueId = venue?.id ?? '';
    final deals = ref.watch(dealsProvider(_key(venueId)));
    final canSell = venue?.verified ?? false;
    // Narrow phones get tighter chrome so the card content keeps its room.
    final horizontal = MediaQuery.sizeOf(context).width < 360
        ? AppSpacing.md
        : AppSpacing.paddingScreen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.md,
            horizontal,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deals & Offers',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Create promotions that bring guests back.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: _CreateButton(venueId: venueId, canSell: canSell),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: Row(
            children: [
              for (final entry in const <String?, String>{
                null: 'All',
                'draft': 'Drafts',
                'active': 'Active',
                'paused': 'Paused',
                'expired': 'Expired',
              }.entries)
                _StatusFilterChip(
                  label: entry.value,
                  selected: _status == entry.key,
                  onSelected: () => setState(() => _status = entry.key),
                ),
            ],
          ),
        ),
        if (!canSell)
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.sm,
              horizontal,
              12,
            ),
            child: const StatusBanner(
              title: 'Verification required',
              message:
                  'Venue verification is required to create or publish deals.',
              tone: BannerTone.info,
              icon: Icons.verified_user_outlined,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: AsyncView<List<Deal>>(
            value: deals,
            loading: const SingleChildScrollView(
              child: LoadingSkeleton(count: 3, itemHeight: 120),
            ),
            onRetry: () => ref.invalidate(dealsProvider(_key(venueId))),
            emptyState: RefreshIndicator(
              onRefresh: () => _refresh(venueId),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  EmptyState(
                    title: _status == null
                        ? 'No deals yet'
                        : 'No $_status deals',
                    message: _status == null
                        ? 'Create your first promotion with New Deal.'
                        : 'Choose another filter or create a new deal.',
                    icon: Icons.local_offer_outlined,
                  ),
                ],
              ),
            ),
            builder: (context, rows) => RefreshIndicator(
              onRefresh: () => _refresh(venueId),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.xs,
                  horizontal,
                  AppSpacing.xl,
                ),
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.marginItem),
                itemBuilder: (context, index) {
                  final deal = rows[index];
                  return _DealCard(
                    key: ValueKey(deal.id),
                    venueId: venueId,
                    deal: deal,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The primary action of the screen. It sits under the header rather than
/// floating, so the desk always sees it, and always sees it disabled when
/// the venue may not sell.
class _CreateButton extends ConsumerWidget {
  const _CreateButton({required this.venueId, required this.canSell});

  final String venueId;
  final bool canSell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RoleGateBuilder(
      capability: Capability.manageDeals,
      builder: (context, allowed, _) {
        final enabled = allowed && canSell && venueId.isNotEmpty;
        return FilledButton.icon(
          onPressed: enabled ? () => _openDealForm(context, venueId) : null,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('New Deal'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(148, 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.paddingButton,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
          ),
        );
      },
    );
  }
}

/// One pill in the status row, styled like the Insights range chips so the two
/// screens read as the same control.
class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        labelStyle: AppTextStyles.labelSmall.copyWith(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Opens the creation form. Shared by the "New Deal" button and the Home
/// "Add Deal" tile, so both obey the same role and verification rules.
Future<void> _openDealForm(BuildContext context, String venueId) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _DealFormSheet(venueId: venueId),
  );
  if (saved == true && context.mounted) {
    showToast(context, 'Deal created as draft.');
  }
}

/// Compact promotion summary using server-provided redemption counts.
class _DealCard extends ConsumerStatefulWidget {
  const _DealCard({super.key, required this.venueId, required this.deal});
  final String venueId;
  final Deal deal;
  @override
  ConsumerState<_DealCard> createState() => _DealCardState();
}

class _DealCardState extends ConsumerState<_DealCard> {
  bool _busy = false;

  Future<void> _run({DealStatus? status, bool delete = false}) async {
    if (_busy || !ref.read(roleGateProvider).can(Capability.manageDeals)) {
      return;
    }
    if (delete && !widget.deal.isDeleteable) return;
    if (status == DealStatus.active &&
        (!(ref.read(selectedVenueProvider)?.verified ?? false) ||
            !widget.deal.endsAt.isAfter(DateTime.now()))) {
      return;
    }
    setState(() => _busy = true);
    try {
      if (delete) {
        final ok = await confirmAction(
          context,
          title: 'Delete draft?',
          message: '“${widget.deal.title}” will be permanently removed.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (!ok || !mounted) return;
        await ref
            .read(businessRepositoryProvider)
            .deleteDeal(widget.venueId, widget.deal.id);
      } else {
        if (!widget.deal.allowedTransitions.contains(status)) return;
        await ref
            .read(businessRepositoryProvider)
            .updateDeal(widget.venueId, widget.deal.id, status: status);
      }
      ref.invalidate(dealsProvider);
      if (mounted) {
        showToast(
          context,
          delete ? 'Draft deleted.' : 'Deal ${status!.label.toLowerCase()}.',
        );
      }
    } catch (error) {
      if (mounted) {
        reportError(context, error, prefix: 'Could not update deal:');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) =>
            _DealFormSheet(venueId: widget.venueId, draft: widget.deal),
      );
      if (saved == true && mounted) showToast(context, 'Draft updated.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deal;
    final now = DateTime.now();
    final timing = d.status == DealStatus.expired
        ? 'Retired / expired'
        : d.isDraft
        ? 'Draft · not published'
        : !d.endsAt.isAfter(now)
        ? 'Validity ended'
        : d.status == DealStatus.paused
        ? 'Paused · unavailable to guests'
        : d.startsAt.isAfter(now)
        ? 'Scheduled'
        : 'Available now';
    final value = d.kind.isPercent
        ? '${d.value.toStringAsFixed(2).replaceFirst(RegExp(r"\.?0+$"), "")}% off'
        : '${formatMoney(d.value)}${d.kind == DealKind.package ? " package" : " off"}';
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  d.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              RoleGateBuilder(
                capability: Capability.manageDeals,
                builder: (context, allowed, _) => PopupMenuButton<String>(
                  tooltip: 'Deal actions',
                  icon: const Icon(Icons.more_vert_rounded),
                  enabled:
                      allowed &&
                      !_busy &&
                      (d.isDraft || d.allowedTransitions.isNotEmpty),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _edit();
                    } else if (action == 'delete') {
                      _run(delete: true);
                    } else {
                      _run(status: DealStatus.parse(action));
                    }
                  },
                  itemBuilder: (_) => [
                    if (d.isDraft)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit draft'),
                      ),
                    for (final to in d.allowedTransitions)
                      PopupMenuItem(
                        value: to.wire,
                        enabled:
                            to != DealStatus.active ||
                            ((ref.read(selectedVenueProvider)?.verified ??
                                    false) &&
                                d.endsAt.isAfter(now)),
                        child: Text(
                          to == DealStatus.expired
                              ? 'Retire deal'
                              : to == DealStatus.paused
                              ? 'Pause deal'
                              : d.status == DealStatus.paused
                              ? 'Resume deal'
                              : 'Publish deal',
                        ),
                      ),
                    if (d.isDeleteable)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete draft'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(status: d.status.wire, label: d.status.label),
              Text(
                d.redemptionLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${_dealDate(d.startsAt)} – ${_dealDate(d.endsAt)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                _busy ? Icons.sync_rounded : Icons.circle_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _busy ? 'Updating…' : timing,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _dealDate(DateTime date) {
  final local = date.toLocal();
  return '${DisplayDate.monthDay(local)}, ${local.year}';
}

/// Create and edit drafts using the existing repository contract.
class _DealFormSheet extends ConsumerStatefulWidget {
  const _DealFormSheet({required this.venueId, this.draft});

  final Deal? draft;

  final String venueId;

  @override
  ConsumerState<_DealFormSheet> createState() => _DealFormSheetState();
}

class _DealFormSheetState extends ConsumerState<_DealFormSheet> {
  final _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _maxRedemptions = TextEditingController();
  DealKind _kind = DealKind.percent;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    if (d != null) {
      _title.text = d.title;
      _description.text = d.description;
      _value.text = d.value.toString();
      _code.text = d.code ?? '';
      _maxRedemptions.text = d.maxRedemptions?.toString() ?? '';
      _kind = d.kind;
      _startsAt = d.startsAt.toLocal();
      _endsAt = d.endsAt.toLocal();
    } else {
      final now = DateTime.now();
      _startsAt = DateTime(now.year, now.month, now.day);
      _endsAt = DateTime(now.year, now.month, now.day + 7, 23, 59, 59, 999);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _value, _code, _maxRedemptions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    if (_busy) return;
    final now = DateUtils.dateOnly(DateTime.now());
    final current = DateUtils.dateOnly((start ? _startsAt : _endsAt) ?? now);
    final first = current.isBefore(now) ? current : now;
    final last = DateTime(now.year + 5, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: current.isAfter(last) ? current : last,
      initialDate: current,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startsAt = picked;
        if (_endsAt == null || !_endsAt!.isAfter(picked)) {
          _endsAt = DateTime(
            picked.year,
            picked.month,
            picked.day + 7,
            23,
            59,
            59,
            999,
          );
        }
      } else {
        _endsAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
          999,
        );
      }
    });
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final gate = ref.read(roleGateProvider);
    if (!gate.can(Capability.manageDeals) ||
        (widget.draft == null &&
            !(ref.read(selectedVenueProvider)?.verified ?? false))) {
      showToast(
        context,
        'Deal management is not available for this account.',
        isError: true,
      );
      return;
    }
    final rangeError = Validators.orderedRange(_startsAt, _endsAt);
    if (rangeError != null) {
      showToast(context, rangeError, isError: true);
      return;
    }
    setState(() => _busy = true);
    final max = _maxRedemptions.text.trim();
    try {
      FocusScope.of(context).unfocus();
      final input = DealDraftInput(
        title: _title.text,
        kind: _kind,
        value: double.parse(_value.text.trim().replaceAll(',', '')),
        startsAt: _startsAt!,
        endsAt: _endsAt!,
        description: _description.text,
        code: _code.text,
        maxRedemptions: max.isEmpty ? null : int.parse(max),
      );
      final repository = ref.read(businessRepositoryProvider);
      if (widget.draft == null) {
        await repository.createDeal(widget.venueId, input);
      } else {
        await repository.updateDeal(
          widget.venueId,
          widget.draft!.id,
          title: input.title,
          description: input.description,
          kind: input.kind,
          value: input.value,
          code: input.code,
          startsAt: input.startsAt,
          endsAt: input.endsAt,
          maxRedemptions: input.maxRedemptions,
        );
      }
      ref.invalidate(dealsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not save deal:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        // The keyboard pushes the sheet up; the fields scroll inside it and
        // the save button stays pinned above the keyboard.
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92 -
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.sizeOf(context).width < 360
                    ? AppSpacing.md
                    : AppSpacing.lg,
                AppSpacing.md,
                MediaQuery.sizeOf(context).width < 360
                    ? AppSpacing.md
                    : AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.draft == null ? 'New deal' : 'Edit draft',
                            style: AppTextStyles.headlineSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title *'),
                    validator: (v) =>
                        Validators.text(v, field: 'Title', min: 2, max: 120),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<DealKind>(
                    initialValue: _kind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final k in DealKind.values)
                        DropdownMenuItem(value: k, child: Text(k.label)),
                    ],
                    onChanged: _busy || widget.draft != null
                        ? null
                        : (v) => setState(() => _kind = v ?? _kind),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _kind.isPercent
                          ? 'Percentage off *'
                          : _kind == DealKind.package
                          ? 'Package price *'
                          : 'Amount off *',
                    ),
                    validator: (v) {
                      final n = double.tryParse(
                        (v ?? '').trim().replaceAll(',', ''),
                      );
                      if (n == null || !n.isFinite || n <= 0) {
                        return 'Enter a positive number';
                      }
                      if (_kind.isPercent && n > 100) {
                        return 'Percentage cannot exceed 100';
                      }
                      if (n > 100000) return 'Amount cannot exceed 100000';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pickDate(true),
                          icon: const Icon(Icons.event),
                          label: Text(
                            _startsAt == null
                                ? 'Starts'
                                : 'Starts: ${_dealDate(_startsAt!)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pickDate(false),
                          icon: const Icon(Icons.event_busy),
                          label: Text(
                            _endsAt == null
                                ? 'Ends'
                                : 'Ends: ${_dealDate(_endsAt!)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Promo code',
                      helperText: 'Optional',
                    ),
                    validator: (v) => Validators.text(
                      v,
                      field: 'Code',
                      max: 24,
                      required: false,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _maxRedemptions,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Max redemptions',
                      helperText: widget.draft?.maxRedemptions == null
                          ? 'Optional; blank means unlimited.'
                          : 'Existing limit can be changed, but not removed.',
                    ),
                    validator: (v) => Validators.integer(
                      v,
                      field: 'Max redemptions',
                      min: 1,
                      required: widget.draft?.maxRedemptions != null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Terms / description',
                    ),
                    validator: (v) => Validators.text(
                      v,
                      field: 'Description',
                      max: 500,
                      required: false,
                    ),
                  ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(
                _busy
                    ? 'Saving…'
                    : widget.draft == null
                    ? 'Create draft'
                    : 'Save draft',
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),
      ),
    );
  }
}
