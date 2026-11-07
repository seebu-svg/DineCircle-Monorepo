// The Business hub gained a sixth tab ("subscription") that is reachable only
// as a query-bearing route (/business?tab=subscription). Two failure modes
// used to bite here: the route failing to resolve at all, and the tile list
// drifting from the tab list. This locks both.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/navigation/app_routes.dart';

void main() {
  test('/business?tab=subscription resolves with its query intact', () {
    const name = '/business?tab=subscription';
    final route = generateRoute(const RouteSettings(name: name));
    expect(route, isNotNull);
    expect(route!.settings.name, name);
    expect(queryOf(route.settings.name!)['tab'], 'subscription');
  });

  test('the hub exposes a subscription tile under Business', () {
    final tile = workspaceModules.where(
      (m) => m.tab == 'subscription',
    );
    expect(tile, hasLength(1));
    expect(tile.single.group, 'Business');
    expect(tile.single.route, AppRoute.business);
    expect(tile.single.fullRoute, '/business?tab=subscription');
  });

  test('the sidebar groups carry the subscription entry to desktop', () {
    final all = [for (final g in sidebarGroups) ...g];
    expect(
      all.any((m) => m.fullRoute == '/business?tab=subscription'),
      isTrue,
    );
  });

  test('subscription is a distinct label from the other business tabs', () {
    final labels = workspaceModules
        .where((m) => m.route == AppRoute.business)
        .map((m) => m.label)
        .toList();
    expect(labels, contains('Subscription'));
    // Every business tab label is unique, the hub must not show two tiles
    // that read the same.
    expect(labels.toSet(), hasLength(labels.length));
  });
}
