import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/deals.dart';
import '../../models/experience.dart';
import '../../models/operations.dart';
import '../../models/venue.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../widgets/media_image.dart';
import '../../widgets/premium_feedback.dart';
import '../../widgets/status_chip.dart';

/// ─── Window ────────────────────────────────────────────────────────────────

/// The last calendar day a [DateRange] covers.
///
/// A preset ends at *midnight after* its last day (`to` is the exclusive
/// instant the API is asked for), so the day a partner reads on the label is
/// one before it. Naming it once keeps the header, the buckets and the range
/// chips from disagreeing about which day is "today".
DateTime insightsLastDay(DateRange range) =>
    ServiceDate.addDays(range.to, -1);

/// `5 Nov – 11 Nov`, with the year only when the window crosses one.
String insightsWindowLabel(DateRange range) {
  final first = range.from;
  final last = insightsLastDay(range);
  if (first.year != last.year) {
    return '${DisplayDate.full(first)} – ${DisplayDate.full(last)}';
  }
  return '${DisplayDate.monthDay(first)} – ${DisplayDate.monthDay(last)}';
}

/// ─── Chart data ────────────────────────────────────────────────────────────

/// One column of the reservation chart.
class TrendBucket {
  const TrendBucket({
    required this.start,
    required this.end,
    required this.value,
    required this.axisLabel,
    required this.describe,
  });

  /// First day the bucket covers, inclusive.
  final DateTime start;

  /// Last day the bucket covers, inclusive.
  final DateTime end;

  /// Booked reservations whose service day fell in the bucket.
  final int value;

  /// The short label printed under the bar.
  final String axisLabel;

  /// The bucket in words, for the caption above the chart and for tests.
  final String describe;
}

final DateFormat _weekdayShort = DateFormat('EEE');

/// Daily buckets for a week or a month, weekly buckets for a quarter.
///
/// Every day of the window gets a bucket whether or not it holds a booking:
/// a trend that only plots days with activity draws a line through a closed
/// Monday and reads as a continuous run of guests. A quarter is grouped into
/// weeks because 90 bars on a phone are a barcode, not a trend.
List<TrendBucket> reservationBuckets(
  List<Reservation> reservations, {
  required int days,
  DateTime? now,
}) {
  if (days <= 0) return const [];
  final today = ServiceDate.startOfDay(now ?? DateTime.now());
  final first = ServiceDate.addDays(today, -(days - 1));

  final counts = <String, int>{};
  for (final row in reservations) {
    final day = ServiceDate.startOfDay(row.startAt);
    if (day.isBefore(first) || day.isAfter(today)) continue;
    final key = ServiceDate.key(day);
    counts[key] = (counts[key] ?? 0) + 1;
  }

  int countBetween(DateTime from, DateTime to) {
    var total = 0;
    for (var day = from;
        !day.isAfter(to);
        day = ServiceDate.addDays(day, 1)) {
      total += counts[ServiceDate.key(day)] ?? 0;
    }
    return total;
  }

  if (days <= 30) {
    return [
      for (var i = 0; i < days; i++)
        if (ServiceDate.addDays(first, i) case final day)
          TrendBucket(
            start: day,
            end: day,
            value: counts[ServiceDate.key(day)] ?? 0,
            axisLabel:
                // A weekday reads on a week; a month needs the date, and the
                // month itself is already in the caption above the chart.
                days <= 7 ? _weekdayShort.format(day) : '${day.day}',
            describe: DisplayDate.day(day),
          ),
    ];
  }

  final buckets = <TrendBucket>[];
  for (var end = today; !end.isBefore(first);) {
    final windowStart = ServiceDate.addDays(end, -6);
    final start = windowStart.isBefore(first) ? first : windowStart;
    buckets.add(
      TrendBucket(
        start: start,
        end: end,
        value: countBetween(start, end),
        axisLabel: DisplayDate.monthDay(start),
        describe:
            '${DisplayDate.monthDay(start)} – ${DisplayDate.monthDay(end)}',
      ),
    );
    end = ServiceDate.addDays(start, -1);
  }
  return buckets.reversed.toList(growable: false);
}

/// Which buckets get an axis label for a plot that fits [budget] of them.
///
/// The last bucket is always labelled: "today" is the anchor a partner looks
/// for first, and a stride that happens to skip it makes the axis look like it
/// ends in the past.
List<int> axisTicks(int count, int budget) {
  if (count <= 0) return const [];
  final room = budget < 2 ? 2 : budget;
  final stride = (count / room).ceil();
  final ticks = <int>[for (var i = 0; i < count; i += stride) i];
  final last = count - 1;
  if (ticks.last != last) {
    if (last - ticks.last < stride * 0.6) {
      ticks[ticks.length - 1] = last;
    } else {
      ticks.add(last);
    }
  }
  return ticks;
}

