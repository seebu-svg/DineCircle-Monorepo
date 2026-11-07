
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/subscription.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Subscription and billing management.
///
/// Billing is handled manually by DineCircle.
/// Plan selection records partner intent.
/// Admin activation is required after payment verification.
class SubscriptionTab extends ConsumerWidget {
  const SubscriptionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venueId = ref.watch(selectedVenueIdProvider);

    if (venueId.isEmpty) {
      return const Center(
        child: Text('Select a venue to view your subscription.'),
      );
    }

    final subscription = ref.watch(subscriptionProvider(venueId));
    final gate = ref.watch(roleGateProvider);

    return subscription.when(
      loading: () => const _SubscriptionLoading(),
      error: (error, _) => _SubscriptionError(
        onRetry: () {
          ref.invalidate(subscriptionProvider(venueId));
        },
      ),
      data: (data) => _SubscriptionContent(
        key: ValueKey(venueId),
        venueId: venueId,
        subscription: data,
        canEdit: gate.can(Capability.manageBilling),
      ),
    );
  }
}

class _SubscriptionContent extends ConsumerStatefulWidget {
  const _SubscriptionContent({
    super.key,
    required this.venueId,
    required this.subscription,
    required this.canEdit,
  });

  final String venueId;
  final VenueSubscription subscription;
  final bool canEdit;

  @override
  ConsumerState<_SubscriptionContent> createState() =>
      _SubscriptionContentState();
}

