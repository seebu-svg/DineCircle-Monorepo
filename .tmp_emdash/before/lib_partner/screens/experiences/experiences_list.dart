import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/experience.dart';
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
import '../../widgets/data_widgets.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

/// Experiences this account operates (`GET /partner/events`).
///
/// Account-wide, so the list spans every venue and labels itself as such. The
/// lifecycle is driven by `status` — there is no delete route — and editing is a
/// partial write, so only the keys the operator touched are sent (an empty body
/// is a `400`). Seat counters stay read-only: they move when guests book.
class ExperiencesScreen extends ConsumerStatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  ConsumerState<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends ConsumerState<ExperiencesScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final experiences = ref.watch(experiencesProvider(_status));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.md,
            AppSpacing.paddingScreen,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in const {
                            null: 'All',
                            'confirmed': 'Confirmed',
                            'live': 'Live',
                            'completed': 'Past',
                            'draft': 'Drafts',
                          }.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: _status == entry.key,
                            onSelected: (_) =>
                                setState(() => _status = entry.key),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              RoleGateBuilder(
                capability: Capability.createExperiences,
                builder: (context, allowed, _) => IconButton(
                  tooltip: 'New experience',
                  onPressed: allowed ? () => _openForm(context, null) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<PartnerExperience>>(
            value: experiences,
            onRetry: () => ref.invalidate(experiencesProvider(_status)),
            emptyState: EmptyState(
              title: 'No experiences',
              message: 'Create a dinner, tasting or workshop to start selling '
                  'seats.',
              icon: Icons.auto_awesome_outlined,
              action: RoleGateBuilder(
                capability: Capability.createExperiences,
                builder: (context, allowed, _) => FilledButton.icon(
                  onPressed: allowed ? () => _openForm(context, null) : null,
                  icon: const Icon(Icons.add),
                  label: const Text('New experience'),
                ),
              ),
            ),
            builder: (context, rows) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(experiencesProvider(_status)),
              child: TileList(
                children: [
                  for (final e in rows)
                    _ExperienceTile(
                      experience: e,
                      onTap: () => _openForm(context, e),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openForm(BuildContext context, PartnerExperience? e) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExperienceFormSheet(experience: e),
    );
    if (saved == true) ref.invalidate(experiencesProvider(_status));
  }
}

class _ExperienceTile extends StatelessWidget {
  const _ExperienceTile({required this.experience, required this.onTap});

  final PartnerExperience experience;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = experience;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(e.title, style: AppTextStyles.titleMedium),
                  ),
                  StatusChip(status: e.status.wire, label: e.status.label),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${e.type.label} · ${e.restaurantName}',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              InfoRow(label: 'When', value: DisplayDate.dateTime(e.startAt)),
              InfoRow(
                label: 'Fill',
                value: '${e.seatsBooked} / ${e.seatsTotal} seats',
              ),
              InfoRow(
                label: 'Price',
                value: '${formatMoney(e.pricePerSeat)} / seat',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  late final TextEditingController _seats;
  late final TextEditingController _price;
  late DateTime _start;
  late DateTime _end;
  ExperienceStatus _status = ExperienceStatus.draft;

  bool get _isEdit => widget.experience != null;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.experience;
    _title = TextEditingController(text: e?.title ?? '');
    _seats = TextEditingController(text: '${e?.seatsTotal ?? 12}');
    _price = TextEditingController(
      text: (e?.pricePerSeat ?? 60).toStringAsFixed(2),
    );
    _start = e?.startAt ?? DateTime.now().add(const Duration(days: 7));
    _end = _start.add(const Duration(hours: 3));
    _status = e?.status ?? ExperienceStatus.draft;
  }

  @override
  void dispose() {
    _title.dispose();
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
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
        if (_title.text.trim() != e.title) changes['title'] = _title.text.trim();
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
        if (_status != e.status) changes['status'] = _status.wire;
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
            startAt: _start,
            endAt: _end,
            seatsTotal: seats,
            pricePerSeat: price,
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
              Text(
                _isEdit ? 'Edit experience' : 'New experience',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title *'),
                validator: (v) =>
                    Validators.text(v, field: 'Title', min: 2, max: 160),
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Price per seat *'),
                validator: (v) => Validators.money(
                  v,
                  field: 'Price',
                  max: Validators.pricePerSeatMax.toDouble(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<ExperienceStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final s in ExperienceStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(
                  () => _status = v ?? ExperienceStatus.draft,
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