/// The top of the y axis, rounded so the gridlines land on whole bookings.
int chartCeiling(int peak) {
  if (peak <= 0) return 1;
  if (peak <= 4) return peak;
  final step = peak <= 10
      ? 2
      : peak <= 50
          ? 5
          : 10;
  return ((peak + step - 1) ~/ step) * step;
}

/// The whole numbers printed beside the chart's gridlines, with the fraction of
/// the plot each one sits at.
///
/// The middle rule is labelled only when the ceiling splits in whole bookings.
/// A ceiling of 1 (one booking) or 3 has no integer half, and rounding it would
/// print the top value twice and mislabel the middle rule.
List<({double fraction, int value})> axisLabels(int ceiling) {
  if (ceiling <= 0) return const [(fraction: 0, value: 0)];
  return [
    (fraction: 1, value: ceiling),
    if (ceiling.isEven) (fraction: 0.5, value: ceiling ~/ 2),
    (fraction: 0, value: 0),
  ];
}

/// ─── Performance figures ───────────────────────────────────────────────────

/// What the venue's promotions have been redeemed for, all time.
///
/// `known` is false when the server sent no counters at all: an absent figure
/// must read as "not reported", never as zero uses.
class DealPerformance {
  const DealPerformance({required this.rows, required this.known});

  factory DealPerformance.of(List<Deal> deals) {
    final rows = deals
        .where((deal) => deal.redemptionsReported)
        .toList(growable: false)
      ..sort((a, b) => b.redemptions.compareTo(a.redemptions));
    return DealPerformance(rows: rows, known: rows.isNotEmpty);
  }

  /// Deals with a counter, most redeemed first.
  final List<Deal> rows;

  /// Whether any counter was reported.
  final bool known;

  int get total =>
      rows.fold(0, (sum, deal) => sum + deal.redemptions);

  int get redeemedDeals =>
      rows.where((deal) => deal.redemptions > 0).length;
}

/// What the venue's experiences did inside one window.
///
/// Only events that really took place count as held: a draft never went live
/// and a declined or cancelled event never seated anyone. Requested events are
/// counted separately, because they are a decision the venue still owes.
class ExperiencePerformance {
  const ExperiencePerformance({
    required this.held,
    required this.seatsBooked,
    required this.seatsTotal,
    required this.upcoming,
    required this.awaitingApproval,
    this.next,
  });

  factory ExperiencePerformance.of(
    List<PartnerExperience> rows, {
    required DateRange range,
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    final first = range.from;
    final last = range.to;
    bool inWindow(DateTime value) =>
        !value.isBefore(first) && value.isBefore(last);

    final held = rows
        .where(
          (row) =>
              inWindow(row.startAt) &&
              (row.status == ExperienceStatus.confirmed ||
                  row.status == ExperienceStatus.live ||
                  row.status == ExperienceStatus.completed),
        )
        .toList(growable: false);
    final upcoming = rows
        .where((row) => row.status.isUpcoming && row.startAt.isAfter(moment))
        .toList(growable: false)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return ExperiencePerformance(
      held: held,
      seatsBooked: held.fold(0, (sum, row) => sum + row.seatsBooked),
      seatsTotal: held.fold(0, (sum, row) => sum + row.seatsTotal),
      upcoming: upcoming.length,
      awaitingApproval: rows
          .where((row) => row.status == ExperienceStatus.requested)
          .length,
      next: upcoming.isEmpty ? null : upcoming.first,
    );
  }

  final List<PartnerExperience> held;
  final int seatsBooked;
  final int seatsTotal;
  final int upcoming;
  final int awaitingApproval;
  final PartnerExperience? next;

  /// Seats as a share of the rooms the held events put on sale, 0–1.
  double? get fillRate =>
      seatsTotal <= 0 ? null : (seatsBooked / seatsTotal).clamp(0.0, 1.0);

  String get fillRateLabel {
    final rate = fillRate;
    return rate == null ? '–' : '${(rate * 100).round()}%';
  }
}

/// The three latest bookings, newest first.
///
/// Ordered by when the guest booked, not by when they are coming: a
/// reservation made this morning for next Friday is today's activity, and
/// ordering by service time would hide it under last weekend's dinners.
List<Reservation> recentReservations(
  List<Reservation> rows, {
  int max = 3,
}) {
  final sorted = [...rows]..sort((a, b) {
      final left = a.createdAt ?? a.startAt;
      final right = b.createdAt ?? b.startAt;
      return right.compareTo(left);
    });
  return sorted.take(max).toList(growable: false);
}

/// ─── Header ────────────────────────────────────────────────────────────────

/// The identity block at the top of Insights.
///
/// It states whose numbers these are, what the screen answers, and which days
/// the window covers. The scope sentence is the important part: reservations
/// and experiences follow the chips, while QR scans and deal redemptions are
/// fixed totals, and a partner should learn that here rather than by comparing
/// two cards that were never meant to match.
class InsightsHeaderCard extends StatelessWidget {
  const InsightsHeaderCard({
    super.key,
    required this.venue,
    required this.windowLabel,
    required this.days,
  });

