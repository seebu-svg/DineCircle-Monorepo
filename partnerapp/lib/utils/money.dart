/// Currency-aware money helpers.
///
/// Mirrors the customer app's `utils/money.dart` verbatim in behaviour: the
/// backend stores bare numeric totals, and every amount the Partner App shows
/// is grouped by an explicit currency code so a future multi-currency
/// catalogue can never be summed into one misleading number.
library;

/// Currency assumed for records that carry no explicit code.
const String kDefaultCurrency = 'USD';

/// Symbol for [code]; unknown currencies fall back to the ISO code itself so an
/// amount is never displayed with the wrong symbol.
String currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'USD':
      return r'$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'PKR':
      // Pakistani Rupees, written the way partners and guests read it on menu
      // cards and receipts: `Rs. 1,250`. PKR is the only trading currency on
      // the partner surface, so this symbol is what every amount here shows.
      return 'Rs. ';
    case 'AED':
      return 'AED ';
    default:
      return '${code.toUpperCase()} ';
  }
}

/// Formats [amount] in [currency]. [decimals] defaults to 2 so refunds, partial
/// payments and fees never silently lose cents.
String formatMoney(
  double amount, {
  String currency = kDefaultCurrency,
  int decimals = 2,
}) {
  final negative = amount < 0;
  final body = _grouped(amount.abs().toStringAsFixed(decimals));
  return '${negative ? '-' : ''}${currencySymbol(currency)}$body';
}

/// Inserts thousands separators left of the decimal point.
///
/// Grouping starts at the first comma a reader expects, i.e. four digits
/// (`1,250`), not five. A price of 1250 shown as `1250` reads as an
/// unformatted number next to `12,500`, which is how menu prices looked wrong
/// side by side on the same card.
String _grouped(String decimal) {
  final parts = decimal.split('.');
  final digits = parts.first;
  if (digits.length < 4) return decimal;
  final buffer = StringBuffer();
  final lead = digits.length % 3;
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (i - lead) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return parts.length > 1 ? '$buffer.${parts[1]}' : buffer.toString();
}

/// A single amount together with the currency it was settled in.
class MoneyAmount {
  const MoneyAmount(this.currency, this.amount);

  final String currency;
  final double amount;
}

/// Sums [entries] per currency. Callers render one line per key instead of
/// blending currencies into a single, incorrect total.
Map<String, double> sumByCurrency(Iterable<MoneyAmount> entries) {
  final totals = <String, double>{};
  for (final entry in entries) {
    final code = entry.currency.isEmpty ? kDefaultCurrency : entry.currency;
    totals[code] = (totals[code] ?? 0) + entry.amount;
  }
  return totals;
}

/// Percentage text for a commission rate the server echoed (0.10 → `10%`).
String formatRate(double rate, {int decimals = 1}) {
  final percent = rate * 100;
  final text = percent.toStringAsFixed(decimals);
  return text.endsWith('0') || text.endsWith('.0')
      ? '${percent.toStringAsFixed(0)}%'
      : '$text%';
}
