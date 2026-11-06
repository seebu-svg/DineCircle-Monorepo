import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/navigation/app_routes.dart';

/// The named route table only matches bare paths, so the shell and dashboard
/// push `/service?tab=checkin`-style links through [generateRoute]. If a query
/// route failed to resolve the Navigator threw "could not find a generator for
/// route" and the sub-tabs were dead (plan line 45: shareable web URLs).
void main() {
  test('a tabbed route resolves to a concrete route', () {
    final route = generateRoute(const RouteSettings(name: '/service?tab=checkin'));
    expect(route, isNotNull);
  });

  test('the generated route keeps the full name so routeQuery sees the tab', () {
    const name = '/business?tab=menu';
    final route = generateRoute(const RouteSettings(name: name));
    expect(route!.settings.name, name);
    expect(queryOf(route.settings.name!)['tab'], 'menu');
  });

  test('a bare section route still resolves', () {
    expect(generateRoute(const RouteSettings(name: '/inbox')), isNotNull);
  });

  test('an unknown path falls back to a route rather than null', () {
    // A malformed deep link must not crash the Navigator with no generator.
    expect(generateRoute(const RouteSettings(name: '/nope?x=1')), isNotNull);
  });
}
