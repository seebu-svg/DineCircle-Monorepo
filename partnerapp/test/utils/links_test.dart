import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/utils/links.dart';

/// The venue QR encodes this string, so it has to be an absolute `https` link a
/// guest's own camera can open, it has to land on the restaurant profile rather
/// than a menu-only page, and it has to fail closed (empty) rather than produce
/// `https://dinecircle.app/venues/` when the id is missing.
void main() {
  group('venuePublicUrl', () {
    test('points at the public restaurant profile', () {
      expect(
        venuePublicUrl('ven_123'),
        'https://dinecircle.app/venues/ven_123',
      );
    });

    test('trims the id before encoding it', () {
      expect(
        venuePublicUrl('  ven_123  '),
        'https://dinecircle.app/venues/ven_123',
      );
    });

    test('percent-encodes ids that are not URL safe', () {
      expect(
        venuePublicUrl('a b/c'),
        'https://dinecircle.app/venues/a%20b%2Fc',
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
      expect(uri.path, '/venues/ven_123');
      // The guest app's parser reads the id off `/venues/<uuid>` and opens the
      // restaurant profile, so the path segment is part of the contract.
      expect(uri.pathSegments, ['venues', 'ven_123']);
    });
  });
}
