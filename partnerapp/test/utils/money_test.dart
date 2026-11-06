import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/utils/money.dart';

void main() {
  group('formatMoney', () {
    test('defaults to USD with two decimals', () {
      expect(formatMoney(12.5), r'$12.50');
    });

    test('groups thousands left of the decimal', () {
      expect(formatMoney(1234567.891), r'$1,234,567.89');
    });

    test('renders negatives with a leading minus before the symbol', () {
      expect(formatMoney(-42.00), r'-$42.00');
    });

    test('honours an explicit currency symbol', () {
      expect(formatMoney(10, currency: 'EUR'), '€10.00');
      expect(formatMoney(10, currency: 'PKR'), 'Rs 10.00');
    });

    test('an unknown code falls back to the ISO code so the symbol is never wrong', () {
      expect(formatMoney(3, currency: 'jpy'), 'JPY 3.00');
    });

    test('zero decimals drops the fraction', () {
      expect(formatMoney(25000, decimals: 0), r'$25,000');
    });
  });

  test('currencySymbol is case-insensitive', () {
    expect(currencySymbol('usd'), r'$');
    expect(currencySymbol('GBP'), '£');
  });

  group('sumByCurrency', () {
    test('keeps currencies apart instead of blending them', () {
      final totals = sumByCurrency(const [
        MoneyAmount('USD', 10),
        MoneyAmount('EUR', 5),
        MoneyAmount('USD', 2.5),
      ]);
      expect(totals['USD'], 12.5);
      expect(totals['EUR'], 5);
      expect(totals.keys, hasLength(2));
    });

    test('an empty code defaults to the assumed currency', () {
      final totals = sumByCurrency(const [MoneyAmount('', 7)]);
      expect(totals[kDefaultCurrency], 7);
    });
  });

  group('formatRate', () {
    test('a whole percent loses the trailing zero', () {
      expect(formatRate(0.10), '10%');
    });

    test('a fractional percent keeps one decimal', () {
      expect(formatRate(0.125), '12.5%');
    });
  });
}
