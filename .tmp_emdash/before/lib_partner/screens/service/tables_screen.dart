import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalog.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/data_widgets.dart';
import '../../widgets/premium_cards.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

/// Floor plan and how it books out (`…/tables` + `…/availability`).
///
/// Tables define the venue's capacity, so the two halves belong on one screen:
/// the roster you edit, and the slot grid that shows whether those tables can
/// actually take a party on a given day. Editing is manager-gated; the
/// availability read is open to every role so a host can see why a slot is dark.
class TablesScreen extends ConsumerStatefulWidget {
  const TablesScreen({super.key});

  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  DateTime _day = ServiceDate.startOfDay(DateTime.now());
  int _partySize = 2;

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    final tables = ref.watch(tablesProvider(venueId));
    final availability = ref.watch(availabilityProvider((
      venue: venueId,
      date: ServiceDate.key(_day),
      partySize: _partySize,
    )));

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        SectionHeader(
          title: 'Tables',
          subtitle: 'Capacity is the sum of the active tables\' seats.',
          topSpacing: AppSpacing.md,
          trailing: RoleGateBuilder(
            capability: Capability.manageTables,
            builder: (context, allowed, _) => TextButton.icon(
              onPressed: allowed
                  ? () => _openEditor(context, venueId, null)
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('New table'),
            ),
          ),
        ),
        tables.when(
          loading: () => const LoadingSkeleton(count: 3),
          error: (e, _) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(tablesProvider(venueId)),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: DisabledTile(
                  title: 'No tables yet',
                  reason: 'Add a table so guests can book a specific spot '
                      'rather than just a party size.',
                  icon: Icons.table_restaurant_outlined,
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingScreen,
              ),
              child: PremiumCard(
                padding: 0,
                child: Column(
                  children: [
                    for (final table in rows)
                      _TableRow(
                        table: table,
                        onEdit: () => _openEditor(context, venueId, table),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        SectionHeader(
          title: 'Availability',
          subtitle: 'How the floor books out for a party of $_partySize.',
          trailing: TextButton.icon(
            onPressed: () async {
              final size = await _askPartySize(context);
              if (size != null) setState(() => _partySize = size);
            },
            icon: const Icon(Icons.groups, size: 18),
            label: Text('Party $_partySize'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final offset in List.generate(7, (i) => i))
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(
                        DisplayDate.day(ServiceDate.addDays(_day, offset)),
                      ),
                      selected: offset == 0,
                      onSelected: (_) => setState(
                        () => _day = ServiceDate.addDays(_day, offset),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingScreen),
          child: availability.when(
            loading: () => const LoadingSkeleton(count: 4),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(availabilityProvider((
                venue: venueId,
                date: ServiceDate.key(_day),
                partySize: _partySize,
              ))),
            ),
            data: (data) => _AvailabilityPanel(data: data),
          ),
        ),
      ],
    );
  }

  Future<int?> _askPartySize(BuildContext context) async {
    final controller = TextEditingController(text: '$_partySize');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Party size'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Guests'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.of(context).pop(
                value == null || value < 1 ? null : value.clamp(1, 200),
              );
            },
            child: const Text('Show'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openEditor(
    BuildContext context,
    String venueId,
    DiningTable? table,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TableEditorSheet(venueId: venueId, table: table),
    );
    if (saved == true) ref.invalidate(tablesProvider(venueId));
  }
}

class _TableRow extends ConsumerWidget {
  const _TableRow({required this.table, required this.onEdit});

  final DiningTable table;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: onEdit,
      title: Text(table.label, style: AppTextStyles.bodyLarge),
      subtitle: Text(
        '${table.seatLabel} · ${table.zoneLabel}',
        style: AppTextStyles.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusChip(
            status: table.isActive ? 'active' : 'cancelled',
            label: table.isActive ? 'Active' : 'Retired',
            dense: true,
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _AvailabilityPanel extends StatelessWidget {
  const _AvailabilityPanel({required this.data});

  final DayAvailability data;

  @override
  Widget build(BuildContext context) {
    if (!data.configuredHours) {
      return const DisabledTile(
        title: 'Opening hours not set',
        reason: 'No slots can open until the venue\'s weekly hours are '
            'configured in Business → Branches.',
        icon: Icons.schedule,
      );
    }
    if (data.slots.isEmpty) {
      return const DisabledTile(
        title: 'Closed on this date',
        reason: 'The venue has no trading window for this day.',
        icon: Icons.do_not_disturb_on_outlined,
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${data.bookableCount} of ${data.slots.length} slots open · '
                'capacity ${data.capacity}',
                style: AppTextStyles.bodySmall,
              ),
            ),
            UpdatedCaption(at: null),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final slot in data.slots)
          PremiumCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: 0,
            child: ListTile(
              dense: true,
              leading: Icon(
                slot.available ? Icons.check_circle : Icons.remove_circle,
                color: slot.available
                    ? AppColors.success
                    : AppColors.textTertiary,
              ),
              title: Text(
                DisplayDate.timeRange(slot.startAt, slot.endAt),
                style: AppTextStyles.bodyMedium,
              ),
              trailing: Text(
                slot.available ? '${slot.seatsLeft} left' : 'Full',
                style: AppTextStyles.labelMedium.copyWith(
                  color: slot.available
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Create or edit one table.
class _TableEditorSheet extends ConsumerStatefulWidget {
  const _TableEditorSheet({required this.venueId, this.table});

  final String venueId;
  final DiningTable? table;

  @override
  ConsumerState<_TableEditorSheet> createState() => _TableEditorSheetState();
}

class _TableEditorSheetState extends ConsumerState<_TableEditorSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _seats;
  late final TextEditingController _zone;
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final t = widget.table;
    _label = TextEditingController(text: t?.label ?? '');
    _seats = TextEditingController(text: '${t?.seats ?? 2}');
    _zone = TextEditingController(text: t?.zone ?? '');
    _active = t?.isActive ?? true;
  }

  @override
  void dispose() {
    _label.dispose();
    _seats.dispose();
    _zone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ops = ref.read(operationsRepositoryProvider);
    final seats = int.tryParse(_seats.text.trim()) ?? 2;
    try {
      final table = widget.table;
      if (table == null) {
        await ops.createTable(
          widget.venueId,
          label: _label.text,
          seats: seats,
          zone: _zone.text,
          isActive: _active,
        );
      } else {
        await ops.updateTable(
          widget.venueId,
          table.id,
          label: _label.text,
          seats: seats,
          zone: _zone.text,
          isActive: _active,
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

  Future<void> _delete() async {
    final table = widget.table;
    if (table == null) return;
    final ok = await confirmAction(
      context,
      title: 'Retire ${table.label}?',
      message: 'A retired table stops taking bookings but stays on record '
          'for past reservations.',
      confirmLabel: 'Retire table',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(operationsRepositoryProvider)
          .deleteTable(widget.venueId, table.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not retire:');
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.table == null ? 'New table' : 'Edit ${widget.table!.label}',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label *'),
              validator: (v) =>
                  Validators.text(v, field: 'Label', min: 1, max: 60),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _seats,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Seats *'),
              validator: (v) =>
                  Validators.integer(v, field: 'Seats', min: 1, max: 100),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _zone,
              decoration: const InputDecoration(
                labelText: 'Zone',
                hintText: 'Terrace, bar, private room…',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save table'),
            ),
            if (widget.table != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _busy ? null : _delete,
                child: const Text('Retire this table'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
