import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/operations.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../widgets/data_widgets.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

/// Full detail for one reservation, opened from a board row or the Home list.
///
/// The sheet reads the whole record, the guest's phone, their notes, the
/// reference, who booked it, and it also carries the actions that row allows.
/// The buttons come from the same transition map as the board, so a tap never
/// produces a `409`, and a successful action refreshes the providers behind
/// the screen that opened it: the dashboard counters, the Home day list and
/// the board itself.
Future<bool?> showReservationSheet(
  BuildContext context,
  Reservation reservation, {
  required String venueId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _ReservationDetailSheet(reservation: reservation, venueId: venueId),
  );
}

class _ReservationDetailSheet extends ConsumerStatefulWidget {
  const _ReservationDetailSheet({
    required this.reservation,
    required this.venueId,
  });

  final Reservation reservation;
  final String venueId;

  @override
  ConsumerState<_ReservationDetailSheet> createState() =>
      _ReservationDetailSheetState();
}

class _ReservationDetailSheetState
    extends ConsumerState<_ReservationDetailSheet> {
  late Reservation _reservation = widget.reservation;
  bool _busy = false;
  bool _changed = false;

  /// One step of the transition map, then a refresh of everything the change
  /// touched: the dashboard counters, the Home day list and the day board.
  Future<void> _act(ReservationAction action) async {
    final r = _reservation;
    final destructive =
        action == ReservationAction.cancel || action == ReservationAction.noShow;
    if (destructive) {
      final ok = await confirmAction(
        context,
        title: action.label,
        message: '${action.label} ${r.guestName}’s ${r.partyLabel} at '
            '${r.timeLabel}?',
        confirmLabel: action.label,
        destructive: true,
      );
      if (!ok || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(operationsRepositoryProvider)
          .actOnReservation(widget.venueId, r.id, action);
      if (!mounted) return;
      setState(() {
        _reservation = updated;
        _busy = false;
        _changed = true;
      });
      _refreshProviders();
      showToast(context, '${r.guestName}: ${action.label}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      reportError(context, error);
    }
  }

  void _refreshProviders() {
    ref.invalidate(dashboardProvider(widget.venueId));
    ref.invalidate(todayReservationsProvider);
    ref.invalidate(reservationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reservation;
    final actions = r.allowedActions;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      // Scrollable: a long note, a large text scale or a keyboard must never
      // push the actions off the sheet.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.guestName, style: AppTextStyles.headlineSmall),
                ),
                const SizedBox(width: AppSpacing.sm),
                StatusChip(status: r.status.wire, label: r.status.label),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            InfoRow(label: 'Start', value: DisplayDate.dateTime(r.startAt)),
            InfoRow(label: 'Ends', value: DisplayDate.time(r.endTime)),
            InfoRow(label: 'Party', value: r.partyLabel),
            InfoRow(
              label: 'Phone',
              value: r.guestPhone.isEmpty ? '-' : r.guestPhone,
              trailing: r.guestPhone.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          copyToClipboard(context, r.guestPhone, 'Phone'),
                    ),
            ),
            InfoRow(
              label: 'Reference',
              value: r.reference.isEmpty ? '-' : r.reference,
              trailing: r.reference.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () =>
                          copyToClipboard(context, r.reference, 'Reference'),
                    ),
            ),
            InfoRow(label: 'Source', value: r.isPhoneIn ? 'Phone-in' : 'Guest app'),
            if (r.notes.isNotEmpty)
              InfoRow(label: 'Notes', value: r.notes, maxLines: 6),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              RoleGateBuilder(
                capability: Capability.manageReservations,
                builder: (context, allowed, denial) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ACTIONS',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final action in actions)
                          _SheetActionButton(
                            action: action,
                            enabled: allowed && !_busy,
                            onTap: () => _act(action),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (_changed)
                  Expanded(
                    child: Text(
                      'Status updated',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(_changed),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One legal transition, styled by what it does to the booking.
class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.action,
    required this.enabled,
    required this.onTap,
  });

  final ReservationAction action;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final destructive =
        action == ReservationAction.cancel || action == ReservationAction.noShow;
    final positive = action == ReservationAction.confirm ||
        action == ReservationAction.seat ||
        action == ReservationAction.complete;
    final child = destructive
        ? OutlinedButton(
            onPressed: enabled ? onTap : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            child: Text(action.label),
          )
        : positive
            ? FilledButton(
                onPressed: enabled ? onTap : null,
                child: Text(action.label),
              )
            : OutlinedButton(
                onPressed: enabled ? onTap : null,
                child: Text(action.label),
              );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
      child: child,
    );
  }
}