  final Venue? venue;
  final String windowLabel;
  final int days;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _VenueTile(venue: venue),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Insights',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'How DineCircle is bringing guests to your restaurant.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm + 2),
          // Two lines at a large text scale rather than one clipped line: this
          // sentence is where the window's scope is stated.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  scale >= 1.4
                      ? '$windowLabel · $days days\n'
                          'Reservations and experiences follow this window.'
                      : '$windowLabel · $days days · reservations and '
                          'experiences',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({required this.venue});

  final Venue? venue;

  @override
  Widget build(BuildContext context) {
    final logo = (venue?.logo ?? '').trim();
    final cover = (venue?.coverImage ?? '').trim();
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
        border: Border.all(color: AppColors.border),
      ),
      child: MediaImage(
        source: logo.isNotEmpty ? logo : cover,
        fallbackIcon: Icons.storefront,
      ),
    );
  }
}

/// ─── Range rail ────────────────────────────────────────────────────────────

/// The label for each preset id, in days.
const Map<String, int> _presetDays = {'7d': 7, '30d': 30, '90d': 90};

/// The three windows the API can answer for.
///
/// Kept to 7, 30 and 90 days on purpose: the reservation route takes any
/// instants, but the QR scan counters only exist for today, a week and a
/// month, so a longer list of choices would promise windows the screen could
/// not honour.
class InsightsRangeRail extends StatelessWidget {
  const InsightsRangeRail({
    super.key,
    required this.selectedId,
    required this.onSelect,
    this.horizontalInset = AppSpacing.paddingScreen,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.minTapTarget - 8,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalInset),
        children: [
          for (final preset in DateRange.presets().take(3))
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _RangeChip(
                // Named from the preset id, not from the instants: a daylight
                // saving change makes midnight-to-midnight 6d23h, and a
                // difference read in days would then say "6 days".
                label: '${_presetDays[preset.id] ?? 7} days',
                selected: preset.id == selectedId,
                onTap: () => onSelect(preset.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11.5,
                    letterSpacing: 0.1,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── KPI grid ──────────────────────────────────────────────────────────────

/// One figure above the fold.
///
/// The caption carries the period, because the four are not all measured over
/// the same stretch of time: reservations and experiences follow the window,
/// scan totals are fixed and deal redemptions are all time. A number without
/// its period is the misreading this screen exists to prevent.
class InsightsKpi {
  const InsightsKpi({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;
}

class InsightsKpiGrid extends StatelessWidget {
  const InsightsKpiGrid({super.key, required this.figures});

  final List<InsightsKpi> figures;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth >= 620 && scale < 1.6 ? 4 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < figures.length; i += columns) {
          final slice = figures.skip(i).take(columns).toList(growable: false);
          if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.sm));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: c < slice.length
                          ? _KpiTile(figure: slice[c])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.figure});

  final InsightsKpi figure;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${figure.label}: ${figure.value}. ${figure.caption}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              figure.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                figure.value,
                maxLines: 1,
                style: AppTextStyles.numericMedium.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              figure.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.1,
                color: AppColors.textTertiary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Section shell ─────────────────────────────────────────────────────────

/// One titled block with an optional doorway out.
///
/// Every section on Insights is the same shell at the same radius and padding,
/// so the screen reads as one document rather than six cards that each chose a
/// size. [action] is the detailed view: the main screen summarises, the section
/// hands the work back to the screen that owns it.
class InsightsSectionCard extends StatelessWidget {
  const InsightsSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 4,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  child: Text(
                    actionLabel!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          child,
        ],
      ),
    );
  }
}

/// A compact line inside a section: what is missing, or what a figure means.
class InsightsNote extends StatelessWidget {
  const InsightsNote(
    this.message, {
    super.key,
    this.icon = Icons.info_outline,
    this.tone,
  });

