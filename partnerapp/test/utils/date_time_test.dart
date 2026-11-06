import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/utils/date_time.dart';

void main() {
  group('ServiceDate', () {
    test('key() emits the wire ?date= form', () {
      expect(ServiceDate.key(DateTime(2026, 11, 1)), '2026-11-01');
      expect(ServiceDate.key(DateTime(2026, 1, 9)), '2026-01-09');
    });

    test('parse() normalises to start of day and survives junk', () {
      expect(ServiceDate.parse('2026-11-01'), DateTime(2026, 11, 1));
      expect(ServiceDate.parse(''), isA<DateTime>());
      expect(ServiceDate.parse(null).hour, 0);
    });

    test('addDays walks calendar days across a month boundary', () {
      expect(
        ServiceDate.addDays(DateTime(2026, 1, 31), 1),
        DateTime(2026, 2, 1),
      );
    });

    test('daysBetween is an inclusive day count, time-of-day ignored', () {
      expect(
        ServiceDate.daysBetween(
          DateTime(2026, 3, 1, 23, 59),
          DateTime(2026, 3, 4, 0, 1),
        ),
        3,
      );
    });

    test('monthStart clamps to the first of the month', () {
      expect(ServiceDate.monthStart(DateTime(2026, 7, 19)), DateTime(2026, 7, 1));
    });
  });

  group('DateRange presets', () {
    // A fixed reference instant keeps the assertions deterministic.
    final now = DateTime(2026, 11, 15, 13, 30);
    final byId = {for (final r in DateRange.presets(now)) r.id: r};

    test('exposes exactly the four agreed presets', () {
      expect(byId.keys, ['7d', '30d', '90d', 'mtd']);
    });

    test('7d spans seven service days ending tomorrow-exclusive', () {
      expect(byId['7d']!.from, DateTime(2026, 11, 9));
      expect(byId['7d']!.to, DateTime(2026, 11, 16));
    });

    test('mtd starts on the first of the month', () {
      expect(byId['mtd']!.from, DateTime(2026, 11, 1));
    });

    test('ISO bounds are UTC for the ?from=&to= query', () {
      expect(byId['7d']!.fromIso.endsWith('Z'), isTrue);
      expect(byId['7d']!.toIso.endsWith('Z'), isTrue);
    });

    test('preset() falls back to 30d for an unknown id', () {
      expect(DateRange.preset('nope', now).id, '30d');
    });
  });
}
