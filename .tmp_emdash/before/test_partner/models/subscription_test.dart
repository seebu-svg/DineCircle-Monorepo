// Roster content is a decision, not a detail: the identical Pro feature list
// is what both plan cards and the comparison table render, and the yearly
// saving badge ("Save PKR 10,000") is derived money the UI quotes verbatim.
// These tests pin the numbers so a price edit has to be a deliberate act.
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/models/subscription.dart';

void main() {
  group('SubscriptionPlan', () {
    test('exposes exactly the agreed PKR prices', () {
      expect(SubscriptionPlan.monthly.pricePkr, 5000);
      expect(SubscriptionPlan.yearly.pricePkr, 50000);
    });

    test('yearly saving is 12x monthly minus the yearly price', () {
      final twelveMonths = SubscriptionPlan.monthly.pricePkr * 12;
      expect(
        twelveMonths - SubscriptionPlan.yearly.pricePkr,
        VenueSubscription.yearlySavingPkr,
      );
      expect(VenueSubscription.yearlySavingPkr, 10000);
    });

    test('parses the server wire values and rejects unknown ones', () {
      expect(SubscriptionPlan.parse('monthly'), SubscriptionPlan.monthly);
      expect(SubscriptionPlan.parse('yearly'), SubscriptionPlan.yearly);
      expect(SubscriptionPlan.parse('weekly'), isNull);
      expect(SubscriptionPlan.parse(null), isNull);
    });
  });

  group('SubscriptionStatus', () {
    test('parses every server status including the snake_case past_due', () {
      expect(SubscriptionStatus.parse('none'), SubscriptionStatus.none);
      expect(SubscriptionStatus.parse('trialing'), SubscriptionStatus.trialing);
      expect(SubscriptionStatus.parse('active'), SubscriptionStatus.active);
      expect(SubscriptionStatus.parse('past_due'), SubscriptionStatus.pastDue);
      expect(SubscriptionStatus.parse('cancelled'), SubscriptionStatus.cancelled);
    });

    test('an unknown status falls back to none rather than throwing', () {
      expect(SubscriptionStatus.parse('refunded'), SubscriptionStatus.none);
      expect(SubscriptionStatus.parse(null), SubscriptionStatus.none);
    });

    test('every status carries a human label', () {
      for (final s in SubscriptionStatus.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });

  group('VenueSubscription.fromJson', () {
    test('reads a full active monthly row', () {
      final sub = VenueSubscription.fromJson(const {
        'plan': 'monthly',
        'status': 'active',
        'pricePkr': 5000,
        'periodStart': '2026-11-01T00:00:00.000Z',
        'periodEnd': '2026-12-01T00:00:00.000Z',
        'autoRenew': true,
      });
      expect(sub.plan, SubscriptionPlan.monthly);
      expect(sub.status, SubscriptionStatus.active);
      expect(sub.pricePkr, 5000);
      expect(sub.autoRenew, isTrue);
      expect(sub.periodStart, isNotNull);
      expect(sub.periodEnd, isNotNull);
      expect(sub.isActive, isTrue);
    });

    test('the synthetic default (no row) is none with zero price', () {
      final sub = VenueSubscription.fromJson(const {
        'plan': null,
        'status': 'none',
        'pricePkr': 0,
        'autoRenew': false,
      });
      expect(sub.plan, isNull);
      expect(sub.status, SubscriptionStatus.none);
      expect(sub.isActive, isFalse);
      expect(sub.periodStart, isNull);
      expect(sub.cancelledAt, isNull);
    });

    test('a cancelled row is not active even with a plan set', () {
      final sub = VenueSubscription.fromJson(const {
        'plan': 'yearly',
        'status': 'cancelled',
        'pricePkr': 50000,
        'cancelledAt': '2026-10-20T00:00:00.000Z',
      });
      expect(sub.plan, SubscriptionPlan.yearly);
      expect(sub.isActive, isFalse);
      expect(sub.cancelledAt, isNotNull);
    });

    test('garbage numerics degrade to zero rather than throwing', () {
      final sub = VenueSubscription.fromJson(const {'pricePkr': 'NaN'});
      expect(sub.pricePkr, 0);
      expect(sub.status, SubscriptionStatus.none);
    });
  });

  group('proFeatures', () {
    test('both plans share one identical feature list', () {
      expect(VenueSubscription.proFeatures, hasLength(7));
      // No duplicates — the same list renders under both plan cards.
      expect(VenueSubscription.proFeatures.toSet(), hasLength(7));
      for (final f in VenueSubscription.proFeatures) {
        expect(f, isNotEmpty);
      }
    });
  });
}
