import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/models/deals.dart';

void main() {
  Deal build({
    DealStatus status = DealStatus.draft,
    DealKind kind = DealKind.percent,
    double value = 20,
    DateTime? startsAt,
    DateTime? endsAt,
  }) => Deal(
    id: 'd1',
    restaurantId: 'v1',
    title: 'Weeknight Special',
    kind: kind,
    value: value,
    status: status,
    startsAt: startsAt ?? DateTime.now().subtract(const Duration(days: 1)),
    endsAt: endsAt ?? DateTime.now().add(const Duration(days: 7)),
  );

  group('lifecycle transitions mirror the server', () {
    test('draft may go live or be expired', () {
      expect(
        build().allowedTransitions,
        containsAll([DealStatus.active, DealStatus.expired]),
      );
    });
    test('active may pause or expire', () {
      expect(
        build(status: DealStatus.active).allowedTransitions,
        containsAll([DealStatus.paused, DealStatus.expired]),
      );
    });
    test('expired is terminal', () {
      expect(build(status: DealStatus.expired).allowedTransitions, isEmpty);
    });
  });

  group('delete vs retire', () {
    test('only a draft is truly deletable', () {
      expect(build(status: DealStatus.draft).isDeleteable, isTrue);
      expect(build(status: DealStatus.active).isDeleteable, isFalse);
    });
    test('the button label reflects the behaviour', () {
      expect(
        build(status: DealStatus.draft).deleteBehaviourLabel,
        'Delete draft',
      );
      expect(
        build(status: DealStatus.active).deleteBehaviourLabel,
        contains('Retire'),
      );
    });
  });

  test('isLive is active and not yet past the end', () {
    expect(build(status: DealStatus.active).isLive, isTrue);
    final past = build(
      status: DealStatus.active,
      endsAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(past.hasPassed, isTrue);
    expect(past.isLive, isFalse);
  });

  group('display labels', () {
    test('percent renders without cents, money with cents', () {
      expect(build(kind: DealKind.percent, value: 20).valueLabel, '20% off');
      expect(build(kind: DealKind.fixed, value: 5).valueLabel, '5.00 off');
    });
  });

  test(
    'missing redemption count is unavailable rather than fabricated zero',
    () {
      final missing = Deal.fromJson({'id': 'd'});
      expect(missing.redemptionLabel, 'Redemptions unavailable');
      final counted = Deal.fromJson({'id': 'd', 'redemptions': 0});
      expect(counted.redemptionLabel, '0 used · no cap');
    },
  );

  test('scheduled active deals are not live before their start', () {
    final scheduled = Deal(
      id: 's',
      restaurantId: 'v',
      title: 'Scheduled',
      kind: DealKind.percent,
      value: 10,
      status: DealStatus.active,
      startsAt: DateTime.now().add(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 2)),
    );
    expect(scheduled.isLive, isFalse);
    expect(scheduled.isScheduled, isTrue);
  });

  group('wire parsing', () {
    test('unknown values fall back safely', () {
      expect(DealStatus.parse('nope'), DealStatus.draft);
      expect(DealKind.parse('nope'), DealKind.percent);
    });
    test('known values round-trip through wire', () {
      expect(DealStatus.parse(DealStatus.active.wire), DealStatus.active);
      expect(DealKind.parse(DealKind.package.wire), DealKind.package);
    });
  });
}