class _SubscriptionContentState
    extends ConsumerState<_SubscriptionContent> {
  bool _busy = false;

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              error ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _selectPlan(SubscriptionPlan plan) async {
    if (_busy || !widget.canEdit) return;

    final confirmed = await _confirmSheet(plan);
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);

    try {
      await ref.read(venueRepositoryProvider).updateSubscription(
            widget.venueId,
            plan: plan.wire,
            autoRenew: true,
          );

      ref.invalidate(subscriptionProvider(widget.venueId));

      _message(
        '${plan.label} plan selected. '
        'Contact support@dinecircle.app with your '
        'payment receipt to request activation.',
      );
    } catch (error) {
      _message(
        'Could not update subscription: $error',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleAutoRenew(bool value) async {
    if (_busy || !widget.canEdit) return;

    setState(() => _busy = true);

    try {
      await ref.read(venueRepositoryProvider).updateSubscription(
            widget.venueId,
            autoRenew: value,
          );

      ref.invalidate(subscriptionProvider(widget.venueId));

      _message(
        value
            ? 'Renewal preference enabled.'
            : 'Renewal preference disabled.',
      );
    } catch (error) {
      _message(
        'Could not update renewal preference: $error',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmSheet(SubscriptionPlan plan) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: FractionallySizedBox(
            heightFactor: 0.65,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_outlined,
                          color: AppColors.primary,
                          size: 27,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Select ${plan.label} Plan',
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review your subscription selection.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.label,
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PKR ${plan.pricePkr.toLocaleString()}',
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              plan == SubscriptionPlan.monthly
                                  ? 'Per month'
                                  : 'Per year',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (plan == SubscriptionPlan.yearly) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Save PKR '
                                '${VenueSubscription.yearlySavingPkr.toLocaleString()} '
                                'per year',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _InfoNotice(
                        icon: Icons.info_outline_rounded,
                        text: 'Selecting a plan does not activate '
                            'your subscription. Billing is arranged '
                            'directly with DineCircle. After payment, '
                            'send your receipt to '
                            'support@dinecircle.app for verification.',
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow =
                              constraints.maxWidth < 320;

                          final cancel = OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(sheetContext, false),
                            child: const Text('Cancel'),
                          );

                          final confirm = FilledButton(
                            onPressed: () =>
                                Navigator.pop(sheetContext, true),
                            child: const Text('Confirm Selection'),
                          );

                          if (narrow) {
                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                confirm,
                                const SizedBox(height: 10),
                                cancel,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: cancel),
                              const SizedBox(width: 10),
                              Expanded(child: confirm),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscription;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final padding = compact ? 16.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            padding,
            16,
            padding,
            36,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageHeader(
                    busy: _busy,
                    onRefresh: () {
                      ref.invalidate(
                        subscriptionProvider(widget.venueId),
                      );
                    },
                  ),

                  const SizedBox(height: 22),

                  _SubscriptionHero(subscription: sub),

                  if (!sub.isActive &&
                      sub.status != SubscriptionStatus.none) ...[
                    const SizedBox(height: 14),
                    _RenewalWall(status: sub.status),
                  ],

                  if (sub.isActive) ...[
                    const SizedBox(height: 26),
                    const _SectionHeader(
                      title: 'Current Plan',
                      subtitle: 'Your active subscription details',
                    ),
                    const SizedBox(height: 12),
                    _CurrentPlanCard(
                      subscription: sub,
                      canEdit: widget.canEdit,
                      busy: _busy,
                      onRenewChanged: _toggleAutoRenew,
                    ),
                  ],

                  const SizedBox(height: 28),

                  const _SectionHeader(
                    title: 'Choose Your Plan',
                    subtitle:
                        'Simple pricing for every restaurant',
                  ),

                  const SizedBox(height: 14),

                  _PlanChooser(
                    currentPlan: sub.plan,
                    busy: _busy,
                    canEdit: widget.canEdit,
                    onTap: _selectPlan,
                  ),

                  const SizedBox(height: 26),

                  const _SectionHeader(
                    title: 'Everything Included',
                    subtitle:
                        'Powerful tools to manage and grow your business',
                  ),

                  const SizedBox(height: 12),

                  const _FeaturesCard(),

                  const SizedBox(height: 20),

                  const _InfoNotice(
                    icon: Icons.shield_outlined,
                    text: 'Payments are arranged directly with '
                        'DineCircle. No payment card or stored-value '
                        'wallet is required in the Partner App.',
                  ),

                  if (!widget.canEdit) ...[
                    const SizedBox(height: 12),
                    const _InfoNotice(
                      icon: Icons.lock_outline_rounded,
                      text: 'Only an authorized venue owner '
                          'can change the subscription.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.busy,
    required this.onRefresh,
  });

  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscription',
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Manage your plan and billing preferences.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh subscription',
          onPressed: busy ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _SubscriptionHero extends StatelessWidget {
  const _SubscriptionHero({
    required this.subscription,
  });

  final VenueSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    final active = sub.isActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active
              ? AppColors.success.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              _StatusBadge(status: sub.status),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'CURRENT SUBSCRIPTION',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            active
                ? '${sub.plan?.label ?? 'Active'} Plan'
                : 'No active plan',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            active
                ? _periodCaption(sub)
                : 'Select a plan and arrange payment '
                    'to request activation.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (active && sub.periodEnd != null) ...[
            const SizedBox(height: 18),
            Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Period ends ${_fmtDate(sub.periodEnd!)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.subscription,
    required this.canEdit,
    required this.busy,
    required this.onRenewChanged,
  });

  final VenueSubscription subscription;
  final bool canEdit;
  final bool busy;
  final ValueChanged<bool> onRenewChanged;

  @override
  Widget build(BuildContext context) {
    final sub = subscription;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            label: 'Plan',
            value: sub.plan?.label ?? 'Not specified',
          ),
          const SizedBox(height: 14),
          _DetailRow(
            label: 'Price',
            value: 'PKR ${sub.pricePkr.toLocaleString()}',
          ),
          if (sub.periodStart != null &&
              sub.periodEnd != null) ...[
            const SizedBox(height: 14),
            _DetailRow(
              label: 'Billing period',
              value:
                  '${_fmtDate(sub.periodStart!)} to '
                  '${_fmtDate(sub.periodEnd!)}',
            ),
          ],
          if (canEdit) ...[
            const SizedBox(height: 16),
            Divider(color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Renewal preference',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Does not automatically charge you.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: sub.autoRenew,
                  onChanged: busy ? null : onRenewChanged,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'For cancellation or billing support, contact '
              'support@dinecircle.app.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            softWrap: true,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanChooser extends StatelessWidget {
  const _PlanChooser({
    required this.currentPlan,
    required this.busy,
    required this.canEdit,
    required this.onTap,
  });

  final SubscriptionPlan? currentPlan;
  final bool busy;
  final bool canEdit;
  final ValueChanged<SubscriptionPlan> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 540;

        final monthly = _PlanOption(
          plan: SubscriptionPlan.monthly,
          selected: currentPlan == SubscriptionPlan.monthly,
          enabled: canEdit && !busy,
          onTap: () => onTap(SubscriptionPlan.monthly),
        );

        final yearly = _PlanOption(
          plan: SubscriptionPlan.yearly,
          selected: currentPlan == SubscriptionPlan.yearly,
          recommended: true,
          enabled: canEdit && !busy,
          onTap: () => onTap(SubscriptionPlan.yearly),
        );

        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: monthly),
              const SizedBox(width: 12),
              Expanded(child: yearly),
            ],
          );
        }

        return Column(
          children: [
            monthly,
            const SizedBox(height: 12),
            yearly,
          ],
        );
      },
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.plan,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.recommended = false,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final bool enabled;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final yearly = plan == SubscriptionPlan.yearly;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected || recommended
                  ? AppColors.primary
                  : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    yearly
                        ? Icons.calendar_month_outlined
                        : Icons.calendar_today_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                yearly ? 'Yearly' : 'Monthly',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'PKR ${plan.pricePkr.toLocaleString()}',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                yearly ? 'per year' : 'per month',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (yearly) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Save PKR '
                    '${VenueSubscription.yearlySavingPkr.toLocaleString()}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: enabled ? onTap : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: selected
                        ? AppColors.surface
                        : AppColors.primary,
                    foregroundColor: selected
                        ? AppColors.primary
                        : Colors.white,
                    side: selected
                        ? const BorderSide(
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                  child: Text(
                    selected ? 'Selected Plan' : 'Choose Plan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final feature in VenueSubscription.proFeatures)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status.wire);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RenewalWall extends StatelessWidget {
  const _RenewalWall({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (status) {
      SubscriptionStatus.trialing => 'Trial period',
      SubscriptionStatus.pastDue => 'Payment overdue',
      SubscriptionStatus.cancelled => 'Subscription cancelled',
      _ => 'Subscription inactive',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusLabel,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Arrange payment directly with DineCircle '
                  'and send your receipt to '
                  'support@dinecircle.app for activation.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
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

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 19,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionLoading extends StatelessWidget {
  const _SubscriptionLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _SubscriptionError extends StatelessWidget {
  const _SubscriptionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to load subscription',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _periodCaption(VenueSubscription sub) {
  if (sub.periodEnd == null) return 'Subscription active';

  final daysLeft =
      sub.periodEnd!.difference(DateTime.now()).inDays;

  if (daysLeft < 0) return 'Period expired';
  if (daysLeft == 0) return 'Expires today';
  if (daysLeft == 1) return '1 day remaining';

  return '$daysLeft days remaining';
}

String _fmtDate(DateTime date) {
  final local = date.toLocal();

  return '${local.year}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

extension _IntFormat on int {
  String toLocaleString() {
    final value = toString();
    final buffer = StringBuffer();
    var count = 0;

    for (var i = value.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(value[i]);
      count++;
    }

    return buffer.toString().split('').reversed.join();
  }
}
