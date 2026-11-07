import '../models/venue.dart';

/// Whether a venue is trading right now, derived only from its *configured*
/// weekly hours. There is no live-status column on the server, so this is a
/// pure read of `opening_hours`, it never invents an "open" state the desk has
/// not actually configured.
enum VenueOpenStatus { open, closed, notConfigured }

/// The result of evaluating a venue's hours against the current service day and
/// clock, with a short human line ("Open until 22:00", "Opens at 18:00").
class BusinessHoursStatus {
  const BusinessHoursStatus(this.status, {this.detail = ''});

  final VenueOpenStatus status;

  /// A one-line operational note beside the open/closed pill. Empty when there
  /// is nothing truthful to add.
  final String detail;

  bool get isOpen => status == VenueOpenStatus.open;
  bool get isConfigured => status != VenueOpenStatus.notConfigured;

  /// Server weekday order matches [OpeningHours.weekdayKeys]: `mon … sun`, and
  /// `DateTime.weekday` is 1 = Monday … 7 = Sunday.
  static const List<String> _dayKeys = OpeningHours.weekdayKeys;

  /// [serviceDay] is the venue's *service date* from the server (its weekday
  /// decides which day's hours apply); [clock] is the local wall clock used only
  /// for the time-of-day comparison. A desk device sits in the venue's timezone,
  /// so its clock is the trading clock; the date is still taken from the server
  /// rather than the device (see the service-day rule).
  static BusinessHoursStatus evaluate({
    required OpeningHours hours,
    required DateTime serviceDay,
    required DateTime clock,
  }) {
    if (hours.isEmpty) {
      return const BusinessHoursStatus(
        VenueOpenStatus.notConfigured,
        detail: 'Opening hours not set',
      );
    }

    final key = _dayKeys[(serviceDay.weekday - 1).clamp(0, 6)];
    final day = hours.day(key);
    if (!day.isConfigured) {
      return const BusinessHoursStatus(
        VenueOpenStatus.notConfigured,
        detail: 'Hours not set for today',
      );
    }
    if (day.closed) {
      return const BusinessHoursStatus(
        VenueOpenStatus.closed,
        detail: 'Closed today',
      );
    }

    final now = clock.hour * 60 + clock.minute;
    int? nextOpening;
    for (final window in day.windows) {
      final open = _toMinutes(window.open);
      final close = _toMinutes(window.close);
      if (open == null || close == null) continue;
      final inside = close <= open
          // Overnight window (e.g. 18:00–02:00): open at/after `open` or before `close`.
          ? (now >= open || now < close)
          : (now >= open && now < close);
      if (inside) {
        return BusinessHoursStatus(
          VenueOpenStatus.open,
          detail: 'Open until ${window.close}',
        );
      }
      if (open > now && (nextOpening == null || open < nextOpening)) {
        nextOpening = open;
      }
    }

    return BusinessHoursStatus(
      VenueOpenStatus.closed,
      detail: nextOpening != null
          ? 'Opens at ${_fromMinutes(nextOpening)}'
          : 'Closed now',
    );
  }

  static int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static String _fromMinutes(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

/// A time-of-day greeting for the welcome header. Uses the local clock, which on
/// a partner device is the venue's trading clock.
String greetingFor(DateTime clock) {
  final hour = clock.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
