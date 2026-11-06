import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/utils/links.dart';

/// The venue QR encodes this string, so it has to be an absolute `https` link a
/// guest's own camera can open, and it has to fail closed (empty) rather than
/// produce `https://dinecircle.app/menu/` when the id is missing.
void main() {
  group('venuePublicUrl', () {
    test('points at the public web menu page', () {
      expect(
        venuePublicUrl('ven_123'),
        'https://dinecircle.app/menu/ven_123',
      );
    });

    test('trims the id before encoding it', () {
      expect(venuePublicUrl('  ven_123  '), 'https://dinecircle.app/menu/ven_123');
    });

    test('percent-encodes ids that are not URL safe', () {
      expect(
        venuePublicUrl('a b/c'),
        'https://dinecircle.app/menu/a%20b%2Fc',
      );
    });

    test('returns empty instead of a broken link when there is no id', () {
      expect(venuePublicUrl(''), '');
      expect(venuePublicUrl('   '), '');
    });

    test('parses as an absolute https URL on the public host', () {
      final uri = Uri.parse(venuePublicUrl('ven_123'));
      expect(uri.scheme, 'https');
      expect(uri.host, 'dinecircle.app');
      expect(uri.path, '/menu/ven_123');
    });
  });
}
