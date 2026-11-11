import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/deals.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/module_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/screens/business/qr_tab.dart';
import 'package:partnerapp/theme/app_theme.dart';
import 'package:partnerapp/utils/links.dart';
import 'package:partnerapp/widgets/qr_code_view.dart';

/// The QR screen is the printed artefact of the whole app: if the code does not
/// render, or the deal codes do not show, a desk has nothing to laminate. Both
/// reads are overridden so the tests never touch the network, and the last test
/// lays the screen out at a real 320px at 2.0 text scale, the width a phone
/// fixes a card at.
class _Scope extends VenueScopeController {
  _Scope({this.verified = true});

  final bool verified;

  @override
  Future<VenueScopeState> build() async => VenueScopeState(
    venues: [
      Venue(
        id: 'v1',
        name: 'Sea & Salt',
        city: 'Karachi',
        verified: verified,
        myRole: PartnerRole.owner,
      ),
    ],
    selectedId: 'v1',
  );
}

Deal _deal({String? code, String title = 'Weekday lunch'}) => Deal(
  id: 'd1',
  restaurantId: 'v1',
  title: title,
  kind: DealKind.percent,
  value: 20,
  status: DealStatus.active,
  startsAt: DateTime.now().subtract(const Duration(days: 1)),
  endsAt: DateTime.now().add(const Duration(days: 7)),
  code: code,
);

Widget _harness(List<Deal> deals, {bool verified = true}) => ProviderScope(
  overrides: [
    venueScopeProvider.overrideWith(() => _Scope(verified: verified)),
    dealsProvider.overrideWith((ref, key) => deals),
  ],
  child: MaterialApp(
    theme: AppTheme.dark,
    home: const Scaffold(body: QrTab()),
  ),
);

void main() {
  testWidgets('encodes the selected venue page as a scannable code', (
    tester,
  ) async {
    await tester.pumpWidget(_harness([_deal(code: 'LUNCH20')]));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Exactly one code on the screen: the venue's own public profile.
    expect(find.byType(QrImageView), findsOneWidget);
    expect(
      tester.widget<QrCodeView>(find.byType(QrCodeView)).data,
      venuePublicUrl('v1'),
    );
    expect(venuePublicUrl('v1'), 'https://dinecircle.app/venues/v1');
    expect(find.text('Restaurant QR'), findsOneWidget);
    // The venue URL is encoded into the QR code pixels, not rendered as text.
    expect(find.text('Sea & Salt'), findsAtLeastNWidgets(2));
  });

  testWidgets('lists the live deal codes a till can check', (tester) async {
    await tester.pumpWidget(
      _harness([_deal(code: 'LUNCH20'), _deal(title: 'No-code deal')]),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Live Deal Codes'));
    await tester.tap(find.text('Live Deal Codes'));
    await tester.pumpAndSettle();

    expect(find.text('LUNCH20'), findsOneWidget);
    expect(find.text('20% off'), findsNWidgets(2));
    // A deal without a code must say so rather than showing a blank row.
    expect(find.text('No promo code set'), findsOneWidget);
  });

  testWidgets('warns before an unverified venue prints its code', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(const [], verified: false));
    await tester.pumpAndSettle();

    expect(find.text('Not public yet'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('layouts at 320px with 2.0 text scale without overflowing', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _harness([_deal(code: 'LUNCH20'), _deal(title: 'No-code deal')]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
