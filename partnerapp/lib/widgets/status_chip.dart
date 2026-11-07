import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A compact status pill.
///
/// The colour comes from [AppColors.forStatus], so `confirmed` reads green on a
/// reservation, an experience and a payout alike, one vocabulary across the
/// whole desk.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.label,
    this.dense = false,
  });

  /// Wire value: `confirmed`, `pending_review`, `no_show`, …
  final String status;

  /// Human label; defaults to the wire value with underscores replaced.
  final String? label;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(status);
    final text = (label ?? status.replaceAll('_', ' ')).trim();
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text.isEmpty ? '-' : text,
        style: dense
            ? AppTextStyles.labelSmall.copyWith(color: color)
            : AppTextStyles.labelMedium.copyWith(color: color),
      ),
    );
  }
}

/// A full-width call-out that leads somewhere: unverified venue, hours missing,
/// a feature the API does not support.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = BannerTone.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final BannerTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color get _color => switch (tone) {
    BannerTone.info => AppColors.info,
    BannerTone.success => AppColors.success,
    BannerTone.warning => AppColors.warning,
    BannerTone.danger => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ??
                switch (tone) {
                  BannerTone.danger => Icons.error_outline,
                  BannerTone.warning => Icons.warning_amber_rounded,
                  BannerTone.success => Icons.check_circle_outline,
                  BannerTone.info => Icons.info_outline,
                },
            size: 20,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTextStyles.titleSmall.copyWith(color: color),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(message, style: AppTextStyles.bodySmall),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum BannerTone { info, success, warning, danger }

/// Explains, in place of a control, why something cannot be done.
///
/// The partner API has real gaps (no review replies, no media upload, no
/// redemption counter). The plan's rule is that a gap ships as an explicit
/// disabled state with a reason, this is the widget that carries the reason.
class DisabledTile extends StatelessWidget {
  const DisabledTile({
    super.key,
    required this.reason,
    this.title,
    this.icon = Icons.block,
  });

  final String reason;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  reason,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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
