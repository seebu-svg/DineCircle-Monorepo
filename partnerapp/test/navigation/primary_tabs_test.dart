import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/navigation/app_routes.dart';

/// The mobile bar is exactly five tabs — Home, Menu, Deals, Insights,
/// Business — and Menu/Deals/Insights are query tabs of /business. That means
/// several destinations share one route root, so the active-tab index must be
/// read from the FULL route name, not just the path. These tests lock that
/// contract and prove no folded-in module (service, experiences, inbox) lost
/// its route: every one of them still resolves and still highlights Business.
void main() {
  test('the bar has exactly five tabs, in order, with the agreed labels', () {
    expect(
      PrimaryDestination.values.map((d) => d.label).toList(),
      ['Home', 'Menu', 'Deals', 'Insights', 'Business'],
    );
    expect(PrimaryDestination.home.route, AppRoute.today);
    expect(PrimaryDestination.menu.route, '/business?tab=menu');
    expect(PrimaryDestination.deals.route, '/business?tab=deals');
    expect(PrimaryDestination.insights.route, '/business?tab=analytics');
    expect(PrimaryDestination.business.route, AppRoute.business);
  });

  group('PrimaryDestination.indexOf', () {
    test('resolves each tab from its full route, query included', () {
      expect(PrimaryDestination.indexOf('/today'), 0);
      expect(PrimaryDestination.indexOf('/business?tab=menu'), 1);
      expect(PrimaryDestination.indexOf('/business?tab=deals'), 2);
      expect(PrimaryDestination.indexOf('/business?tab=analytics'), 3);
      expect(PrimaryDestination.indexOf('/business'), 4);
      // Other business tabs land on the hub tab, not a wrong sibling.
      expect(PrimaryDestination.indexOf('/business?tab=profile'), 4);
      expect(PrimaryDestination.indexOf('/business?tab=qr'), 4);
    });

    test('folded-in modules and their detail pages highlight Business', () {
      expect(PrimaryDestination.indexOf('/service?tab=checkin'), 4);
      expect(PrimaryDestination.indexOf('/experiences'), 4);
      expect(PrimaryDestination.indexOf('/experiences/detail'), 4);
      expect(PrimaryDestination.indexOf('/inbox?tab=notifications'), 4);
      expect(PrimaryDestination.indexOf('/business/hours'), 4);
    });

    test('unknown or absent routes fall back to Home, never a crash', () {
      expect(PrimaryDestination.indexOf(null), 0);
      expect(PrimaryDestination.indexOf(''), 0);
      expect(PrimaryDestination.indexOf('/settings'), 0);
      expect(PrimaryDestination.indexOf('/nope?x=1'), 0);
    });
  });

  test('every tab route still resolves through generateRoute', () {
    for (final dest in PrimaryDestination.values) {
      final route = generateRoute(RouteSettings(name: dest.route));
      expect(route, isNotNull, reason: dest.label);
      // The name survives so section screens still read ?tab= back out.
      expect(route!.settings.name, dest.route);
    }
  });

  test('workspace hub tiles all point at resolvable, tab-bearing routes', () {
    expect(workspaceGroups.map((g) => g.first.group).toList(),
        ['Business', 'Service', 'Experiences', 'Inbox']);
    for (final item in workspaceModules) {
      expect(item.tab, isNotNull, reason: item.label);
      final route = generateRoute(RouteSettings(name: item.fullRoute));
      expect(route, isNotNull, reason: item.fullRoute);
    }
    // Nothing from the old bottom bar vanished into nowhere.
    for (final path in ['/service', '/experiences', '/inbox']) {
      expect(
        workspaceModules.any((m) =>
            m.route == path ||
            rootOf(m.fullRoute) == path),
        isTrue,
        reason: '$path lost every hub entry',
      );
    }
  });
}
