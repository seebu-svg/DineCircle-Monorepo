import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/api/api_client.dart';
import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/deals.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/app_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/repositories/business_repository.dart';
import 'package:partnerapp/screens/business/deals_tab.dart';
import 'package:partnerapp/screens/business/deals_widgets.dart';
import 'package:partnerapp/theme/app_theme.dart';
import 'package:partnerapp/widgets/async_views.dart';

/// A promotion with sane, non-expiring defaults and one field per test.
Deal deal(
  DealStatus status, {
  String id = 'd',
  String title = 'Lunch deal',
  DealKind kind = DealKind.percent,
  double value = 20,
  DateTime? startsAt,
  DateTime? endsAt,
  int? maxRedemptions,
  int redemptions = 3,
  String description = '',
  String terms = '',
  String imageUrl = '',
  String? code,
}) => Deal(
  id: id,
  restaurantId: 'v',
  title: title,
  description: description,
  kind: kind,
  value: value,
  status: status,
  startsAt: startsAt ?? DateTime.now().subtract(const Duration(days: 1)),
  endsAt: endsAt ?? DateTime.now().add(const Duration(days: 7)),
  maxRedemptions: maxRedemptions,
  redemptions: redemptions,
  terms: terms,
  imageUrl: imageUrl,
  code: code,
);

class Repo extends BusinessRepository {
  Repo({List<Deal>? rows})
    : rows = rows ?? [deal(DealStatus.draft)],
      super(ApiClient());

  List<Deal> rows;
  int creates = 0;
  int updates = 0;
  int reads = 0;
  int redeems = 0;
  bool fail = false;

  /// Holds a write open, so a test can look at the card mid-flight.
  Completer<void>? pending;

  /// Holds the read open, so the first-load skeleton can be observed.
  Completer<void>? readGate;

  DealDraftInput? input;

  /// What the last PATCH carried, so the round-trip of conditions and the
  /// cover photo can be asserted (the field the partner is most likely to
  /// notice going missing).
  String? lastTitle;
  String? lastTerms;
  String? lastImageUrl;
  DealStatus? lastStatus;

  @override
  Future<List<Deal>> deals(
    String venueId, [
    DealQuery query = const DealQuery(),
  ]) async {
    reads++;
    await readGate?.future;
    if (fail) throw StateError('Offline');
    if (query.status == null) return rows;
    return rows.where((row) => row.status.wire == query.status).toList();
  }

  @override
  Future<Deal> createDeal(String venueId, DealDraftInput value) async {
    creates++;
    input = value;
    await pending?.future;
    if (fail) throw StateError('Save failed');
    final created = deal(DealStatus.draft, title: value.title);
    rows = [...rows, created];
    return created;
  }

  @override
  Future<Deal> updateDeal(
    String venueId,
    String dealId, {
    String? title,
    String? description,
    DealKind? kind,
    double? value,
    String? code,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxRedemptions,
    DealStatus? status,
    String? terms,
    String? imageUrl,
  }) async {
    updates++;
    lastTitle = title;
    lastTerms = terms;
    lastImageUrl = imageUrl;
    lastStatus = status;
    await pending?.future;
    if (fail) throw StateError('Update failed');
    final index = rows.indexWhere((row) => row.id == dealId);
    if (index < 0) throw StateError('Missing row');
    final next = rows[index];
    final replaced = Deal(
      id: next.id,
      restaurantId: next.restaurantId,
      title: title ?? next.title,
      description: description ?? next.description,
      kind: kind ?? next.kind,
      value: value ?? next.value,
      status: status ?? next.status,
      startsAt: startsAt ?? next.startsAt,
      endsAt: endsAt ?? next.endsAt,
      maxRedemptions: maxRedemptions ?? next.maxRedemptions,
      redemptions: next.redemptions,
      terms: terms ?? next.terms,
      imageUrl: imageUrl ?? next.imageUrl,
      code: code ?? next.code,
    );
    rows = [...rows]..[index] = replaced;
    return replaced;
  }