  final String message;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.textTertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// ─── Figures strip ─────────────────────────────────────────────────────────

class InsightsFigure {
  const InsightsFigure({required this.label, required this.value, this.hint});

  final String label;
  final String value;

  /// Shown instead of the label when a figure needs explaining.
  final String? hint;
}

/// Two or three figures in one hairline strip.
class InsightsFigureStrip extends StatelessWidget {
  const InsightsFigureStrip({super.key, required this.figures});

  final List<InsightsFigure> figures;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stacked = constraints.maxWidth < 300 || scale >= 1.5;
        final body = stacked
            ? Column(
                children: [
                  for (var i = 0; i < figures.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    _row(figures[i]),
                  ],
                ],
              )
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < figures.length; i++) ...[
                      if (i > 0) Container(width: 1, color: AppColors.border),
                      Expanded(child: _cell(figures[i])),
                    ],
                  ],
                ),
              );
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: body,
        );
      },
    );
  }

  Widget _cell(InsightsFigure figure) {
    return Semantics(
      label: '${figure.label}: ${figure.value}',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: AppSpacing.sm + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                figure.value,
                maxLines: 1,
                style: AppTextStyles.numericMedium.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              figure.hint ?? figure.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(InsightsFigure figure) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              figure.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            figure.value,
            style: AppTextStyles.numericMedium.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Reservation chart ─────────────────────────────────────────────────────

/// Booked reservations per day (or per week) for the selected window.
///
/// Drawn with layout rather than a canvas so the axis text is a real Text: it
/// follows the device's text scale, it can be thinned to the space available,
/// and a label never paints over its neighbour. The empty days are part of the
/// series, so a quiet Tuesday is a short bar, not a gap the line skips.
class ReservationTrendChart extends StatelessWidget {
  const ReservationTrendChart({
    super.key,
    required this.buckets,
    this.height = 132,
  });

  final List<TrendBucket> buckets;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();

    final scale = MediaQuery.textScalerOf(context).scale(1);
    final peak = buckets.fold<int>(0, (max, b) => b.value > max ? b.value : max);
    final ceiling = chartCeiling(peak);
    final busiest = buckets.reduce((a, b) => b.value > a.value ? b : a);
    final plotHeight = height - 12;
    // The day labels are real Text, so their box has to grow with the device's
    // text scale or a 2x label would paint outside its 14dp slot.
    final labelHeight = 14 * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final budget = (constraints.maxWidth / (52 * scale)).floor().clamp(2, 8);
        final ticks = axisTicks(buckets.length, budget).toSet();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busiest.value > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Busiest: ${busiest.describe} · ${busiest.value} '
                  '${busiest.value == 1 ? 'booking' : 'bookings'}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SizedBox(
              height: height,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 30,
                    child: _AxisLabels(ceiling: ceiling, plotHeight: plotHeight),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Stack(
                      children: [
                        for (final fraction in const [1.0, 0.5, 0.0])
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 6 + (1 - fraction) * plotHeight,
                            child: Container(
                              height: 1,
                              color: AppColors.border.withValues(
                                alpha: fraction == 0 ? 1 : 0.45,
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final bucket in buckets)
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: buckets.length > 20 ? 0.5 : 1.5,
                                      ),
                                      child: Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          width: double.infinity,
                                          height: bucket.value == 0
                                              ? 2
                                              : (bucket.value / ceiling) *
                                                    plotHeight,
                                          decoration: BoxDecoration(
                                            color: bucket.value == 0
                                                ? AppColors.borderLight
                                                : AppColors.primary,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                              top: Radius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < buckets.length; i++)
                        Expanded(
                          child: ticks.contains(i)
                              ? _AxisLabel(
                                  text: buckets[i].axisLabel,
                                  height: labelHeight,
                                  alignment: i == 0
                                      ? Alignment.centerLeft
                                      : i == buckets.length - 1
                                          ? Alignment.centerRight
                                          : Alignment.center,
                                )
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.ceiling, required this.plotHeight});

  final int ceiling;
  final double plotHeight;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.labelSmall.copyWith(
      fontSize: 9.5,
      fontWeight: FontWeight.w400,
      color: AppColors.textTertiary,
      height: 1,
    );
    return Stack(
      children: [
        for (final tick in axisLabels(ceiling))
          Positioned(
            right: 4,
            top: 6 + (1 - tick.fraction) * plotHeight - 5,
            child: Text(
              '${tick.value}',
              style: style,
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          ),
      ],
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({
    required this.text,
    required this.alignment,
    required this.height,
  });

  final String text;
  final Alignment alignment;
  final double height;

  @override
  Widget build(BuildContext context) {
    // An overflow box lets a two-character day label stay centred on its bar
    // even when the cell itself is narrower than the word, without the label
    // ever widening the row it lives in.
    return SizedBox(
      height: height,
      child: OverflowBox(
        // `minWidth: 0` is required: OverflowBox otherwise inherits the
        // incoming minimum, and a wide cell (127dp for seven daily bars) would
        // hand the Text a min wider than its 46dp max, which is invalid.
        minWidth: 0,
        maxWidth: 46,
        minHeight: 0,
        maxHeight: height,
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 9.5,
            fontWeight: FontWeight.w400,
            color: AppColors.textTertiary,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// ─── Deal rows ─────────────────────────────────────────────────────────────

/// The most-redeemed promotions, with the cap that makes the count readable.
///
/// Bars are scaled against the top deal so they can be compared with each
/// other; the cap is printed as text, because drawing one bar to its cap and
/// another to its own would put two different denominators side by side.
class DealRedemptionList extends StatelessWidget {
  const DealRedemptionList({
    super.key,
    required this.deals,
    this.maxRows = 3,
  });

  final List<Deal> deals;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final visible = deals.take(maxRows).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    final top = visible.first.redemptions <= 0 ? 1 : visible.first.redemptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm + 2),
          Builder(
            builder: (context) {
              final deal = visible[i];
              final cap = deal.maxRedemptions;
              final label = cap == null
                  ? '${deal.redemptions} used'
                  : '${deal.redemptions} of $cap';
              return Semantics(
                label: '${deal.title}: $label',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deal.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          label,
                          maxLines: 1,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      child: LinearProgressIndicator(
                        value: (deal.redemptions / top).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.10,
                        ),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// ─── Recent activity ───────────────────────────────────────────────────────

/// The latest bookings at this venue, at most [max] of them.
class RecentReservationList extends StatelessWidget {
  const RecentReservationList({
    super.key,
    required this.reservations,
    this.max = 3,
  });

  final List<Reservation> reservations;
  final int max;

  @override
  Widget build(BuildContext context) {
    final rows = reservations.take(max).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(height: 1, color: AppColors.border),
            ),
          _RecentRow(reservation: rows[i]),
        ],
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.reservation});

  final Reservation reservation;

  @override
  Widget build(BuildContext context) {
    final detail =
        '${reservation.partyLabel} · ${DisplayDate.day(reservation.startAt)}, '
        '${DisplayDate.time(reservation.startAt)}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final narrow = constraints.maxWidth < 300 || scale >= 1.5;
        final name = Text(
          reservation.guestName.isEmpty ? 'Guest' : reservation.guestName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        );
        final chip = StatusChip(
          status: reservation.status.wire,
          label: reservation.status.label,
          dense: true,
        );
        final caption = Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: narrow ? 34 : 30,
              margin: const EdgeInsets.only(top: 2, right: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: AppColors.forStatus(reservation.status.wire),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Expanded(
              child: narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: name),
                            const SizedBox(width: AppSpacing.sm),
                            chip,
                          ],
                        ),
                        const SizedBox(height: 2),
                        caption,
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: name),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              reservation.partyLabel,
                              maxLines: 1,
                              style: AppTextStyles.labelSmall.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            chip,
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DisplayDate.day(reservation.startAt)}, '
                          '${DisplayDate.time(reservation.startAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// ─── Loading ───────────────────────────────────────────────────────────────

/// The screen's first read, in the shape it will settle into.
class InsightsSkeleton extends StatelessWidget {
  const InsightsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingScreen,
        AppSpacing.md,
        AppSpacing.paddingScreen,
        AppSpacing.xl,
      ),
      children: [
        _bar(height: 92),
        const SizedBox(height: AppSpacing.sm + 4),
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: _bar(height: 84)),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: _bar(height: 84)),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _bar(height: 232),
        const SizedBox(height: AppSpacing.md),
        _bar(height: 150),
      ],
    );
  }

  Widget _bar({required double height}) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
  );
}

/// ─── Notices ───────────────────────────────────────────────────────────────

/// A compact in-card failure with the one action that retries it.
class InsightsReadError extends StatelessWidget {
  const InsightsReadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InlineNotice(
      message: message,
      kind: InlineNoticeKind.error,
      action: InlineNoticeAction(label: 'Try again', onTap: onRetry),
    );
  }
}

/// A compact "nothing measured here" line, sized for inside a section.
class InsightsPlaceholder extends StatelessWidget {
  const InsightsPlaceholder({
    super.key,
    required this.message,
    this.icon = Icons.insights_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
