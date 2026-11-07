import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

// ---------------------------------------------------------------------------
// Shared frame
// ---------------------------------------------------------------------------

/// A chrome wrapper for every chart: title row, optional subtitle, legend
/// chips, and a consistent empty / partial-data notice.
///
/// The chart body is supplied via [child] so this frame stays presentation-
/// only and is trivially testable.
class ChartFrame extends StatelessWidget {
  const ChartFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.legend = const [],
    this.emptyNotice,
    this.child = const SizedBox.shrink(),
  });

  final String title;
  final String? subtitle;
  final List<ChartLegendEntry> legend;

  /// When non-null the frame renders a "no data" placeholder instead of
  /// [child]. Use this when the underlying series is empty.
  final String? emptyNotice;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(), style: AppTextStyles.overline),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (legend.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final e in legend)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: e.color.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: e.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          e.label,
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (emptyNotice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.insights_outlined,
                    color: AppColors.textTertiary,
                    size: 32,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    emptyNotice!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            )
          else
            SizedBox(height: 200, child: child),
        ],
      ),
    );
  }
}

class ChartLegendEntry {
  const ChartLegendEntry({required this.label, required this.color});

  final String label;
  final Color color;
}

// ---------------------------------------------------------------------------
// Data records
// ---------------------------------------------------------------------------

/// A single time-series data point.
class TrendPoint {
  const TrendPoint({required this.date, required this.value});

  final DateTime date;
  final double value;
}

/// A single labelled bar for a categorical chart.
class BarPoint {
  const BarPoint({required this.label, required this.value});

  final String label;
  final double value;
}

// ---------------------------------------------------------------------------
// TrendLineChart
// ---------------------------------------------------------------------------

/// A smooth line chart rendered from [TrendPoint]s.
///
/// Shows a gradient fill beneath the line, circular data-point dots when there
/// are ≤ 31 points (daily / weekly granularity), and horizontal grid lines
/// styled to the dark theme.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.points,
    this.lineColor = AppColors.primary,
    this.showDots = true,
    this.fillGradient = true,
  });

  final List<TrendPoint> points;
  final Color lineColor;
  final bool showDots;
  final bool fillGradient;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value),
    ];

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final effectiveMaxY = maxY == 0 ? 1.0 : maxY;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: effectiveMaxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border.withValues(alpha: 0.5),
              strokeWidth: 0.8,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: effectiveMaxY / 4,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _compact(value),
                    style: AppTextStyles.labelSmall.copyWith(fontSize: 9),
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      _compact(s.y),
                      AppTextStyles.labelMedium.copyWith(color: lineColor),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: lineColor,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: showDots && points.length <= 31,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 2.5,
                  color: lineColor,
                  strokeWidth: 1.2,
                  strokeColor: AppColors.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: fillGradient,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    lineColor.withValues(alpha: 0.25),
                    lineColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          minY: 0,
          maxY: effectiveMaxY * 1.15,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BarTrendChart
// ---------------------------------------------------------------------------

/// A vertical bar chart from [BarPoint]s.
///
/// Bars are coloured with [barColor] and labelled along the x-axis. The first
/// and last labels are always shown; intermediate labels are thinned when there
/// are more than 10 bars.
class BarTrendChart extends StatelessWidget {
  const BarTrendChart({
    super.key,
    required this.points,
    this.barColor = AppColors.primary,
  });

  final List<BarPoint> points;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final maxY =
        points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final effectiveMaxY = maxY == 0 ? 1.0 : maxY;

    final barGroups = <BarChartGroupData>[
      for (var i = 0; i < points.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: points[i].value,
              color: barColor,
              width: points.length > 20 ? 6 : 12,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
    ];

    final showEveryN = points.length > 10
        ? (points.length / 5).ceil()
        : 1;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: effectiveMaxY * 1.15,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: effectiveMaxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border.withValues(alpha: 0.5),
              strokeWidth: 0.8,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: effectiveMaxY / 4,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _compact(value),
                    style: AppTextStyles.labelSmall.copyWith(fontSize: 9),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= points.length) {
                    return const SizedBox.shrink();
                  }
                  if (idx % showEveryN != 0 && idx != points.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      points[idx].label,
                      style: AppTextStyles.labelSmall.copyWith(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceElevated,
              getTooltipItem: (_, _, rod, _) => BarTooltipItem(
                _compact(rod.toY),
                AppTextStyles.labelMedium.copyWith(color: barColor),
              ),
            ),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sparkline
// ---------------------------------------------------------------------------

/// A tiny inline chart (≈ 80 × 28) suitable for embedding inside a [StatTile]
/// or [MetricRow]. No axes, no grid, just the line.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.points,
    this.color = AppColors.primary,
    this.height = 28,
    this.strokeWidth = 1.8,
  });

  final List<TrendPoint> points;
  final Color color;
  final double height;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(height: height, child: const SizedBox.shrink());
    }
    final values = points.map((p) => p.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final effectiveRange = range == 0 ? 1.0 : range;

    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++)
        FlSpot(
          i.toDouble(),
          (values[i] - minY) / effectiveRange,
        ),
    ];

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: strokeWidth,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          minY: 0,
          maxY: 1.05,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// RankedBarList
// ---------------------------------------------------------------------------

/// A vertical list of horizontal bars, sorted descending by value.
///
/// Used for "top items" panels (e.g. most-redeemed deals, busiest status).
/// Each row shows the rank index, the label, the bar, and the value.
class RankedBarList extends StatelessWidget {
  const RankedBarList({
    super.key,
    required this.points,
    this.barColor = AppColors.primary,
    this.maxRows = 8,
  });

  final List<BarPoint> points;
  final Color barColor;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text('No data', style: AppTextStyles.bodySmall),
      );
    }

    final sorted = [...points]..sort((a, b) => b.value.compareTo(a.value));
    final visible = sorted.take(maxRows).toList();
    final maxValue =
        sorted.first.value == 0 ? 1.0 : sorted.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++)
          _RankedBarRow(
            rank: i + 1,
            label: visible[i].label,
            value: visible[i].value,
            fraction: visible[i].value / maxValue,
            color: barColor,
          ),
      ],
    );
  }
}

class _RankedBarRow extends StatelessWidget {
  const _RankedBarRow({
    required this.rank,
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final int rank;
  final String label;
  final double value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: LinearProgressIndicator(
                value: fraction,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 48,
            child: Text(
              _compact(value),
              textAlign: TextAlign.right,
              style: AppTextStyles.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _compact(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(1);
}
