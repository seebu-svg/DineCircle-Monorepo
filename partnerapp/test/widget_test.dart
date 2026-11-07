// Smoke test for the partner app root.
//
// The real [SessionController] reads flutter_secure_storage on build, which has
// no implementation under `flutter test`. We override it with a controller that
// resolves straight to signed-out, so the gate renders the login surface, the
// same decision the app makes for a fresh install, without touching plugins.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/main.dart';
import 'package:partnerapp/providers/app_providers.dart';

class _SignedOutSession extends SessionController {
  @override
  Future<SessionState> build() async => const SessionState.signedOut();
}

void main() {
  testWidgets('fresh install lands on the login surface', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_SignedOutSession.new)],
        child: const PartnerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DineCircle Partner'), findsOneWidget);
    expect(
      find.text('Sign in to manage your restaurant.'),
      findsOneWidget,
    );
  });
}
