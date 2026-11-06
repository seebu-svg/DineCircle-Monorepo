import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../repositories/operations_repository.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../utils/validators.dart';
import '../../widgets/role_gate_builder.dart';

/// Takes a booking over the phone and writes it as a confirmed reservation.
///
/// The server defaults a partner-created reservation to `confirmed`, so the desk
/// does not have to confirm its own entry. Table selection is optional — leaving
/// it unset lets the availability engine assign one — and the start is collected
/// as a venue-local instant converted to UTC on the way out.
class PhoneBookingSheet extends ConsumerStatefulWidget {
  const PhoneBookingSheet({super.key, required this.venueId});

  final String venueId;

  @override
  ConsumerState<PhoneBookingSheet> createState() => _PhoneBookingSheetState();
}

class _PhoneBookingSheetState extends ConsumerState<PhoneBookingSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _party = TextEditingController(text: '2');
  final _notes = TextEditingController();

  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  int _duration = 90;
  String? _tableId;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _party.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 120)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final input = PhoneBookingInput(
      guestName: _name.text,
      guestPhone: _phone.text,
      partySize: int.tryParse(_party.text.trim()) ?? 2,
      startAt: _start,
      durationMinutes: _duration,
      tableId: _tableId,
      notes: _notes.text,
    );
    try {
      await ref.read(operationsRepositoryProvider).createPhoneBooking(
            widget.venueId,
            input,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not book:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(tablesProvider(widget.venueId)).valueOrNull ?? [];
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New phone booking', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Guest name *'),
                validator: (v) =>
                    Validators.text(v, field: 'Guest name', min: 2, max: 120),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) => Validators.phone(v),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _party,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Party size *'),
                validator: (v) => Validators.integer(
                  v,
                  field: 'Party size',
                  min: 1,
                  max: 200,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              InkWell(
                onTap: _pickStart,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start',
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(
                    DisplayDate.dateTime(_start),
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String?>(
                initialValue: _tableId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Table (optional)'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Assign automatically'),
                  ),
                  for (final table in tables.where((t) => t.isActive))
                    DropdownMenuItem<String?>(
                      value: table.id,
                      child: Text('${table.label} · ${table.seatLabel}'),
                    ),
                ],
                onChanged: (v) => setState(() => _tableId = v),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Duration', style: AppTextStyles.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final minutes in const [60, 90, 120, 150])
                    ChoiceChip(
                      label: Text('$minutes min'),
                      selected: _duration == minutes,
                      onSelected: (_) => setState(() => _duration = minutes),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Allergies, occasion, high chair…',
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
                    : const Text('Confirm booking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
