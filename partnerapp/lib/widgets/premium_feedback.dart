import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// ShimmerSkeleton
// ---------------------------------------------------------------------------

/// A pulsing placeholder that mimics the shape of content while it loads.
///
/// Respects [MediaQueryData.disableAnimations], when animations are disabled
/// the shimmer renders as a static translucent box instead of animating.
class ShimmerSkeleton extends StatefulWidget {
  const ShimmerSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      return _StaticSkeleton(
        width: widget.width,
        height: widget.height,
        borderRadius: widget.borderRadius,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Sweep a lighter band from left to right.
        final gradient = LinearGradient(
          begin: Alignment(t * 3 - 1, 0),
          end: Alignment(t * 3 + 1, 0),
          colors: [
            AppColors.surfaceHigh.withValues(alpha: 0.3),
            AppColors.surfaceHigh.withValues(alpha: 0.6),
            AppColors.surfaceHigh.withValues(alpha: 0.3),
          ],
          stops: const [0.0, 0.5, 1.0],
        );
        return _StaticSkeleton(
          width: widget.width,
          height: widget.height,
          borderRadius: widget.borderRadius,
          gradient: gradient,
        );
      },
    );
  }
}

class _StaticSkeleton extends StatelessWidget {
  const _StaticSkeleton({
    this.width,
    required this.height,
    this.borderRadius,
    this.gradient,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              colors: [
                AppColors.surfaceHigh.withValues(alpha: 0.4),
                AppColors.surfaceHigh.withValues(alpha: 0.4),
              ],
            ),
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// InlineNotice
// ---------------------------------------------------------------------------

/// A coloured banner used inline (inside a card, between sections) to surface
/// a contextual message: info, warning, success or error.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.kind = InlineNoticeKind.info,
    this.icon,
    this.action,
  });

  final String message;
  final InlineNoticeKind kind;
  final IconData? icon;
  final InlineNoticeAction? action;

  Color get _color {
    switch (kind) {
      case InlineNoticeKind.info:
        return AppColors.info;
      case InlineNoticeKind.warning:
        return AppColors.warning;
      case InlineNoticeKind.success:
        return AppColors.success;
      case InlineNoticeKind.error:
        return AppColors.danger;
    }
  }

  IconData get _defaultIcon {
    switch (kind) {
      case InlineNoticeKind.info:
        return Icons.info_outline;
      case InlineNoticeKind.warning:
        return Icons.warning_amber_outlined;
      case InlineNoticeKind.success:
        return Icons.check_circle_outline;
      case InlineNoticeKind.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: _color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _defaultIcon, size: 18, color: _color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: action!.onTap,
              child: Text(
                action!.label,
                style: AppTextStyles.labelSmall.copyWith(color: _color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum InlineNoticeKind { info, warning, success, error }

class InlineNoticeAction {
  const InlineNoticeAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

// ---------------------------------------------------------------------------
// NotTrackedTile
// ---------------------------------------------------------------------------

/// A standard "the platform does not expose this" tile.
///
/// Used wherever a screen would like to show a metric (QR scans, profile
/// views, loyalty points, modifiers, featured items) but the backend has no
/// data for it. The tile is honest, it never fabricates numbers.
class NotTrackedTile extends StatelessWidget {
  const NotTrackedTile({
    super.key,
    required this.metric,
    this.reason,
    this.supportLink,
  });

  final String metric;
  final String? reason;
  final String? supportLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.textTertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              Icons.sync_disabled,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$metric is not tracked',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason ??
                      'The DineCircle platform does not currently expose '
                          'this metric to partners.',
                  style: AppTextStyles.bodySmall,
                ),
                if (supportLink != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: () {
                      // Intentionally a no-op at the widget level; the caller
                      // can wrap this tile in a link handler if desired.
                    },
                    child: Text(
                      supportLink!,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
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
