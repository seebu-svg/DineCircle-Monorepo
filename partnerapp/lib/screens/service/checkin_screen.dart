import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

/// Door check-in for experience tickets.
///
/// The scan endpoint keys on the booking id, but the guest presents a reference
/// string from a QR code, so the scan result (or a pasted reference) is resolved
/// against the bookings already loaded for the chosen experience. Camera capture
/// is mobile-only; on web, manual reference entry is the path — the one honest
/// route the API supports without a scanner.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  String? _eventId;
  final _reference = TextEditingController();
  bool _busy = false;

  ({String? eventId, String? status}) get _bookingsKey =>
      (eventId: _eventId, status: null);

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _checkIn() async {
    final raw = _reference.text.trim();
    if (Validators.bookingReference(raw) != null) {
      showToast(context, 'Enter a booking reference or id.', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final bookings = await ref.read(bookingsProvider(_bookingsKey).future);
      final booking = _resolve(bookings, raw);
      if (booking == null) {
        _showResult(_CheckinOutcome(_CheckinKind.notFound, reference: raw));
        return;
      }
      final updated =
          await ref.read(operationsRepositoryProvider).checkIn(booking.id);
      ref.invalidate(bookingsProvider(_bookingsKey));
      _showResult(
        updated.isCancelled
            ? _CheckinOutcome(_CheckinKind.cancelled, booking: updated)
            : _CheckinOutcome(_CheckinKind.success, booking: updated),
      );
    } catch (error) {
      _showResult(_CheckinOutcome.fromError(error, raw));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PartnerBooking? _resolve(List<PartnerBooking> bookings, String raw) {
    final lower = raw.toLowerCase();
    for (final b in bookings) {
      if (b.reference.toLowerCase() == lower || b.id.toLowerCase() == lower) {
        return b;
      }
    }
    // A bare UUID not in the loaded list is still a valid id to the server.
    if (Validators.looksLikeUuid(raw)) {
      return PartnerBooking(
        id: raw,
        eventId: '',
        eventTitle: 'Booking',
        guestName: '',
        seats: 0,
        totalAmount: 0,
        status: BookingStatus.confirmed,
        paymentStatus: 'paid',
        reference: raw,
        checkedIn: false,
      );
    }
    return null;
  }

  void _showResult(_CheckinOutcome outcome) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ResultSheet(outcome: outcome),
    ).then((_) => _reference.clear());
  }

  @override
  Widget build(BuildContext context) {
    final experiences = ref.watch(experiencesProvider('confirmed'));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Check in guests', style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Scan a ticket or type its reference to verify and check the guest '
          'in. Only a paid, live booking can be checked in.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        experiences.when(
          loading: () => const LoadingSkeleton(count: 1),
          error: (e, _) => ErrorView(error: e),
          data: (rows) {
            if (rows.isEmpty) {
              return const DisabledTile(
                title: 'No confirmed experiences',
                reason: 'Nothing to check guests in to right now.',
              );
            }
            return DropdownButtonFormField<String>(
              initialValue: _eventId ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Experience'),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Search across all experiences'),
                ),
                for (final e in rows)
                  DropdownMenuItem<String>(
                    value: e.id,
                    child: Text(
                      '${e.title} · ${DisplayDate.dateTime(e.startAt)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _eventId = (v == '' ? null : v)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        RoleGateBuilder(
          capability: Capability.checkIn,
          builder: (context, allowed, denial) => TextFormField(
            controller: _reference,
            enabled: allowed,
            onFieldSubmitted: (_) => allowed ? _checkIn() : null,
            decoration: InputDecoration(
              labelText: 'Booking reference or id',
              helperText: denial,
              suffixIcon: allowed && !kIsWeb
                  ? IconButton(
                      tooltip: 'Scan QR',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanUnavailable,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        RoleGateBuilder(
          capability: Capability.checkIn,
          builder: (context, allowed, denial) => FilledButton.icon(
            onPressed: allowed && !_busy ? _checkIn : null,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.how_to_reg),
            label: const Text('Check in'),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const DisabledTile(
          title: 'Offer redemption',
          reason: 'The platform does not yet expose a deal-redemption counter, '
              'so offers cannot be redeemed here.',
          icon: Icons.local_offer_outlined,
        ),
      ],
    );
  }

  void _scanUnavailable() {
    showToast(
      context,
      'Camera capture is not wired up in this build; type or paste the '
      'reference instead.',
      isError: true,
    );
  }
}

enum _CheckinKind { success, already, cancelled, notFound, forbidden }

class _CheckinOutcome {
  const _CheckinOutcome(
    this.kind, {
    this.booking,
    this.reference = '',
  });

  factory _CheckinOutcome.fromError(Object error, String reference) {
    final text = error.toString().toLowerCase();
    if (text.contains('already')) {
      return _CheckinOutcome(_CheckinKind.already, reference: reference);
    }
    if (text.contains('cancel')) {
      return _CheckinOutcome(_CheckinKind.cancelled, reference: reference);
    }
    if (text.contains('403') || text.contains('forbidden')) {
      return _CheckinOutcome(_CheckinKind.forbidden, reference: reference);
    }
    return _CheckinOutcome(_CheckinKind.notFound, reference: reference);
  }

  final _CheckinKind kind;
  final PartnerBooking? booking;
  final String reference;
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.outcome});

  final _CheckinOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final ok = outcome.kind == _CheckinKind.success;
    final icon = switch (outcome.kind) {
      _CheckinKind.success => Icons.check_circle,
      _CheckinKind.already => Icons.how_to_reg,
      _CheckinKind.cancelled => Icons.cancel,
      _CheckinKind.notFound => Icons.search_off,
      _CheckinKind.forbidden => Icons.lock,
    };
    final title = switch (outcome.kind) {
      _CheckinKind.success => 'Checked in',
      _CheckinKind.already => 'Already checked in',
      _CheckinKind.cancelled => 'Booking cancelled',
      _CheckinKind.notFound => 'Booking not found',
      _CheckinKind.forbidden => 'Not your booking',
    };
    final detail = switch (outcome.kind) {
      _CheckinKind.success =>
        '${outcome.booking?.guestName ?? 'Guest'} · '
            '${outcome.booking?.seats ?? 0} seats',
      _CheckinKind.already =>
        '${outcome.reference.isEmpty ? 'That ticket' : outcome.reference} '
            'has already been admitted.',
      _CheckinKind.cancelled =>
        'This booking was cancelled and cannot be used.',
      _CheckinKind.notFound =>
        'No booking matches "${outcome.reference}". Check the reference or '
        'select the right experience above.',
      _CheckinKind.forbidden =>
        'This booking does not belong to a venue you operate.',
    };
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: ok ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
