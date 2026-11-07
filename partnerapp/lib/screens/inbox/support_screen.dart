import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comms.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
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

/// Support tickets and moderation cases (`POST /feedback`, `GET /users/me/*`).
///
/// There is no partner-side resolution workflow and no venue refund action, so
/// the header says plainly that a ticket is the channel, a refund is requested
/// by filing one, not by tapping a button that does not exist. Statuses are
/// read-only here; support owns the replies.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(ticketsProvider);
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
                child: Text(
                  'Account-wide. Filing a ticket is how you reach the platform; '
                  'refunds and disputes are raised the same way.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              TextButton.icon(
                onPressed: () => _newTicket(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New ticket'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<SupportTicket>>(
            value: tickets,
            onRetry: () => ref.invalidate(ticketsProvider),
            emptyState: const EmptyState(
              title: 'No tickets',
              message: 'Open one for a bug, a billing question or a problem '
                  'with a booking, and the platform will reply.',
              icon: Icons.support_agent_outlined,
            ),
            builder: (context, rows) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(ticketsProvider),
              child: TileList(
                children: [
                  for (final t in rows) _TicketTile(ticket: t),
                  const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.md),
                    child: DisabledTile(
                      title: 'Refunds & dispute resolution',
                      reason: 'The app cannot issue a refund or close a case. '
                          'File a ticket with the category "Payment or payout" '
                          'and the platform handles it.',
                      icon: Icons.money_off_outlined,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _newTicket(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TicketFormSheet(),
    );
    if (created == true) ref.invalidate(ticketsProvider);
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    return PremiumCard(
      padding: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(t.subject, style: AppTextStyles.titleMedium)),
                StatusChip(status: t.status.wire, label: t.status.label),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              t.description,
              style: AppTextStyles.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.ticket.isEmpty ? '-' : t.ticket,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ),
                Text(
                  t.createdAt == null
                      ? ''
                      : DisplayDate.relative(t.createdAt!),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
            if (t.relatedRef.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              InfoRow(label: 'Reference', value: t.relatedRef),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketFormSheet extends ConsumerStatefulWidget {
  const _TicketFormSheet();

  @override
  ConsumerState<_TicketFormSheet> createState() => _TicketFormSheetState();
}

class _TicketFormSheetState extends ConsumerState<_TicketFormSheet> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _relatedRef = TextEditingController();
  TicketCategory _category = TicketCategory.general;
  bool _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _relatedRef.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(businessRepositoryProvider).createTicket(
        category: _category,
        subject: _subject.text,
        description: _description.text,
        relatedRef: _relatedRef.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not file ticket:');
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
              Text('New ticket', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<TicketCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in TicketCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Subject *'),
                validator: (v) =>
                    Validators.text(v, field: 'Subject', min: 3, max: 160),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _description,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description *'),
                validator: (v) =>
                    Validators.text(v, field: 'Description', min: 10, max: 2000),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _relatedRef,
                decoration: const InputDecoration(
                  labelText: 'Booking / experience reference',
                  helperText: 'Optional, helps support find the case.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: const Text('File ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