  @override
  Future<Deal> redeemDeal(String venueId, String dealId) async {
    redeems++;
    await pending?.future;
    if (fail) throw StateError('Redeem failed');
    final index = rows.indexWhere((row) => row.id == dealId);
    final next = rows[index];
    final counted = Deal(
      id: next.id,
      restaurantId: next.restaurantId,
      title: next.title,
      description: next.description,
      kind: next.kind,
      value: next.value,
      status: next.status,
      startsAt: next.startsAt,
      endsAt: next.endsAt,
      maxRedemptions: next.maxRedemptions,
      redemptions: next.redemptions + 1,
      terms: next.terms,
      imageUrl: next.imageUrl,
      code: next.code,
    );
    rows = [...rows]..[index] = counted;
    return counted;
  }

  @override
  Future<bool> deleteDeal(String venueId, String dealId) async {
    rows = rows.where((row) => row.id != dealId).toList();
    return true;
  }
}

Widget harness(
  Repo repo, {
  bool verified = true,
  PartnerRole role = PartnerRole.owner,
}) => ProviderScope(
  overrides: [
    selectedVenueProvider.overrideWithValue(
      Venue(id: 'v', name: 'Cafe', verified: verified, myRole: role),
    ),
    businessRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const Scaffold(body: DealsTab()),
  ),
);

