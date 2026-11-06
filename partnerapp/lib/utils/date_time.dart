import 'package:intl/intl.dart';

/// Service-day keys.
///
/// The partner reservation and availability endpoints take `?date=YYYY-MM-DD`,
/// and the server resolves "today" in the *venue's* timezone (the dashboard
/// returns `today.date` / `today.timeZone`). The app therefore never computes a
/// service day from the device clock: it takes the server's day and walks it
/// with plain calendar arithmetic.
class ServiceDate {
  ServiceDate._();

  static final DateFormat _key = DateFormat('yyyy-MM-dd');

  /// `2026-11-01` — the wire form for `?date=`.
  static String key(DateTime day) => _key.format(day);

  /// Parses a service-day key. A bad or empty key falls back to today (local),
  /// which keeps a screen usable while its dashboard header is still loading.
  static DateTime parse(String? value) {
    if (value == null || value.isEmpty) return startOfDay(DateTime.now());
    final parsed = DateTime.tryParse(value);
    return parsed == null ? startOfDay(DateTime.now()) : startOfDay(parsed);
  }

  static DateTime startOfDay(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static DateTime addDays(DateTime day, int days) =>
      startOfDay(day.add(Duration(days: days)));

  static DateTime monthStart(DateTime day) => DateTime(day.year, day.month);

  /// Inclusive calendar-day distance, used by "3 days ago" style captions.
  static int daysBetween(DateTime from, DateTime to) =>
      startOfDay(to).difference(startOfDay(from)).inDays;

  static bool isToday(DateTime day) =>
      startOfDay(day) == startOfDay(DateTime.now());
}

/// Preset ranges for earnings and analytics (`?from=&to=` are ISO instants).
class DateRange {
  const DateRange({
    required this.id,
    required this.label,
    required this.from,
    required this.to,
  });

  final String id;
  final String label;
  final DateTime from;
  final DateTime to;

  String get fromIso => from.toUtc().toIso8601String();
  String get toIso => to.toUtc().toIso8601String();

  static List<DateRange> presets([DateTime? now]) {
    final end = now ?? DateTime.now();
    final today = ServiceDate.startOfDay(end);
    final endOfDay = today.add(const Duration(days: 1));
    return [
      DateRange(
        id: '7d',
        label: 'Last 7 days',
        from: today.subtract(const Duration(days: 6)),
        to: endOfDay,
      ),
      DateRange(
        id: '30d',
        label: 'Last 30 days',
        from: today.subtract(const Duration(days: 29)),
        to: endOfDay,
      ),
      DateRange(
        id: '90d',
        label: 'Last 90 days',
        from: today.subtract(const Duration(days: 89)),
        to: endOfDay,
      ),
      DateRange(
        id: 'mtd',
        label: 'Month to date',
        from: ServiceDate.monthStart(today),
        to: endOfDay,
      ),
    ];
  }

  static DateRange preset(String id, [DateTime? now]) =>
      presets(now).firstWhere((r) => r.id == id, orElse: () => presets(now)[1]);
}

/// Display formatting shared by every screen.
class DisplayDate {
  DisplayDate._();

  static final DateFormat _weekday = DateFormat('EEE d MMM');
  static final DateFormat _weekdayLong = DateFormat('EEEE d MMMM');
  static final DateFormat _monthDay = DateFormat('d MMM');
  static final DateFormat _full = DateFormat('d MMM yyyy');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _month = DateFormat('MMM yyyy');

  static String day(DateTime value) => _weekday.format(value);
  static String dayLong(DateTime value) => _weekdayLong.format(value);
  static String monthDay(DateTime value) => _monthDay.format(value);
  static String full(DateTime value) => _full.format(value);
  static String month(DateTime value) => _month.format(value);
  static String time(DateTime value) => _time.format(value);

  static String timeRange(DateTime start, DateTime? end) {
    if (end == null) return time(start);
    return '${time(start)} – ${time(end)}';
  }

  static String dateTime(DateTime value) =>
      '${_weekday.format(value)}, ${time(value)}';

  /// Compact "just now / 12 min ago / 3 h ago / Yesterday / 4 Nov" caption used
  /// under every list row so the desk can tell what is stale.
  static String relative(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.isNegative) {
      return 'in ${_shortSpan(diff.abs())}';
    }
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (ServiceDate.daysBetween(value, now) == 1) return 'Yesterday';
    if (ServiceDate.daysBetween(value, now) < 7) {
      return _weekday.format(value);
    }
    return _monthDay.format(value);
  }

  static String _shortSpan(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    return '${d.inDays} d';
  }
}
