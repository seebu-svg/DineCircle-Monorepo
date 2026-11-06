import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:partnerapp/theme/app_theme.dart';

Deal deal(DealStatus status) => Deal(
  id: 'd',
  restaurantId: 'v',
  title: 'Lunch deal',
  kind: DealKind.percent,
  value: 20,
  status: status,
  startsAt: DateTime.now(),
  endsAt: DateTime.now().add(const Duration(days: 7)),
  redemptions: 3,
);

class Repo extends BusinessRepository {
  Repo() : super(ApiClient());
  Deal? row = deal(DealStatus.draft);
  int creates = 0;
  int updates = 0;
  int reads = 0;
  bool fail = false;
  Completer<void>? pending;
  DealDraftInput? input;

  @override
  Future<List<Deal>> deals(
    String venueId, [
    DealQuery query = const DealQuery(),
  ]) async {
    reads++;
    if (fail) throw StateError('Offline');
    return [
      if (row != null &&
          (query.status == null || query.status == row!.status.wire))
        row!,
    ];
  }

  @override
  Future<Deal> createDeal(String venueId, DealDraftInput value) async {
    creates++;
    input = value;
    await pending?.future;
    if (fail) throw StateError('Save failed');
    return row = deal(DealStatus.draft);
  }

  @override
  Future<Deal> updateDeal(
    String venueId,
    String dealId, {
    String? title,
    String? description,
    double? value,
    String? code,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxRedemptions,
    DealStatus? status,
  }) async {
    updates++;
    await pending?.future;
    if (fail) throw StateError('Update failed');
    return row = deal(status ?? DealStatus.draft);
  }

  @override
  Future<bool> deleteDeal(String venueId, String dealId) async {
    row = null;
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

Future<void> action(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Deal actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'filtered lifecycle mutations refresh drafts, active and paused; expired is terminal',
    (tester) async {
      final repo = Repo();
      await tester.pumpWidget(harness(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();
      await action(tester, 'Publish deal');
      expect(find.text('No draft deals'), findsOneWidget);
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();
      await action(tester, 'Pause deal');
      expect(find.text('No active deals'), findsOneWidget);
      await tester.tap(find.text('Paused'));
      await tester.pumpAndSettle();
      await action(tester, 'Resume deal');
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();
      await action(tester, 'Retire deal');
      await tester.tap(find.text('Expired'));
      await tester.pumpAndSettle();
      expect(find.text('Retired / expired'), findsOneWidget);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );
    },
  );

  testWidgets('draft deletion confirms and refreshes filtered list', (
    tester,
  ) async {
    await tester.pumpWidget(harness(Repo()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drafts'));
    await tester.pumpAndSettle();
    await action(tester, 'Delete draft');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No draft deals'), findsOneWidget);
  });

  testWidgets('creation prevents duplicates and closes after success', (
    tester,
  ) async {
    final repo = Repo()..pending = Completer<void>();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Deal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Dinner offer');
    await tester.enterText(find.byType(TextFormField).at(1), '15');
    await tester.ensureVisible(find.text('Create draft'));
    await tester.tap(find.text('Create draft'));
    await tester.pump();
    expect(repo.creates, 1);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
          .onPressed,
      isNull,
    );
    expect(repo.input!.endsAt.hour, 23);
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Create draft'), findsNothing);
    expect(find.text('Deal created as draft.'), findsOneWidget);
  });

  testWidgets('invalid values never submit; creation errors keep form open', (
    tester,
  ) async {
    final repo = Repo()..fail = true;
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Deal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Dinner offer');
    await tester.enterText(find.byType(TextFormField).at(1), '101');
    await tester.ensureVisible(find.text('Create draft'));
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();
    expect(repo.creates, 0);
    await tester.ensureVisible(find.byType(TextFormField).at(1));
    await tester.enterText(find.byType(TextFormField).at(1), '10');
    await tester.ensureVisible(find.text('Create draft'));
    await tester.tap(find.text('Create draft'));
    await tester.pumpAndSettle();
    expect(repo.creates, 1);
    expect(find.text('Create draft'), findsOneWidget);
    expect(find.textContaining('Could not save deal:'), findsOneWidget);
  });

  testWidgets('roles and verification restrict controls', (tester) async {
    await tester.pumpWidget(harness(Repo(), role: PartnerRole.staff));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'New Deal'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
          .enabled,
      isFalse,
    );
    await tester.pumpWidget(harness(Repo(), verified: false));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'New Deal'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Deal actions'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.widgetWithText(PopupMenuItem<String>, 'Publish deal'),
          )
          .enabled,
      isFalse,
    );
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
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(repo.reads, greaterThan(before));
  });

  testWidgets('pending lifecycle blocks repeats and reports failures', (
    tester,
  ) async {
    final repo = Repo()..pending = Completer<void>();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await action(tester, 'Publish deal');
    expect(repo.updates, 1);
    expect(
      tester
          .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
          .enabled,
      isFalse,
    );
    repo.fail = true;
    repo.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not update deal:'), findsOneWidget);
    expect(
      tester
          .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
          .enabled,
      isTrue,
    );
  });

  testWidgets('draft edit is prefilled and saves through existing PATCH', (
    tester,
  ) async {
    final repo = Repo();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();
    await action(tester, 'Edit draft');
    expect(find.text('Lunch deal'), findsNWidgets(2));
    await tester.ensureVisible(find.text('Save draft'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(repo.updates, 1);
    expect(find.text('Draft updated.'), findsOneWidget);
  });

  testWidgets('small screen, large text and keyboard keep form scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(harness(Repo()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('New Deal'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create draft'));
    expect(tester.takeException(), isNull);
  });
}
