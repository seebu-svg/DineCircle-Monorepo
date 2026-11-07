import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A premium card with a subtle gradient fill, hairline border and an optional
/// left accent bar.
///
/// Replaces the ad-hoc `Card` + `Container` patterns scattered across the app
/// so every surface reads as the same premium shell.
class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = AppSpacing.md,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final Color? accent;
  final double padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusLg);
    // The gradient fill + the multi-colour accent border cannot share one
    // BoxDecoration (Flutter forbids a borderRadius on a non-uniform Border),
    // so the two are split across an outer border shell and an inner gradient
    // shell. Both carry the same radius so the silhouette stays consistent.
    final content = Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surface, AppColors.surfaceElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
      ),
      child: child,
    );
    final body = accent != null
        ? ClipRRect(
            borderRadius: radius,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: accent!, width: 3),
                  top: BorderSide(color: AppColors.border),
                  bottom: BorderSide(color: AppColors.border),
                  right: BorderSide(color: AppColors.border),
                ),
              ),
              child: content,
            ),
          )
        : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.surface, AppColors.surfaceElevated],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: radius,
              border: Border.all(color: AppColors.border),
            ),
            padding: EdgeInsets.all(padding),
            child: child,
          );
    final card = onTap == null ? body : InkWell(
      onTap: onTap,
      borderRadius: radius,
      child: body,
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

/// A wide hero panel with a gradient background, optional eyebrow and trailing
/// action. Used at the top of a screen to announce what the user is looking at.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.accent = AppColors.primary,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.18), AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: AppTextStyles.overline.copyWith(color: accent),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(title, style: AppTextStyles.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    // Subtle settle-in when the screen mounts; skipped entirely when the
    // device asks for animations to be disabled.
    if (MediaQuery.disableAnimationsOf(context)) return panel;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.985, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: panel,
    );
  }
}

/// A section header with an overline label, a title and an optional trailing
/// action (e.g. "See all").
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.overline,
    this.trailing,
  });

  final String title;
  final String? overline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingScreen,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null)
                  Text(overline!, style: AppTextStyles.overline),
                Text(title, style: AppTextStyles.titleMedium),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A single stat tile: label, large value, optional caption and icon.
///
/// Lighter than a [KpiCard],no tone, no tap target,intended for dense
/// summary rows inside a [PremiumCard].
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.tone,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null)
              Icon(icon, size: 16, color: tone ?? AppColors.textSecondary),
            if (icon != null) const SizedBox(width: 4),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: AppTextStyles.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.metricValue.copyWith(
            color: tone ?? AppColors.textPrimary,
            fontSize: 26,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!, style: AppTextStyles.caption, maxLines: 2),
        ],
      ],
    );
  }
}

/// A small pill showing an up / down / flat delta.
class DeltaPill extends StatelessWidget {
  const DeltaPill({super.key, required this.value, this.suffix});

  final double value;
  final String? suffix;

  Color get _color {
    if (value > 0) return AppColors.success;
    if (value < 0) return AppColors.danger;
    return AppColors.textSecondary;
  }

  IconData get _icon {
    if (value > 0) return Icons.trending_up;
    if (value < 0) return Icons.trending_down;
    return Icons.trending_flat;
  }

  @override
  Widget build(BuildContext context) {
    final sign = value > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _color),
          const SizedBox(width: 4),
          Text(
            '$sign${value.toStringAsFixed(1)}${suffix ?? '%'}',
            style: AppTextStyles.labelSmall.copyWith(color: _color),
          ),
        ],
      ),
    );
  }
}

/// A horizontal progress bar with a label and a percent caption.
class ProgressMeter extends StatelessWidget {
  const ProgressMeter({
    super.key,
    required this.percent,
    this.label,
    this.color = AppColors.primary,
  });

  final double percent;
  final String? label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Row(
            children: [
              // The label carries the meaning; it may ellipsis, the percent
              // never may, so only the label flexes.
              Expanded(child: Text(label!, style: AppTextStyles.bodySmall)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(clamped * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.labelMedium.copyWith(color: color),
              ),
            ],
          ),
        if (label != null) const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: LinearProgressIndicator(
            value: clamped,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

/// A label + value row, used inside cards for dense key/value pairs.
class MetricRow extends StatelessWidget {
  const MetricRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A 2x2 (phone) or 4-up (desktop) grid of action tiles.
///
/// Each tile carries a label, icon and optional tint; tapping fires [onTap]
/// with the tile's index.
class ActionGrid extends StatelessWidget {
  const ActionGrid({
    super.key,
    required this.tiles,
    required this.onTap,
  });

  final List<ActionTile> tiles;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // Count columns from the space actually handed to the grid, not the
    // window: the dashboard embeds this in a scrollable whose width can be
    // narrower than the viewport (max-width content shells, test surfaces).
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final crossAxisCount = width >= 600 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.4,
          children: [
            for (var i = 0; i < tiles.length; i++)
              _ActionTileWidget(tile: tiles[i], onTap: () => onTap(i)),
          ],
        );
      },
    );
  }
}

class ActionTile {
  const ActionTile({
    required this.label,
    required this.icon,
    this.tint,
  });

  final String label;
  final IconData icon;
  final Color? tint;
}

class _ActionTileWidget extends StatelessWidget {
  const _ActionTileWidget({required this.tile, required this.onTap});

  final ActionTile tile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = tile.tint ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tile.icon, color: tint, size: 22),
            const SizedBox(height: 6),
            // Flexible so a tight tile height ellipsises the label instead of
            // throwing a RenderFlex overflow at large text scale.
            Flexible(
              child: Text(
                tile.label,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(color: tint),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A plan card for the subscription chooser.
///
/// Highlights the selected plan with a primary border and a "Recommended"
/// eyebrow when [recommended] is true.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.name,
    required this.priceLabel,
    required this.periodLabel,
    required this.features,
    this.recommended = false,
    this.selected = false,
    this.badge,
    this.onTap,
  });

  final String name;
  final String priceLabel;
  final String periodLabel;
  final List<String> features;
  final bool recommended;
  final bool selected;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.primary : AppColors.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text(
                        badge!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              priceLabel,
              style: AppTextStyles.metricValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              periodLabel,
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f, style: AppTextStyles.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
