import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_time.dart';
import '../utils/money.dart';

/// One headline number with its context.
///
/// KPI tiles are the dashboard's primary surface, so the caption that explains
/// what the number counts is part of the widget — a bare figure on a dark card
/// is how a desk misreads a slow day as an outage.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.tone = KpiTone.neutral,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final KpiTone tone;
  final VoidCallback? onTap;
  final Widget? trailing;

  Color get _accent => switch (tone) {
    KpiTone.neutral => AppColors.textPrimary,
    KpiTone.positive => AppColors.success,
    KpiTone.attention => AppColors.warning,
    KpiTone.negative => AppColors.danger,
    KpiTone.accent => AppColors.primary,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.paddingCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: _accent),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: AppTextStyles.numericLarge),
              ),
              if (caption != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  caption!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: tone == KpiTone.neutral
                        ? AppColors.textSecondary
                        : _accent,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum KpiTone { neutral, positive, attention, negative, accent }

/// A money amount, always with its currency symbol and grouped digits.
///
/// Uses tabular figures so a table of totals lines up in columns, which is what
/// makes a payout list scannable.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.currency = kDefaultCurrency,
    this.large = false,
    this.muted = false,
    this.decimals = 2,
  });

  final double amount;
  final String currency;
  final bool large;
  final bool muted;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final style = large ? AppTextStyles.numericLarge : AppTextStyles.numericMedium;
    return Text(
      formatMoney(amount, currency: currency, decimals: decimals),
      style: muted ? style.copyWith(color: AppColors.textSecondary) : style,
    );
  }
}

/// A `label — value` line, the workhorse of every detail sheet.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
    this.maxLines = 4,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 6,
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Responsive card grid.
///
/// Column count is derived from the actual cross-axis extent rather than a
/// fixed breakpoint, so a 320 px phone gets one column, a 1440 px browser gets
/// four or five, and neither ever overflows.
class DataGrid extends StatelessWidget {
  const DataGrid({
    super.key,
    required this.children,
    this.minTileWidth = 240,
    this.spacing = AppSpacing.md,
    this.aspectRatio = 2.6,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / (minTileWidth + spacing))
            .floor()
            .clamp(1, 6);
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              // The aspect ratio is a *floor* on tile height, not a fixed cap:
              // a KPI tile with a two-line caption (or a 2.0 text scale) must
              // grow rather than overflow, which a hard AspectRatio cannot.
              SizedBox(
                width: width,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: width / aspectRatio),
                  child: child,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A bordered, scrollable list of tiles — the mobile-shaped counterpart to the
/// web data table, used wherever a list has no tabular columns.
class TileList extends StatelessWidget {
  const TileList({
    super.key,
    required this.children,
    this.separator = true,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.paddingScreen),
  });

  final List<Widget> children;
  final bool separator;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding.copyWith(bottom: AppSpacing.xl),
      itemCount: children.length,
      separatorBuilder: (_, _) => separator
          ? const SizedBox(height: AppSpacing.sm)
          : const SizedBox.shrink(),
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// A tabular row header for the wide layouts.
class GridRowHeader extends StatelessWidget {
  const GridRowHeader({super.key, required this.cells, this.flexes});

  final List<String> cells;
  final List<int>? flexes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: flexes != null && i < flexes!.length ? flexes![i] : 1,
              child: Text(
                cells[i].toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

/// The "updated 2 minutes ago" caption every polled surface carries, because
/// without push there is no other way to say how fresh a number is.
class UpdatedCaption extends StatelessWidget {
  const UpdatedCaption({super.key, required this.at});

  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final time = at;
    if (time == null) return const SizedBox.shrink();
    return Text(
      'Updated ${DisplayDate.relative(time)}',
      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
    );
  }
}
