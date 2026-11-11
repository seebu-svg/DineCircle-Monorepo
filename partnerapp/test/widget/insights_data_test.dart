import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/models/experience.dart';
import 'package:partnerapp/models/operations.dart';
import 'package:partnerapp/screens/business/insights_widgets.dart';
import 'package:partnerapp/utils/date_time.dart';

/// The date arithmetic behind every Insights card, checked away from the
/// widget tree so a wrong boundary is attributed to the calculation and not to
/// a layout.
///
/// The clock is fixed at 15:30 on 11 Nov 2026: a mid-afternoon moment, so a
/// window that started or ended at the wrong hour would be visible.
DateTime _clock() => DateTime(2026, 11, 11, 15, 30);

DateTime _dayFromNow(int offset, [int hour = 19]) {
  final today = ServiceDate.startOfDay(_clock());
  return DateTime(today.year, today.month, today.day + offset, hour);
}

Reservation _booking(
  DateTime startAt, {
  String id = 'r1',
  String guest = 'Guest',
  ReservationStatus status = ReservationStatus.confirmed,
  DateTime? createdAt,
}) =>
    Reservation(
      id: id,
      restaurantId: 'v1',
      guestName: guest,
      partySize: 2,
      startAt: startAt,
      status: status,
      createdAt: createdAt,
    );

PartnerExperience _experience(
  DateTime startAt, {
  String id = 'e1',
  ExperienceStatus status = ExperienceStatus.confirmed,
  int seatsBooked = 18,
  int seatsTotal = 24,
}) =>
    PartnerExperience(
      id: id,
      title: 'Chef’s Table',
      restaurantName: 'Sea & Salt',
      restaurantId: 'v1',
      startAt: startAt,
      seatsTotal: seatsTotal,
      seatsBooked: seatsBooked,
      pricePerSeat: 4500,
      status: status,
      type: ExperienceType.dinner,
    );

