import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'navigation/app_routes.dart';
import 'providers/app_providers.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/onboarding/onboarding_carousel.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Device preferences are resolved once, up front, and injected so no screen
  // ever awaits storage mid-build (see [sharedPreferencesProvider]).
  final prefs = await SharedPreferences.getInstance();

  // The onboarding carousel shows exactly once per device. After the user
  // finishes or skips it, `dinecircle.onboardingSeen` is persisted so every
  // subsequent cold start lands straight on AuthGate.
  final showOnboarding = prefs.getBool('dinecircle.onboardingSeen') != true;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) async => prefs),
      ],
      child: PartnerApp(showOnboarding: showOnboarding),
    ),
  );
}

/// Root of the DineCircle Partner app.
///
/// A single dark theme runs on both targets; [AuthGate] is the home surface and
/// decides what an operator actually sees from the session and venue scope, so a
/// cold start, a reload and a sign-out all land in the same place. The named
/// route table exists so web deep links (`/#/business?tab=menu`) resolve to the
/// same screens the shell navigates to.
class PartnerApp extends StatelessWidget {
  const PartnerApp({super.key, required this.showOnboarding});

  /// Whether the first-launch carousel has not yet been dismissed.
  final bool showOnboarding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DineCircle Partner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: showOnboarding
          ? const OnboardingCarousel()
          : const AuthGate(),
      // Every named route,bare or query-bearing,resolves through
      // [generateRoute] so all screens share the same fade-through transition
      // and sub-tab deep links (`/service?tab=checkin`) keep working.
      onGenerateRoute: generateRoute,
    );
  }
}
