import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/models/operations.dart';

/// The desk must only ever offer actions the server will accept, so the legal
/// transition table is a contract guard: an accidental edit here would let a
/// button render that the API answers with `409`. See plan module 7.
void main() {
  Reservation at(ReservationStatus status) => Reservation(
    id: 'r1',
    restaurantId: 'v1',
    guestName: 'Ada',
    partySize: 2,
    startAt: DateTime.utc(2026, 11, 1, 19),
    status: status,
  );

  group('kReservationTransitions', () {
    test('pending may be confirmed, cancelled, or marked no-show', () {
      expect(
        kReservationTransitions[ReservationStatus.pending],
        containsAll(<ReservationAction>[
          ReservationAction.confirm,
          ReservationAction.cancel,
          ReservationAction.noShow,
        ]),
      );
    });

    test('confirmed may seat, cancel, or mark no-show', () {
      expect(
        kReservationTransitions[ReservationStatus.confirmed],
        containsAll(<ReservationAction>[
          ReservationAction.seat,
          ReservationAction.cancel,
          ReservationAction.noShow,
        ]),
      );
    });

    test('a seated party may only be completed', () {
      expect(
        kReservationTransitions[ReservationStatus.seated],
        [ReservationAction.complete],
      );
    });

    test('terminal statuses expose no actions', () {
      for (final status in const [
        ReservationStatus.completed,
        ReservationStatus.cancelled,
        ReservationStatus.noShow,
      ]) {
        expect(kReservationTransitions[status], isEmpty, reason: '$status');
      }
    });

    test('every status has an entry so the board never reads null', () {
      for (final status in ReservationStatus.values) {
        expect(kReservationTransitions.containsKey(status), isTrue);
        expect(at(status).allowedActions, kReservationTransitions[status]);
      }
    });
  });

  group('ReservationAction', () {
    test('paths match the URL segments the partner route expects', () {
      // The one that is easy to get wrong: the server route is `no-show`.
      expect(ReservationAction.noShow.path, 'no-show');
      expect(ReservationAction.confirm.path, 'confirm');
      expect(ReservationAction.seat.path, 'seat');
      expect(ReservationAction.complete.path, 'complete');
      expect(ReservationAction.cancel.path, 'cancel');
    });

    test('targets are the statuses the server moves the row to', () {
      expect(ReservationAction.confirm.target, ReservationStatus.confirmed);
      expect(ReservationAction.seat.target, ReservationStatus.seated);
      expect(ReservationAction.complete.target, ReservationStatus.completed);
      expect(ReservationAction.cancel.target, ReservationStatus.cancelled);
      expect(ReservationAction.noShow.target, ReservationStatus.noShow);
    });
  });

  group('ReservationStatus', () {
    test('wire value for no-show is the snake-case token', () {
      expect(ReservationStatus.noShow.wire, 'no_show');
      expect(ReservationStatus.parse('no_show'), ReservationStatus.noShow);
    });

    test('an unknown status falls back to pending rather than throwing', () {
      expect(ReservationStatus.parse('garbage'), ReservationStatus.pending);
      expect(ReservationStatus.parse(null), ReservationStatus.pending);
    });

    test('holdsCovers covers the three states that occupy a slot', () {
      expect(ReservationStatus.pending.holdsCovers, isTrue);
      expect(ReservationStatus.confirmed.holdsCovers, isTrue);
      expect(ReservationStatus.seated.holdsCovers, isTrue);
      expect(ReservationStatus.completed.holdsCovers, isFalse);
      expect(ReservationStatus.cancelled.holdsCovers, isFalse);
      expect(ReservationStatus.noShow.holdsCovers, isFalse);
    });
  });

  group('Reservation', () {
    test('isPhoneIn recognises desk-taken bookings', () {
      Reservation withSource(String source) => Reservation(
        id: 'r1',
        restaurantId: 'v1',
        guestName: 'Ada',
        partySize: 2,
        startAt: DateTime.utc(2026, 11, 1, 19),
        status: ReservationStatus.pending,
        source: source,
      );
      expect(withSource('partner').isPhoneIn, isTrue);
      expect(withSource('phone').isPhoneIn, isTrue);
      expect(withSource('guest').isPhoneIn, isFalse);
    });

    test('endTime falls back to start plus duration when no endsAt', () {
      final start = DateTime.utc(2026, 11, 1, 19);
      final r = Reservation(
        id: 'r1',
        restaurantId: 'v1',
        guestName: 'Ada',
        partySize: 2,
        startAt: start,
        status: ReservationStatus.pending,
        durationMinutes: 90,
      );
      expect(r.endTime, start.add(const Duration(minutes: 90)));

      final explicit = DateTime.utc(2026, 11, 1, 21, 30);
      expect(
        Reservation(
          id: 'r1',
          restaurantId: 'v1',
          guestName: 'Ada',
          partySize: 2,
          startAt: start,
          status: ReservationStatus.pending,
          endsAt: explicit,
        ).endTime,
        explicit,
      );
    });
  });
}
