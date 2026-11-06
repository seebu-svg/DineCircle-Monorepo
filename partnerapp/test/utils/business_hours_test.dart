import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/utils/business_hours.dart';

/// Builds a week where every day shares the same configuration, so the tests
/// assert the open/closed logic independent of which weekday they run on.
OpeningHours _everyDay({bool closed = false, List<HoursWindow> windows = const []}) {
  final day = DayHours(closed: closed, windows: windows);
  return OpeningHours({for (final k in OpeningHours.weekdayKeys) k: day});
}

DateTime _at(int hour, int minute) => DateTime(2026, 11, 3, hour, minute);

void main() {
  group('BusinessHoursStatus.evaluate', () {
    test('no hours configured is notConfigured, never a fake "open"', () {
      final status = BusinessHoursStatus.evaluate(
        hours: OpeningHours.empty(),
        serviceDay: _at(12, 0),
        clock: _at(12, 0),
      );
      expect(status.status, VenueOpenStatus.notConfigured);
      expect(status.isConfigured, isFalse);
    });

    test('inside a window is open and names the closing time', () {
      final status = BusinessHoursStatus.evaluate(
        hours: _everyDay(windows: [HoursWindow(open: '09:00', close: '22:00')]),
        serviceDay: _at(13, 30),
        clock: _at(13, 30),
      );
      expect(status.status, VenueOpenStatus.open);
      expect(status.detail, 'Open until 22:00');
    });

    test('before today\'s window closes as "Opens at"', () {
      final status = BusinessHoursStatus.evaluate(
        hours: _everyDay(windows: [HoursWindow(open: '12:00', close: '22:00')]),
        serviceDay: _at(9, 0),
        clock: _at(9, 0),
      );
      expect(status.status, VenueOpenStatus.closed);
      expect(status.detail, 'Opens at 12:00');
    });

    test('after every window closes as "Closed now"', () {
      final status = BusinessHoursStatus.evaluate(
        hours: _everyDay(windows: [HoursWindow(open: '09:00', close: '17:00')]),
        serviceDay: _at(20, 0),
        clock: _at(20, 0),
      );
      expect(status.status, VenueOpenStatus.closed);
      expect(status.detail, 'Closed now');
    });

    test('a closed trading day reports "Closed today"', () {
      final status = BusinessHoursStatus.evaluate(
        hours: _everyDay(closed: true),
        serviceDay: _at(12, 0),
        clock: _at(12, 0),
      );
      expect(status.status, VenueOpenStatus.closed);
      expect(status.detail, 'Closed today');
    });

    test('an overnight window is open across midnight', () {
      final status = BusinessHoursStatus.evaluate(
        hours: _everyDay(windows: [HoursWindow(open: '18:00', close: '02:00')]),
        serviceDay: _at(1, 0),
        clock: _at(1, 0),
      );
      expect(status.status, VenueOpenStatus.open);
    });

    test('picks the nearest upcoming of several windows', () {
      final status = BusinessHoursStatus.evaluate(
        hours: _everyDay(windows: [
          HoursWindow(open: '08:00', close: '10:00'),
          HoursWindow(open: '16:00', close: '18:00'),
        ]),
        serviceDay: _at(11, 0),
        clock: _at(11, 0),
      );
      expect(status.status, VenueOpenStatus.closed);
      expect(status.detail, 'Opens at 16:00');
    });
  });

  group('greetingFor', () {
    test('splits the day into morning / afternoon / evening', () {
      expect(greetingFor(DateTime(2026, 11, 3, 8)), 'Good morning');
      expect(greetingFor(DateTime(2026, 11, 3, 14)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 11, 3, 20)), 'Good evening');
    });
  });
}