void main() {
  group('presets', () {
    test('each preset covers exactly its own calendar days, ending today', () {
      for (final days in {7, 30, 90}) {
        final range = DateRange.preset('${days}d', _clock());
        final today = ServiceDate.startOfDay(_clock());
        expect(
          range.from,
          ServiceDate.addDays(today, -(days - 1)),
          reason: '${days}d starts on the first covered day',
        );
        expect(
          range.to,
          ServiceDate.addDays(today, 1),
          reason: '${days}d ends at midnight after today',
        );
        expect(
          range.to.difference(range.from).inHours,
          greaterThanOrEqualTo((days - 1) * 24),
        );
      }
    });

    test('the last covered day is the one before the exclusive end', () {
      final range = DateRange.preset('7d', _clock());
      expect(insightsLastDay(range), ServiceDate.startOfDay(_clock()));
      expect(insightsWindowLabel(range), '5 Nov – 11 Nov');
    });

    test('a window crossing new year names both years', () {
      final range = DateRange(
        id: 'x',
        label: 'Custom',
        from: DateTime(2026, 12, 30),
        to: DateTime(2027, 1, 2),
      );
      expect(insightsWindowLabel(range), '30 Dec 2026 – 1 Jan 2027');
    });
  });

  group('reservation buckets', () {
    test('7 days is one bucket per day, today last', () {
      final buckets = reservationBuckets(
        [
          _booking(_dayFromNow(0)),
          _booking(_dayFromNow(0), id: 'r2'),
          _booking(_dayFromNow(-6)),
          // Outside the window: the day before it starts, and the next day.
          _booking(_dayFromNow(-7)),
          _booking(_dayFromNow(1)),
        ],
        days: 7,
        now: _clock(),
      );

      expect(buckets, hasLength(7));
      expect(buckets.last.end, ServiceDate.startOfDay(_clock()));
      expect(buckets.first.start, ServiceDate.addDays(_dayFromNow(0), -6));
      expect(buckets.last.value, 2, reason: 'today holds two bookings');
      expect(buckets.first.value, 1, reason: 'six days ago holds one');
      expect(buckets.fold<int>(0, (sum, b) => sum + b.value), 3);
      expect(buckets.last.axisLabel, isNotEmpty);
    });

    test('30 days is one bucket per day and adds up to the window', () {
      final rows = [
        for (var i = 0; i < 30; i++) _booking(_dayFromNow(-i), id: 'r$i'),
        _booking(_dayFromNow(-30), id: 'outside'),
      ];
      final buckets =
          reservationBuckets(rows, days: 30, now: _clock());

      expect(buckets, hasLength(30));
      expect(buckets.fold<int>(0, (sum, b) => sum + b.value), 30);
      expect(buckets.every((b) => b.value == 1), isTrue);
      expect(buckets.last.end, ServiceDate.startOfDay(_clock()));
    });

    test('90 days groups into weeks that still cover every day once', () {
      final rows = [
        for (var i = 0; i < 90; i++) _booking(_dayFromNow(-i), id: 'r$i'),
        _booking(_dayFromNow(-90), id: 'outside'),
        _booking(_dayFromNow(1), id: 'tomorrow'),
      ];
      final buckets =
          reservationBuckets(rows, days: 90, now: _clock());

      expect(buckets, hasLength(13));
      expect(
        buckets.fold<int>(0, (sum, b) => sum + b.value),
        90,
        reason: 'every booking inside the window is counted once',
      );
      expect(
        buckets.first.start,
        ServiceDate.addDays(_dayFromNow(0), -89),
        reason: 'the first partial week is clamped to the window',
      );
      expect(buckets.last.end, ServiceDate.startOfDay(_clock()));
      for (final bucket in buckets) {
        expect(
          ServiceDate.daysBetween(bucket.start, bucket.end),
          lessThanOrEqualTo(6),
        );
        expect(bucket.start.isAfter(bucket.end), isFalse);
      }
    });

    test('a zero-day window draws nothing instead of dividing by zero', () {
      expect(reservationBuckets(const [], days: 0), isEmpty);
    });
  });

  group('experience window', () {
    test('a booking at the exclusive end belongs to the next window', () {
      final range = DateRange.preset('7d', _clock());
      final performance = ExperiencePerformance.of(
        [
          // Exactly the first instant of the window: included.
          _experience(range.from, id: 'at-from'),
          // Exactly the end instant: that is tomorrow, so excluded.
          _experience(
            range.to,
            id: 'at-to',
            status: ExperienceStatus.completed,
          ),
          _experience(_dayFromNow(-2), id: 'inside', seatsBooked: 10),
          _experience(
            _dayFromNow(-3),
            id: 'cancelled',
            status: ExperienceStatus.cancelled,
          ),
          _experience(_dayFromNow(20), id: 'upcoming'),
          _experience(
            _dayFromNow(21),
            id: 'requested',
            status: ExperienceStatus.requested,
          ),
        ],
        range: range,
        now: _clock(),
      );

      expect(performance.held.map((e) => e.id), ['at-from', 'inside']);
      expect(performance.seatsBooked, 28);
      expect(performance.seatsTotal, 48);
      expect(performance.fillRateLabel, '58%');
      expect(performance.upcoming, 2, reason: 'confirmed and requested ahead');
      expect(performance.awaitingApproval, 1);
      expect(performance.next?.id, 'upcoming');
    });

    test('a quarter catches experiences the week does not', () {
      final seven = ExperiencePerformance.of(
        [_experience(_dayFromNow(-45))],
        range: DateRange.preset('7d', _clock()),
        now: _clock(),
      );
      final ninety = ExperiencePerformance.of(
        [_experience(_dayFromNow(-45))],
        range: DateRange.preset('90d', _clock()),
        now: _clock(),
      );

      expect(seven.held, isEmpty);
      expect(seven.fillRateLabel, '–', reason: 'no rooms sold, so no rate');
      expect(ninety.held, hasLength(1));
      expect(ninety.fillRateLabel, '75%');
    });
  });

  group('reservation window', () {
    test('trims the booking that sits on the exclusive end', () {
      final from = ServiceDate.startOfDay(_clock());
      final to = ServiceDate.addDays(from, 1);
      final window = ReservationWindow(
        reservations: [
          _booking(from.add(const Duration(hours: 10))),
          _booking(to, id: 'tomorrow'),
        ],
        total: 2,
      );

      final trimmed = window.clampedTo(from, to);
      expect(trimmed.reservations.map((r) => r.id), ['r1']);
      expect(trimmed.total, 1);
      expect(trimmed.truncated, isFalse);
    });

    test('keeps the server total honest when a page was also truncated', () {
      final from = ServiceDate.startOfDay(_clock());
      final to = ServiceDate.addDays(from, 1);
      final trimmed = ReservationWindow(
        reservations: [
          _booking(from.add(const Duration(hours: 10))),
          _booking(to, id: 'tomorrow'),
        ],
        total: 5,
      ).clampedTo(from, to);

      expect(trimmed.reservations, hasLength(1));
      expect(trimmed.total, 4, reason: 'the trimmed row leaves the count too');
      expect(trimmed.truncated, isTrue);
    });

    test('leaves an already-correct window untouched', () {
      final from = ServiceDate.startOfDay(_clock());
      final to = ServiceDate.addDays(from, 1);
      final window = ReservationWindow(
        reservations: [_booking(from.add(const Duration(hours: 19)))],
        total: 1,
      );

      expect(identical(window.clampedTo(from, to), window), isTrue);
    });

    test('recent activity is ordered by when the guest booked', () {
      final rows = [
        _booking(
          _dayFromNow(-4),
          id: 'old-booking',
          guest: 'Old',
          createdAt: _dayFromNow(-4, 9),
        ),
        _booking(
          _dayFromNow(-1),
          id: 'new-booking',
          guest: 'New',
          createdAt: _dayFromNow(-1, 20),
        ),
        // Booked this morning for next Friday: today's activity, not deferred.
        _booking(
          _dayFromNow(3),
          id: 'future-booking',
          guest: 'Fresh',
          createdAt: _dayFromNow(0, 8),
        ),
        _booking(
          _dayFromNow(-2),
          id: 'middle',
          guest: 'Middle',
          createdAt: _dayFromNow(-2, 12),
        ),
      ];

      expect(
        recentReservations(rows).map((r) => r.guestName),
        ['Fresh', 'New', 'Middle'],
      );
      expect(recentReservations(rows, max: 1).single.id, 'future-booking');
    });
  });
}
