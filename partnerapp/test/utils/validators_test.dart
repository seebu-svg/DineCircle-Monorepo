import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/utils/validators.dart';

void main() {
  group('text', () {
    test('required by default and trims for the emptiness check', () {
      expect(Validators.text('   ', field: 'Name'), 'Name is required');
      expect(Validators.text(null, field: 'Name'), 'Name is required');
    });

    test('enforces min and max on the trimmed value', () {
      expect(Validators.text('ab', field: 'Name', min: 2), isNull);
      expect(Validators.text('a', field: 'Name', min: 2),
          contains('at least 2'));
      expect(Validators.text('way too long', max: 5), contains('too long'));
    });

    test('optional text lets an empty value pass', () {
      expect(Validators.text('', field: 'Bio', required: false), isNull);
    });
  });

  group('email', () {
    test('accepts a well-formed address', () {
      expect(Validators.email('desk@example.test'), isNull);
    });
    test('rejects junk and honours required', () {
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email(''), isNull);
      expect(Validators.email('', required: true), 'Email is required');
    });
  });

  test('phone allows the usual punctuation but no letters', () {
    expect(Validators.phone('+1 (555) 123-4567'), isNull);
    expect(Validators.phone('call me'), isNotNull);
  });

  test('url demands http(s)', () {
    expect(Validators.url('https://cdn.example/i.png'), isNull);
    expect(Validators.url('ftp://cdn/i.png'), isNotNull);
    expect(Validators.url('nope'), isNotNull);
  });

  group('money / percent', () {
    test('money requires a positive number in range', () {
      expect(Validators.money('12.50'), isNull);
      expect(Validators.money('0'), isNotNull);
      expect(Validators.money('abc'), isNotNull);
      expect(Validators.money('1e9'), isNotNull);
    });
    test('percent caps at 100', () {
      expect(Validators.percent('15'), isNull);
      expect(Validators.percent('150'), isNotNull);
    });
  });

  test('time insists on 24-hour HH:MM', () {
    expect(Validators.time('18:30'), isNull);
    expect(Validators.time('8:30'), isNotNull);
    expect(Validators.time('24:00'), isNotNull);
  });

  test('futureDate rejects a past day but allows today', () {
    final today = DateTime.now();
    expect(Validators.futureDate(DateTime(today.year, today.month, today.day)),
        isNull);
    expect(Validators.futureDate(DateTime(2000, 1, 1)), isNotNull);
    expect(Validators.futureDate(null), isNotNull);
  });

  test('orderedRange requires end strictly after start', () {
    final a = DateTime(2026, 1, 1);
    expect(Validators.orderedRange(a, a.add(const Duration(days: 1))), isNull);
    expect(Validators.orderedRange(a, a), isNotNull);
    expect(Validators.orderedRange(null, a), 'Both dates are required');
  });

  test('listLength bounds count from both sides', () {
    expect(Validators.listLength([1, 2], max: 3), isNull);
    expect(Validators.listLength([1, 2, 3], max: 2), contains('At most 2'));
    expect(Validators.listLength(<int>[], min: 1, field: 'tags'),
        contains('At least 1'));
  });

  test('bookingReference guards length and emptiness', () {
    expect(Validators.bookingReference('BK-4821'), isNull);
    expect(Validators.bookingReference('ab'), contains('too short'));
    expect(Validators.bookingReference(''), isNotNull);
  });

  test('looksLikeUuid matches only a canonical uuid', () {
    expect(Validators.looksLikeUuid('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'),
        isTrue);
    expect(Validators.looksLikeUuid('BK-4821'), isFalse);
  });
}
