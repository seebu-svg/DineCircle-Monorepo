import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/operations.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/money.dart';
import '../../widgets/async_views.dart';
import '../../widgets/data_widgets.dart';
import '../../widgets/premium_cards.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

/// Experience ticket sales (`GET /partner/bookings`).
///
/// The route is account-wide, so the list is labelled as spanning every venue
/// the caller operates. An experience filter narrows it to one event, mirroring
/// the door's need to work a single service at a time; a booking detail carries
/// check-in, and the guest actions the API does not expose render disabled.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String? _eventId;
  String? _status;

  ({String? eventId, String? status}) get _key =>
      (eventId: _eventId, status: _status);

  @override
  Widget build(BuildContext context) {
    final experiences = ref.watch(experiencesProvider(null));
    final bookings = ref.watch(bookingsProvider(_key));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.md,
            AppSpacing.paddingScreen,
            0,
          ),
          child: Column(
            children: [
              experiences.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (rows) => DropdownButtonFormField<String>(
                  initialValue: _eventId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Experience',
                    helperText: 'Bookings span every venue you operate.',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('All experiences'),
                    ),
                    for (final e in rows)
                      DropdownMenuItem<String>(
                        value: e.id,
                        child: Text(e.title, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => _eventId = (v == '' ? null : v)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final entry in const {
                          null: 'All',
                          'confirmed': 'Confirmed',
                          'pending': 'Pending',
                          'cancelled': 'Cancelled',
                        }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _status == entry.key,
                        onSelected: (_) => setState(() => _status = entry.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<PartnerBooking>>(
            value: bookings,
            onRetry: () => ref.invalidate(bookingsProvider(_key)),
            emptyState: EmptyState(
              title: 'No bookings',
              message: _eventId == null
                  ? 'No tickets have been sold across your experiences yet.'
                  : 'No bookings match this filter for the selected experience.',
              icon: Icons.confirmation_number_outlined,
            ),
            builder: (context, rows) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(bookingsProvider(_key)),
              child: TileList(
                children: [
                  for (final b in rows)
                    _BookingTile(
                      booking: b,
                      onTap: () => showBookingSheet(context, b),
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

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking, required this.onTap});

  final PartnerBooking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return PremiumCard(
      padding: 0,
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
                    child: Text(b.guestName, style: AppTextStyles.titleMedium),
                  ),
                  StatusChip(status: b.status.wire, label: b.status.label),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                b.eventTitle.isEmpty ? 'Experience' : b.eventTitle,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: Text('${b.seats} seats',
                      style: AppTextStyles.bodyMedium)),
                  Text(
                    formatMoney(b.totalAmount),
                    style: AppTextStyles.numericMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.reference.isEmpty ? 'No reference' : b.reference,
                      style: AppTextStyles.labelSmall,
                    ),
                  ),
                  if (b.checkedIn)
                    const StatusChip(status: 'paid', label: 'Checked in')
                  else if (b.isPaid)
                    const StatusChip(status: 'confirmed', label: 'Not checked in')
                  else
                    StatusChip(status: b.paymentStatus, label: b.paymentStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full record for one booking plus the actions the desk can take.
Future<void> showBookingSheet(BuildContext context, PartnerBooking booking) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BookingSheet(booking: booking),
  );
}

class _BookingSheet extends ConsumerStatefulWidget {
  const _BookingSheet({required this.booking});

  final PartnerBooking booking;

  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  bool _busy = false;

  ({String? eventId, String? status}) get _key =>
      (eventId: null, status: null);

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(operationsRepositoryProvider).checkIn(widget.booking.id);
      ref.invalidate(bookingsProvider(_key));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Check-in failed:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
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
          Row(
            children: [
              Expanded(
                child: Text(b.guestName, style: AppTextStyles.headlineSmall),
              ),
              StatusChip(status: b.status.wire, label: b.status.label),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InfoRow(label: 'Experience', value: b.eventTitle),
          InfoRow(label: 'Seats', value: '${b.seats}'),
          InfoRow(label: 'Total', value: formatMoney(b.totalAmount)),
          InfoRow(label: 'Payment', value: b.paymentStatus),
          InfoRow(
            label: 'Reference',
            value: b.reference,
            trailing: b.reference.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () =>
                        copyToClipboard(context, b.reference, 'Reference'),
                  ),
          ),
          InfoRow(
            label: 'Check-in',
            value: b.checkedIn ? 'Checked in' : 'Not yet',
          ),
          const SizedBox(height: AppSpacing.md),
          RoleGateBuilder(
            capability: Capability.checkIn,
            builder: (context, allowed, denial) => FilledButton.icon(
              onPressed: allowed && b.canCheckIn && !_busy ? _checkIn : null,
              icon: const Icon(Icons.how_to_reg),
              label: Text(b.checkedIn ? 'Already checked in' : 'Check in'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const DisabledTile(
            title: 'Dietary requirements',
            reason: 'The platform does not expose a guest\'s dietary notes per '
                'booking; ask at the door or check the menu allergen list.',
            icon: Icons.restaurant,
          ),
        ],
      ),
    );
  }
}
