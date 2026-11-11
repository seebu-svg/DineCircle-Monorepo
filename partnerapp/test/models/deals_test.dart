import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/models/deals.dart';

void main() {
  Deal build({
    DealStatus status = DealStatus.draft,
    DealKind kind = DealKind.percent,
    double value = 20,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxRedemptions,
    int redemptions = 0,
    bool redemptionsReported = true,
    String title = 'Weeknight Special',
    String description = '',
    String? code,
    String terms = '',
    String imageUrl = '',
  }) => Deal(
    id: 'd1',
    restaurantId: 'v1',
    title: title,
    description: description,
    kind: kind,
    value: value,
    status: status,
    startsAt: startsAt ?? DateTime.now().subtract(const Duration(days: 1)),
    endsAt: endsAt ?? DateTime.now().add(const Duration(days: 7)),
    maxRedemptions: maxRedemptions,
    redemptions: redemptions,
    redemptionsReported: redemptionsReported,
    code: code,
    terms: terms,
    imageUrl: imageUrl,
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
    test('percent keeps the percentage, without trailing cents', () {
      expect(build(kind: DealKind.percent, value: 20).valueLabel, '20% off');
      expect(build(kind: DealKind.percent, value: 12.5).valueLabel, '12.5% off');
    });

    test('money reads in rupees, not as a bare decimal', () {
      // The old label was "750.00 off": no currency, two decimals nobody uses
      // on a Pakistani menu, and the exact text the master prompt flagged.
      final fixed = build(kind: DealKind.fixed, value: 750);
      expect(fixed.valueLabel, 'Rs. 750 off');
      expect(
        build(kind: DealKind.fixed, value: 1250).valueLabel,
        'Rs. 1,250 off',
      );
    });

    test('a package states its price rather than a discount', () {
      final package = build(kind: DealKind.package, value: 2999);
      expect(package.valueLabel, 'Rs. 2,999');
      expect(package.valueLabel, isNot(contains('off')));
    });

    test('the mechanic is named beside the headline figure', () {
      expect(
        build(kind: DealKind.percent).mechanicLabel,
        'Percentage discount',
      );
      expect(build(kind: DealKind.fixed).mechanicLabel, 'Fixed amount off');
      expect(build(kind: DealKind.package).mechanicLabel, 'Set package price');
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

    test('the partner payload carries conditions and the cover photo', () {
      final deal = Deal.fromJson({
        'id': 'd',
        'restaurantId': 'v',
        'title': 'Lunch',
        'kind': 'percent',
        'value': 20,
        'status': 'active',
        'startsAt': '2026-11-01T00:00:00.000Z',
        'endsAt': '2026-11-30T00:00:00.000Z',
        'terms': 'Mon–Fri, 12:00–15:00. How to redeem: show this offer.',
        'imageUrl': '/public/venue-images/abc',
        'redemptions': 4,
        'maxRedemptions': 10,
      });
      expect(deal.terms, startsWith('Mon–Fri'));
      expect(deal.imageUrl, '/public/venue-images/abc');
      expect(deal.redemptionLabel, '4 / 10 used');
    });

    test('absent optional text is empty, never null', () {
      final deal = Deal.fromJson({'id': 'd'});
      expect(deal.terms, '');
      expect(deal.imageUrl, '');
    });
  });

  group('redemption limits', () {
    test('an uncapped deal has no remaining figure and is redeemable', () {
      final deal = build(status: DealStatus.active);
      expect(deal.redemptionsLeft, isNull);
      expect(deal.isLimitReached, isFalse);
      expect(deal.redemptionProgress, isNull);
      expect(deal.isRedeemable, isTrue);
    });

    test('the remaining count is the cap minus what was used', () {
      final deal = build(
        status: DealStatus.active,
        maxRedemptions: 10,
        redemptions: 4,
      );
      expect(deal.redemptionsLeft, 6);
      expect(deal.redemptionProgress, 0.4);
      expect(deal.isRedeemable, isTrue);
    });

    test('a fully used deal is not redeemable and clamps at zero', () {
      final deal = build(
        status: DealStatus.active,
        maxRedemptions: 5,
        redemptions: 5,
      );
      expect(deal.redemptionsLeft, 0);
      expect(deal.isLimitReached, isTrue);
      expect(deal.isRedeemable, isFalse);
      expect(deal.redemptionProgress, 1.0);

      // A ledger drift must not paint a negative bar.
      final overshot = build(
        status: DealStatus.active,
        maxRedemptions: 5,
        redemptions: 7,
      );
      expect(overshot.redemptionsLeft, 0);
      expect(overshot.redemptionProgress, 1.0);
    });

    test('the redeem button agrees with the route guard', () {
      // Mirrors `WHERE status = 'active' AND starts_at <= now() AND ends_at >
      // now()` on `POST …/deals/:id/redeem`.
      expect(build().isRedeemable, isFalse, reason: 'a draft is not live');
      expect(
        build(status: DealStatus.paused).isRedeemable,
        isFalse,
        reason: 'a paused deal is hidden',
      );
      expect(
        build(
          status: DealStatus.active,
          endsAt: DateTime.now().subtract(const Duration(hours: 1)),
        ).isRedeemable,
        isFalse,
        reason: 'a passed deal cannot be honoured',
      );
      expect(
        build(
          status: DealStatus.active,
          startsAt: DateTime.now().add(const Duration(days: 2)),
          endsAt: DateTime.now().add(const Duration(days: 9)),
        ).isRedeemable,
        isFalse,
        reason: 'a scheduled deal has not started',
      );
    });

    test('an unreported counter draws no progress meter', () {
      final deal = build(
        status: DealStatus.active,
        maxRedemptions: 10,
        redemptions: 3,
        redemptionsReported: false,
      );
      expect(deal.redemptionProgress, isNull);
      expect(deal.redemptionLabel, 'Redemptions unavailable');
    });
  });

  group('expiring soon', () {
    test('a live deal inside the week counts', () {
      final deal = build(
        status: DealStatus.active,
        endsAt: DateTime.now().add(const Duration(days: 3)),
      );
      expect(deal.isExpiringSoon, isTrue);
    });

    test('a live deal with room left does not', () {
      final deal = build(
        status: DealStatus.active,
        endsAt: DateTime.now().add(const Duration(days: 20)),
      );
      expect(deal.isExpiringSoon, isFalse);
    });

    test('an unpublished deal never counts, however close its end', () {
      final deal = build(endsAt: DateTime.now().add(const Duration(days: 1)));
      expect(deal.isExpiringSoon, isFalse);
    });
  });

  group('duplicating a deal', () {
    final source = build(
      status: DealStatus.active,
      kind: DealKind.fixed,
      value: 750,
      title: 'Lunch offer',
      description: 'Two courses',
      code: 'LUNCH20',
      terms: 'Mon–Fri',
      imageUrl: '/public/venue-images/abc',
      maxRedemptions: 50,
      redemptions: 12,
    );

    test('copies the content and marks the title', () {
      final draft = source.copyToDraft();
      expect(draft.title, 'Lunch offer (copy)');
      expect(draft.kind, DealKind.fixed);
      expect(draft.value, 750);
      expect(draft.description, 'Two courses');
      expect(draft.terms, 'Mon–Fri');
      expect(draft.imageUrl, '/public/venue-images/abc');
      expect(draft.maxRedemptions, 50);
    });

    test('drops the code, which would otherwise be refused as a clash', () {
      expect(source.copyToDraft().code, '');
    });

    test('a copy of a passed deal lands inside a usable window', () {
      final old = build(
        status: DealStatus.expired,
        startsAt: DateTime.now().subtract(const Duration(days: 60)),
        endsAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      final draft = old.copyToDraft();
      // Both ends move into the present, and the window still runs forwards:
      // a copy starting in the past or ending before it starts could not be
      // published at all.
      expect(draft.startsAt.isAfter(old.startsAt), isTrue);
      expect(draft.endsAt.isAfter(DateTime.now()), isTrue);
      expect(draft.endsAt.isAfter(draft.startsAt), isTrue);
    });

    test('the title cannot exceed the server ceiling', () {
      final long = build(title: 'x' * 118);
      final draft = long.copyToDraft();
      expect(draft.title.length, lessThanOrEqualTo(120));
      expect(draft.title, endsWith('(copy)'));
    });
  });

  group('create body', () {
    test('sends conditions and the cover photo', () {
      final body = DealDraftInput(
        title: ' Lunch ',
        kind: DealKind.percent,
        value: 20,
        startsAt: DateTime.utc(2026, 11, 1),
        endsAt: DateTime.utc(2026, 11, 30),
        terms: 'Mon–Fri',
        imageUrl: '/public/venue-images/abc',
      ).toBody();
      expect(body['title'], 'Lunch');
      expect(body['terms'], 'Mon–Fri');
      expect(body['imageUrl'], '/public/venue-images/abc');
      expect(body['startsAt'], '2026-11-01T00:00:00.000Z');
    });

    test('omits an empty code so the server generates none', () {
      final body = DealDraftInput(
        title: 'Lunch',
        kind: DealKind.percent,
        value: 20,
        startsAt: DateTime.utc(2026, 11, 1),
        endsAt: DateTime.utc(2026, 11, 30),
      ).toBody();
      expect(body.containsKey('code'), isFalse);
      expect(body.containsKey('maxRedemptions'), isFalse);
    });

    test('upper-cases a typed code, because guests quote it out loud', () {
      final body = DealDraftInput(
        title: 'Lunch',
        kind: DealKind.percent,
        value: 20,
        startsAt: DateTime.utc(2026, 11, 1),
        endsAt: DateTime.utc(2026, 11, 30),
        code: 'lunch20',
      ).toBody();
      expect(body['code'], 'LUNCH20');
    });
  });
}
