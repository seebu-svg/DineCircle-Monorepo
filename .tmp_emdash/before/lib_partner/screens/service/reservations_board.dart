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
import '../../widgets/async_views.dart';
import '../../widgets/premium_cards.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';
import 'phone_booking_sheet.dart';
import 'reservation_detail_sheet.dart';

/// The day board: reservations grouped by slot, worked top to bottom.
///
/// The date travels as a `yyyy-MM-dd` key (the server resolves it in the branch
/// timezone) and the walk with ±1 day is pure calendar arithmetic, so a desk in
/// a different device zone still sees the venue's service day correctly. Only
/// the actions legal from the current status render, mirroring the server's
/// transition table so a tap never produces a `409`.
class ReservationsBoard extends ConsumerStatefulWidget {
  const ReservationsBoard({super.key});

  @override
  ConsumerState<ReservationsBoard> createState() => _ReservationsBoardState();
}

class _ReservationsBoardState extends ConsumerState<ReservationsBoard> {
  late DateTime _day = ServiceDate.startOfDay(DateTime.now());
  String? _status;

  ({String venue, String? date, String? status}) get _key => (
    venue: ref.read(selectedVenueIdProvider),
    date: ServiceDate.key(_day),
    status: _status,
  );

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    if (venueId.isEmpty) return const _NoVenue();
    final key = (venue: venueId, date: ServiceDate.key(_day), status: _status);
    final reservations = ref.watch(reservationsProvider(key));

    return Column(
      children: [
        _DayBar(
          day: _day,
          status: _status,
          onShift: (delta) => setState(
            () => _day = ServiceDate.addDays(_day, delta),
          ),
          onToday: () => setState(
            () => _day = ServiceDate.startOfDay(DateTime.now()),
          ),
          onStatus: (s) => setState(() => _status = s),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(reservationsProvider(key));
              try {
                await ref.read(reservationsProvider(key).future);
              } catch (_) {}
            },
            child: reservations.when(
              loading: () => const LoadingSkeleton(),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(reservationsProvider(key)),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return _EmptyDay(
                    onPhoneBooking: () => _openPhoneBooking(venueId),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: _groupBySlot(rows),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _groupBySlot(List<Reservation> rows) {
    final byTime = <String, List<Reservation>>{};
    for (final r in rows) {
      byTime.putIfAbsent(_slotKey(r.startAt), () => []).add(r);
    }
    final keys = byTime.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final key in keys) {
      final group = byTime[key]!;
      final covers = group
          .where((r) => r.status.holdsCovers)
          .fold<int>(0, (sum, r) => sum + r.partySize);
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.lg,
            AppSpacing.paddingScreen,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(key, style: AppTextStyles.titleLarge),
              const Spacer(),
              Text(
                '${group.length} tables · $covers covers',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      );
      widgets.addAll([
        for (final r in group)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.paddingScreen,
              vertical: AppSpacing.xs,
            ),
            child: _ReservationTile(
              reservation: r,
              onAction: (action) => _act(r, action),
              onOpen: () => showReservationSheet(context, r,
                  venueId: ref.read(selectedVenueIdProvider)),
            ),
          ),
      ]);
    }
    return widgets;
  }

  Future<void> _act(Reservation r, ReservationAction action) async {
    final venueId = ref.read(selectedVenueIdProvider);
    final confirm = action == ReservationAction.cancel ||
        action == ReservationAction.noShow;
    if (confirm) {
      final ok = await confirmAction(
        context,
        title: action.label,
        message: '${action.label} ${r.guestName}’s ${r.partyLabel} at '
            '${r.timeLabel}?',
        confirmLabel: action.label,
        destructive: true,
      );
      if (!ok) return;
    }
    try {
      await ref
          .read(operationsRepositoryProvider)
          .actOnReservation(venueId, r.id, action);
      ref.invalidate(reservationsProvider(_key));
      if (mounted) showToast(context, '${r.guestName}: ${action.label}');
    } catch (error) {
      if (mounted) reportError(context, error);
    }
  }

  Future<void> _openPhoneBooking(String venueId) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PhoneBookingSheet(venueId: venueId),
    );
    if (created == true) ref.invalidate(reservationsProvider(_key));
  }
}

/// A single reservation row with its legal actions and a role gate.
class _ReservationTile extends ConsumerWidget {
  const _ReservationTile({
    required this.reservation,
    required this.onAction,
    required this.onOpen,
  });

  final Reservation reservation;
  final ValueChanged<ReservationAction> onAction;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reservation;
    final actions = r.allowedActions;
    return PremiumCard(
      padding: 0,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.guestName, style: AppTextStyles.titleMedium),
                  ),
                  StatusChip(status: r.status.wire, label: r.status.label),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${r.partyLabel} · ${r.timeLabel}'
                '${r.isPhoneIn ? ' · phone-in' : ''}',
                style: AppTextStyles.bodySmall,
              ),
              if (r.notes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  r.notes,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                RoleGateBuilder(
                  capability: Capability.manageReservations,
                  builder: (context, allowed, denial) => Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final action in actions)
                        _ActionButton(
                          action: action,
                          enabled: allowed,
                          onTap: () => onAction(action),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
    return SizedBox(height: 40, child: child);
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.status,
    required this.onShift,
    required this.onToday,
    required this.onStatus,
  });

  final DateTime day;
  final String? status;
  final ValueChanged<int> onShift;
  final VoidCallback onToday;
  final ValueChanged<String?> onStatus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingScreen,
        AppSpacing.md,
        AppSpacing.paddingScreen,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => onShift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: onToday,
                  child: Column(
                    children: [
                      Text(
                        DisplayDate.dayLong(day),
                        style: AppTextStyles.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        ServiceDate.isToday(day) ? 'Today' : 'Tap for today',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: ServiceDate.isToday(day)
                              ? AppColors.primary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onShift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All', null, status, onStatus),
                for (final s in ReservationStatus.values)
                  _filterChip(s.label, s.wire, status, onStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    String? value,
    String? current,
    ValueChanged<String?> onStatus,
  ) {
    final selected = current == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onStatus(value),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onPhoneBooking});

  final VoidCallback onPhoneBooking;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        EmptyState(
          title: 'No reservations',
          message: 'Nothing is booked for this day with the current filter. '
              'Take a booking over the phone to add one.',
          icon: Icons.event_busy_outlined,
          action: FilledButton.icon(
            onPressed: onPhoneBooking,
            icon: const Icon(Icons.add_call),
            label: const Text('New phone booking'),
          ),
        ),
      ],
    );
  }
}

class _NoVenue extends StatelessWidget {
  const _NoVenue();

  @override
  Widget build(BuildContext context) => const EmptyState(
        title: 'No venue selected',
        message: 'Register or switch to a venue to see its reservations.',
        icon: Icons.storefront,
      );
}

/// `HH:MM` in the local frame, used to bucket rows into a slot header.
String _slotKey(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