/// Opens the card's kebab menu and taps one entry.
Future<void> action(WidgetTester tester, String label, {int at = 0}) async {
  await tester.tap(find.byTooltip('Deal actions').at(at));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Answers the confirmation dialog a destructive or guest-facing write raises.
Future<void> confirm(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Taps one status chip in the scrollable filter rail.
Future<void> rail(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(DealStatusRail),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps one of the three figures in the header strip.
Future<void> indicator(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(DealsHeaderCard),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pins a device size and a text scale for one test, and clears both after.
void useDevice(WidgetTester tester, Size size, {double scale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets('the header figures describe every loaded deal', (tester) async {
    final repo = Repo(
      rows: [
        deal(
          DealStatus.active,
          id: 'a',
          title: 'Live lunch',
          redemptions: 5,
          endsAt: DateTime.now().add(const Duration(days: 30)),
        ),
        deal(DealStatus.draft, id: 'b', title: 'Dinner draft', redemptions: 2),
        deal(DealStatus.paused, id: 'c', title: 'Paused brunch', redemptions: 0),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    final header = find.byType(DealsHeaderCard);
    expect(header, findsOneWidget);
    expect(find.text('Deals & Offers'), findsOneWidget);
    // Three figures, folded from the rows the list can show, each naming
    // itself so a number is never a riddle.
    expect(
      find.descendant(of: header, matching: find.text('Active deals')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Redemptions')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Drafts')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('1')),
      findsNWidgets(2),
      reason: 'one active deal and one draft',
    );
    expect(
      find.descendant(of: header, matching: find.text('7')),
      findsOneWidget,
      reason: '5 + 2 + 0 recorded redemptions',
    );

    // The rail carries no counts any more: a chip reading "Active 1" beside a
    // card wearing an "Active" badge was the third place the word appeared.
    expect(find.text('All 3'), findsNothing);
    expect(find.textContaining('Active 1'), findsNothing);

    // One card, one badge: no second lifecycle word anywhere on the card.
    final card = find.byType(DealCard).first;
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(DealStatusPill)),
      findsOneWidget,
    );
  });

  testWidgets('a header figure filters the list and Clear returns', (
    tester,
  ) async {
    final repo = Repo(
      rows: [
        deal(DealStatus.active, id: 'a', title: 'Live lunch'),
        deal(DealStatus.draft, id: 'b', title: 'Dinner draft'),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await indicator(tester, 'Drafts');
    expect(find.text('Drafts · 1 deal'), findsOneWidget);
    expect(find.text('Dinner draft'), findsOneWidget);
    expect(find.text('Live lunch'), findsNothing);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Live lunch'), findsOneWidget);
    expect(find.text('Dinner draft'), findsOneWidget);
  });

  testWidgets('the rail filters, and a second tap on the same chip clears it', (
    tester,
  ) async {
    final repo = Repo(
      rows: [
        deal(DealStatus.active, id: 'a', title: 'Live lunch'),
        deal(DealStatus.draft, id: 'b', title: 'Dinner draft'),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await rail(tester, 'Active');
    expect(find.text('Active deals · 1 deal'), findsOneWidget);
    expect(find.text('Live lunch'), findsOneWidget);
    expect(find.text('Dinner draft'), findsNothing);

    await rail(tester, 'Active');
    expect(find.text('Active deals · 1 deal'), findsNothing);
    expect(find.text('Dinner draft'), findsOneWidget);
  });

  testWidgets('a filter that matches nothing always has a way back', (
    tester,
  ) async {
    final repo = Repo(
      rows: [
        deal(DealStatus.active, id: 'a', title: 'Live lunch'),
        deal(DealStatus.draft, id: 'b', title: 'Dinner draft'),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await rail(tester, 'Drafts');
    // Publish the only draft: the filter now matches nothing, and the exit is
    // the point of the branch.
    await action(tester, 'Publish deal');
    await confirm(tester, 'Publish');
    expect(find.text('No deals match this filter'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Live lunch'), findsOneWidget);
  });

  testWidgets('lifecycle moves follow the transition map; expired is terminal', (
    tester,
  ) async {
    final repo = Repo(rows: [deal(DealStatus.draft)]);
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await action(tester, 'Publish deal');
    await confirm(tester, 'Publish');
    expect(repo.lastStatus, DealStatus.active);
    expect(find.text('Deal published · live in the Customer App.'), findsOneWidget);

    await action(tester, 'Pause deal');
    expect(repo.lastStatus, DealStatus.paused);
    expect(
      find.descendant(
        of: find.byType(DealCard),
        matching: find.text('Paused'),
      ),
      findsOneWidget,
    );

    await action(tester, 'Resume deal');
    await confirm(tester, 'Resume');
    expect(repo.lastStatus, DealStatus.active);

    await action(tester, 'Retire deal');
    await confirm(tester, 'Retire');
    expect(repo.lastStatus, DealStatus.expired);
    expect(
      find.descendant(
        of: find.byType(DealCard),
        matching: find.text('Expired'),
      ),
      findsOneWidget,
    );
    // A retired deal has no move left, but it can still be read and copied.
    await tester.tap(find.byTooltip('Deal actions'));
    await tester.pumpAndSettle();
    expect(find.text('Preview as guest'), findsOneWidget);
    expect(find.text('Publish deal'), findsNothing);
    expect(find.text('Pause deal'), findsNothing);
    expect(find.text('Retire deal'), findsNothing);
  });

  testWidgets('draft deletion confirms and refreshes the list', (tester) async {
    final repo = Repo();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await action(tester, 'Delete draft');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.rows, isEmpty);
    expect(find.text('No deals yet'), findsOneWidget);
  });

  testWidgets('an empty venue offers the one action that changes that', (
    tester,
  ) async {
    await tester.pumpWidget(harness(Repo(rows: [])));
    await tester.pumpAndSettle();

    expect(find.text('No deals yet'), findsOneWidget);
    // No rail: there is nothing to filter.
    expect(find.byType(DealStatusRail), findsNothing);
    // The empty state repeats the primary action rather than pointing at it.
    await tester.tap(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.text('New deal'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create draft'), findsOneWidget);
  });

  testWidgets('creation prevents duplicate submits and closes on success', (
    tester,
  ) async {
    final repo = Repo()..pending = Completer<void>();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New deal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Dinner offer');
    await tester.enterText(find.byType(TextFormField).at(1), '15');
    await tester.tap(find.text('Create draft'));
    await tester.pump();
    expect(repo.creates, 1);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
          .onPressed,
      isNull,
    );
    // The default window ends at 23:59 so the last day is a full day of service.
    expect(repo.input!.endsAt.hour, 23);
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Create draft'), findsNothing);
    expect(find.text('Deal created as draft.'), findsOneWidget);
  });

  testWidgets('invalid values never submit; save errors keep the form open', (
    tester,
  ) async {
    final repo = Repo()..fail = true;
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New deal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Dinner offer');
    await tester.enterText(find.byType(TextFormField).at(1), '101');
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();
    expect(repo.creates, 0, reason: '101% is not a discount');
    expect(find.text('Discount cannot exceed 100%'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '10');
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();
    expect(repo.creates, 1);
    expect(find.text('Create draft'), findsOneWidget);
    expect(find.textContaining('Could not save deal:'), findsOneWidget);
  });

  testWidgets('a short title is caught before the server sees it', (
    tester,
  ) async {
    final repo = Repo();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New deal'));
    await tester.pumpAndSettle();
    // `dealBaseSchema` requires three characters; two used to reach the API and
    // come back a 422 with a message nobody could act on.
    await tester.enterText(find.byType(TextFormField).at(0), 'AB');
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();
    expect(repo.creates, 0);
    expect(find.text('Title needs at least 3 characters'), findsOneWidget);
  });

  testWidgets('roles and verification restrict controls honestly', (
    tester,
  ) async {
    await tester.pumpWidget(harness(Repo(), role: PartnerRole.staff));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'New deal'))
          .onPressed,
      isNull,
    );
    // Staff may still count a redemption and preview an offer, but the menu
    // must not offer a lifecycle move it would be refused for.
    await tester.tap(find.byTooltip('Deal actions'));
    await tester.pumpAndSettle();
    expect(find.text('Preview as guest'), findsOneWidget);
    expect(find.text('Publish deal'), findsNothing);
    expect(find.text('Edit draft'), findsNothing);
    expect(find.text('Delete draft'), findsNothing);
  });

  testWidgets('an unverified venue reads the list but cannot publish', (
    tester,
  ) async {
    final repo = Repo(rows: [deal(DealStatus.draft)]);
    await tester.pumpWidget(harness(repo, verified: false));
    await tester.pumpAndSettle();

    // The banner sits in the list, not in the pinned chrome, so the cards keep
    // their room at large text scales.
    expect(find.text('Verification required'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'New deal'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Deal actions'));
    await tester.pumpAndSettle();
    expect(find.text('Publish deal'), findsNothing);
    expect(find.text('Edit draft'), findsNothing);
  });

  testWidgets('the first read shows a skeleton, not a confident zero', (
    tester,
  ) async {
    final repo = Repo()..readGate = Completer<void>();
    await tester.pumpWidget(harness(repo));
    await tester.pump();

    expect(find.byType(DealsSkeleton), findsOneWidget);
    expect(find.text('Deals & Offers'), findsNothing);

    repo.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(DealsSkeleton), findsNothing);
    expect(find.text('Deals & Offers'), findsOneWidget);
  });

  testWidgets('read errors retry and pull to refresh awaits a new read', (
    tester,
  ) async {
    final repo = Repo()..fail = true;
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    final before = repo.reads;
    await tester.drag(find.byType(DealCard).first, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(repo.reads, greaterThan(before));
  });

  testWidgets('a pending write replaces the actions and reports its failure', (
    tester,
  ) async {
    final repo = Repo()..pending = Completer<void>();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await action(tester, 'Publish deal');
    // Confirm without settling: the card spins while the write travels, and a
    // spinner never settles.
    await tester.tap(find.text('Publish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.updates, 1);
    // One card, one in-flight state: the buttons are gone rather than tappable
    // twice, and the card says what it is doing.
    expect(find.text('Updating…'), findsOneWidget);
    expect(find.byTooltip('Deal actions'), findsNothing);
    expect(find.text('Redeem'), findsNothing);

    repo.fail = true;
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not update deal:'), findsOneWidget);
    expect(find.text('Updating…'), findsNothing);
    expect(
      tester
          .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
          .enabled,
      isTrue,
    );
  });

  testWidgets('conditions and the cover photo survive an edit round-trip', (
    tester,
  ) async {
    final repo = Repo(
      rows: [
        deal(
          DealStatus.draft,
          terms: 'Mon–Fri, 12:00–15:00',
          imageUrl: '/public/venue-images/abc',
        ),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await action(tester, 'Edit draft');
    // Once on the card, once in the field being edited.
    expect(find.text('Lunch deal'), findsNWidgets(2));
    expect(find.text('Mon–Fri, 12:00–15:00'), findsOneWidget);

    // The whole reason the conditions field exists: what the partner writes is
    // what the guest reads, so it has to travel on the PATCH.
    await tester.ensureVisible(find.text('Weekends only'));
    await tester.tap(find.text('Weekends only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(repo.updates, 1);
    expect(repo.lastTerms, 'Mon–Fri, 12:00–15:00, Weekends only');
    expect(repo.lastImageUrl, '/public/venue-images/abc');
    expect(find.text('Draft updated.'), findsOneWidget);
  });

  testWidgets('a duplicate creates a draft and never patches the original', (
    tester,
  ) async {
    final repo = Repo(
      rows: [deal(DealStatus.active, title: 'Lunch deal', code: 'LUNCH20')],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await action(tester, 'Duplicate');
    expect(find.text('Duplicate deal'), findsWidgets);
    expect(find.text('Lunch deal (copy)'), findsOneWidget);
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();
    expect(repo.creates, 1);
    expect(repo.updates, 0);
    expect(repo.input!.title, 'Lunch deal (copy)');
    expect(repo.input!.code, isEmpty);
    expect(find.text('Copy created as a draft.'), findsOneWidget);
  });

  testWidgets('recording a redemption quotes the count and reports the rest', (
    tester,
  ) async {
    final repo = Repo(
      rows: [deal(DealStatus.active, maxRedemptions: 2, redemptions: 1)],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 redeemed'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);

    await tester.tap(find.text('Redeem'));
    await tester.pumpAndSettle();
    // The figure is stated before the tap, because there is no undo.
    expect(find.textContaining('1 of 2 uses recorded'), findsOneWidget);
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();

    expect(repo.redeems, 1);
    // The toast quotes the counters the server returns *after* the increment,
    // so a desk reading "0 of 2 left" knows the cap is now spent.
    expect(find.text('Redemption recorded · 0 of 2 left.'), findsOneWidget);
    expect(find.text('2 of 2 redeemed'), findsOneWidget);
    expect(find.text('Limit reached'), findsOneWidget);
    expect(find.text('Redeem'), findsNothing);
  });

  testWidgets('a capped-out deal cannot be redeemed again', (tester) async {
    final repo = Repo(
      rows: [deal(DealStatus.active, maxRedemptions: 2, redemptions: 2)],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    expect(find.text('Limit reached'), findsOneWidget);
    expect(find.text('Redeem'), findsNothing);
  });

  testWidgets('an unreported counter reads as unmeasured, never as zero', (
    tester,
  ) async {
    final repo = Repo(
      rows: [
        Deal(
          id: 'd',
          restaurantId: 'v',
          title: 'Lunch deal',
          kind: DealKind.percent,
          value: 20,
          status: DealStatus.active,
          startsAt: DateTime.now().subtract(const Duration(days: 1)),
          endsAt: DateTime.now().add(const Duration(days: 7)),
          redemptionsReported: false,
        ),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    expect(find.text('Redemptions not reported'), findsOneWidget);
    expect(find.text('0 redemptions · no limit'), findsNothing);
    // The header says why its figure is a dash instead of printing a zero.
    expect(find.text('Not reported'), findsOneWidget);
  });

  testWidgets('a card opens the details view with rules, code and counts', (
    tester,
  ) async {
    // A tall window, so the whole record fits and each section can be read
    // without scrolling: this test is about content, not about scrolling.
    useDevice(tester, const Size(800, 1400));
    final repo = Repo(
      rows: [
        deal(
          DealStatus.active,
          code: 'LUNCH20',
          maxRedemptions: 20,
          redemptions: 5,
          terms: 'Dine-in only. How to redeem: show the code at the table.',
        ),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lunch deal'));
    await tester.pumpAndSettle();

    expect(find.text('Deal details'), findsOneWidget);
    expect(find.text('Validity'), findsOneWidget);
    expect(find.text('Eligibility and conditions'), findsOneWidget);
    expect(find.text('Promotion code'), findsOneWidget);
    expect(find.text('LUNCH20'), findsOneWidget);
    // Split the same way the Customer App splits it.
    expect(find.text('Dine-in only.'), findsOneWidget);
    expect(find.text('show the code at the table.'), findsOneWidget);
    expect(find.text('Redemption activity'), findsOneWidget);
    // The platform counts uses and stores no ledger; the sheet says so rather
    // than showing a history that is always empty.
    expect(
      find.textContaining('Individual uses are not stored'),
      findsOneWidget,
    );

    // The clipboard has no platform channel under `flutter test`, and the
    // button reports what actually happened rather than assuming.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pumpAndSettle();
    expect(find.text('Code LUNCH20 copied'), findsOneWidget);
  });

  testWidgets('the details view scrolls on a phone and still reads honestly', (
    tester,
  ) async {
    useDevice(tester, const Size(320, 640));
    final repo = Repo(
      rows: [
        deal(
          DealStatus.active,
          code: 'LUNCH20',
          maxRedemptions: 20,
          redemptions: 5,
          terms: 'Dine-in only. How to redeem: show the code at the table.',
        ),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lunch deal'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The record is longer than the sheet: the tail has to be reachable.
    await tester.dragUntilVisible(
      find.text('Redemption activity'),
      find.descendant(
        of: find.byType(DealDetailsSheet),
        matching: find.byType(ListView),
      ),
      const Offset(0, -160),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the preview states what guests can and cannot see', (
    tester,
  ) async {
    final repo = Repo(
      rows: [
        deal(
          DealStatus.paused,
          terms: 'Dine-in only. How to redeem: show the code at the table.',
        ),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await action(tester, 'Preview as guest');
    expect(find.text('Guest preview'), findsOneWidget);
    // Said once, in the sheet: the card points at the state, it does not
    // repeat the sentence.
    expect(find.text('Paused · hidden from guests'), findsOneWidget);
    expect(find.text('Dine-in only.'), findsOneWidget);
    expect(find.text('show the code at the table.'), findsOneWidget);
    // No banner means no grey block: the guest sees the venue cover instead.
    expect(
      find.text('Guests see your venue cover photo behind this offer.'),
      findsOneWidget,
    );
  });

  testWidgets('a fixed deal reads in rupees, not as a bare decimal', (
    tester,
  ) async {
    final repo = Repo(
      rows: [deal(DealStatus.active, kind: DealKind.fixed, value: 1250)],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    // Once, on the card: the cover-band pill that used to repeat it is gone.
    expect(find.text('Rs. 1,250 off'), findsOneWidget);
    expect(find.text('Rs. 1,250 off package'), findsNothing);
    expect(find.textContaining('1250.00'), findsNothing);
  });

  testWidgets('a deal without a banner reserves no space for one', (
    tester,
  ) async {
    final repo = Repo(
      rows: [deal(DealStatus.active, title: 'Lunch deal', description: '')],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    // A 132dp grey placeholder used to sit above the title; the card is now
    // only as tall as its content.
    expect(tester.getSize(find.byType(DealCard)).height, lessThan(200));
  });

  testWidgets('long text on a small phone stays inside the screen', (
    tester,
  ) async {
    useDevice(tester, const Size(320, 640));
    final repo = Repo(
      rows: [
        deal(
          DealStatus.active,
          id: 'a',
          title: 'Weekend family feast with a free dessert for every table',
          description:
              'Free dessert for every guest at the table when two mains are '
              'ordered before 19:00, dine-in only, excluding public holidays.',
          maxRedemptions: 200,
          redemptions: 178,
          endsAt: DateTime.now().add(const Duration(days: 3)),
        ),
        deal(DealStatus.draft, id: 'b', title: 'Dinner draft'),
        deal(DealStatus.expired, id: 'c', title: 'Old offer'),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(DealCard).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Deal details'), findsOneWidget);
  });

  testWidgets('large text on a small phone keeps every control reachable', (
    tester,
  ) async {
    useDevice(tester, const Size(320, 700), scale: 2);
    final repo = Repo(
      rows: [
        deal(
          DealStatus.active,
          title: 'Weekend family feast',
          description: 'Free dessert with every main course.',
          maxRedemptions: 20,
          redemptions: 4,
        ),
        deal(DealStatus.draft, id: 'b', title: 'Dinner draft'),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // The header drops a word before it breaks one at this width, and the key
    // still reports its full meaning.
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create draft'));
    expect(tester.takeException(), isNull);
    // The save button is pinned outside the scroll view, so the keyboard
    // squeezes the fields rather than pushing the button out of reach.
    expect(find.text('Create draft').hitTestable(), findsOneWidget);
  });

  testWidgets('a medium phone at 1.3x text keeps the cards readable', (
    tester,
  ) async {
    useDevice(tester, const Size(360, 780), scale: 1.3);
    final repo = Repo(
      rows: [
        deal(DealStatus.active, id: 'a', title: 'Live lunch'),
        deal(DealStatus.paused, id: 'b', title: 'Paused brunch'),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DealCard), findsNWidgets(2));
  });

  testWidgets('a large phone shows both cards without an overflow', (
    tester,
  ) async {
    useDevice(tester, const Size(412, 915));
    final repo = Repo(
      rows: [
        deal(DealStatus.active, id: 'a', title: 'Live lunch'),
        deal(DealStatus.draft, id: 'b', title: 'Dinner draft'),
        deal(DealStatus.expired, id: 'c', title: 'Old offer'),
      ],
    );
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DealCard), findsNWidgets(3));
    // Three statuses, one badge each, no duplicate lifecycle wording.
    expect(find.byType(DealStatusPill), findsNWidgets(3));
  });
}
