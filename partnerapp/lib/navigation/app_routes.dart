import 'package:flutter/material.dart';

import '../screens/auth/auth_gate.dart';
import '../screens/auth/partner_gate_screen.dart';
import '../screens/business/business_section_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/experiences/experiences_section_screen.dart';
import '../screens/inbox/inbox_section_screen.dart';
import '../screens/onboarding/onboarding_carousel.dart';
import '../screens/onboarding/registration_wizard.dart';
import '../screens/onboarding/verification_status_screen.dart';
import '../screens/service/service_section_screen.dart';
import '../screens/settings/settings_screen.dart';

/// Named routes for the whole app.
///
/// Every destination has a real URL so a desk can share or bookmark one
/// (`/#/service?tab=checkin`), which is the only way the web build becomes
/// usable with a keyboard and a back button. Sub-tabs travel in the query,
/// detail records in the path.
class AppRoute {
  AppRoute._();

  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String partnerGate = '/not-a-partner';
  static const String registration = '/register';
  static const String verification = '/verification';
  static const String today = '/today';
  static const String service = '/service';
  static const String experiences = '/experiences';
  static const String business = '/business';
  static const String inbox = '/inbox';
  static const String settings = '/settings';

  static const String experienceDetail = '/experiences/detail';
  static const String requestDetail = '/experiences/request';
  static const String reservationDetail = '/service/reservation';
  static const String hoursEditor = '/business/hours';
  static const String supportNew = '/inbox/support/new';

  /// Tab-level entries of the Business section that are promoted to primary
  /// mobile tabs. They stay *inside* `/business`, one screen, one data
  /// scope, and only the `?tab=` differs, so shared links keep working.
  static const String menu = '$business?tab=menu';
  static const String deals = '$business?tab=deals';
  static const String insights = '$business?tab=analytics';
}

/// The five mobile tabs, in bar order.
///
/// Menu/Deals/Insights address Business sub-tabs through the query so the
/// former Service/Experiences/Inbox surfaces stay reachable from the Business
/// hub without inventing parallel screens for the same data.
enum PrimaryDestination {
  home(AppRoute.today, 'Home', Icons.home_outlined, Icons.home),
  menu(
    AppRoute.menu,
    'Menu',
    Icons.restaurant_menu_outlined,
    Icons.restaurant_menu,
  ),
  deals(AppRoute.deals, 'Deals', Icons.local_offer_outlined, Icons.local_offer),
  insights(
    AppRoute.insights,
    'Insights',
    Icons.query_stats_outlined,
    Icons.query_stats,
  ),
  business(
    AppRoute.business,
    'Business',
    Icons.storefront_outlined,
    Icons.storefront,
  );

  const PrimaryDestination(
    this.route,
    this.label,
    this.icon,
    this.selectedIcon,
  );

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Which tab should light up for a route name (query included).
  ///
  /// Several tabs share the `/business` root and differ only by `?tab=`, so
  /// the query is part of the match; the folded-in modules (service,
  /// experiences, inbox and their detail pages) read as the Business hub that
  /// links them, and anything unknown lands on Home like before.
  static int indexOf(String? route) {
    final name = route ?? '';
    final path = rootOf(name);
    if (path == AppRoute.today) return home.index;
    if (path == AppRoute.business) {
      return switch (queryOf(name)['tab']) {
        'menu' => menu.index,
        'deals' => deals.index,
        'analytics' => insights.index,
        _ => business.index,
      };
    }
    if (path.startsWith('${AppRoute.business}/') ||
        path.startsWith(AppRoute.service) ||
        path.startsWith(AppRoute.experiences) ||
        path.startsWith(AppRoute.inbox)) {
      return business.index;
    }
    return home.index;
  }
}

/// Folded-in modules and secondary Business surfaces, grouped, as launcher
/// tiles for the mobile Business hub. Reuses [SecondaryDestination] so the
/// web sidebar and the phone hub always point at the same working routes.
const List<SecondaryDestination> workspaceModules = [
  SecondaryDestination(
    route: AppRoute.business,
    label: 'Venue profile',
    icon: Icons.store_outlined,
    group: 'Business',
    tab: 'profile',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'Branches',
    icon: Icons.location_city_outlined,
    group: 'Business',
    tab: 'branches',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'Packages',
    icon: Icons.card_membership_outlined,
    group: 'Business',
    tab: 'packages',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'QR code',
    icon: Icons.qr_code_2,
    group: 'Business',
    tab: 'qr',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'Subscription',
    icon: Icons.card_giftcard_outlined,
    group: 'Business',
    tab: 'subscription',
  ),
  SecondaryDestination(
    route: AppRoute.service,
    label: 'Reservations',
    icon: Icons.event_available_outlined,
    group: 'Service',
    tab: 'reservations',
  ),
  SecondaryDestination(
    route: AppRoute.service,
    label: 'Check-in',
    icon: Icons.qr_code_scanner,
    group: 'Service',
    tab: 'checkin',
  ),
  SecondaryDestination(
    route: AppRoute.service,
    label: 'Bookings',
    icon: Icons.confirmation_number_outlined,
    group: 'Service',
    tab: 'bookings',
  ),
  SecondaryDestination(
    route: AppRoute.service,
    label: 'Tables & hours',
    icon: Icons.table_restaurant_outlined,
    group: 'Service',
    tab: 'tables',
  ),
  SecondaryDestination(
    route: AppRoute.experiences,
    label: 'Experience requests',
    icon: Icons.pending_actions_outlined,
    group: 'Experiences',
    tab: 'requests',
  ),
  SecondaryDestination(
    route: AppRoute.experiences,
    label: 'Host proposals',
    icon: Icons.handshake_outlined,
    group: 'Experiences',
    tab: 'proposals',
  ),
  SecondaryDestination(
    route: AppRoute.experiences,
    label: 'Experiences',
    icon: Icons.auto_awesome_outlined,
    group: 'Experiences',
    tab: 'experiences',
  ),
  SecondaryDestination(
    route: AppRoute.experiences,
    label: 'Hosts',
    icon: Icons.person_outline,
    group: 'Experiences',
    tab: 'hosts',
  ),
  SecondaryDestination(
    route: AppRoute.inbox,
    label: 'Reviews',
    icon: Icons.star_outline,
    group: 'Inbox',
    tab: 'reviews',
  ),
  SecondaryDestination(
    route: AppRoute.inbox,
    label: 'Support',
    icon: Icons.support_agent_outlined,
    group: 'Inbox',
    tab: 'support',
  ),
  SecondaryDestination(
    route: AppRoute.inbox,
    label: 'Notifications',
    icon: Icons.notifications_none,
    group: 'Inbox',
    tab: 'notifications',
  ),
];

/// Workspace tiles grouped for the hub, in first-seen order (mirrors
/// [sidebarGroups] so the two never drift apart).
List<List<SecondaryDestination>> get workspaceGroups {
  final ordered = <String, List<SecondaryDestination>>{};
  for (final item in workspaceModules) {
    ordered.putIfAbsent(item.group, () => []).add(item);
  }
  return ordered.values.toList(growable: false);
}

/// Admin/secondary destinations that live in the web sidebar but are reachable
/// from the profile menu on a phone.
class SecondaryDestination {
  const SecondaryDestination({
    required this.route,
    required this.label,
    required this.icon,
    required this.group,
    this.tab,
  });

  final String route;
  final String label;
  final IconData icon;
  final String group;

  /// The sub-tab to open inside a section screen.
  final String? tab;

  String get fullRoute => tab == null ? route : '$route?tab=$tab';
}

const List<SecondaryDestination> secondaryDestinations = [
  SecondaryDestination(
    route: AppRoute.today,
    label: 'Dashboard',
    icon: Icons.insights_outlined,
    group: 'Operations',
  ),
  SecondaryDestination(
    route: AppRoute.service,
    label: 'Reservations',
    icon: Icons.event_available_outlined,
    group: 'Operations',
    tab: 'reservations',
  ),
  SecondaryDestination(
    route: AppRoute.service,
    label: 'Check-in',
    icon: Icons.qr_code_scanner,
    group: 'Operations',
    tab: 'checkin',
  ),
  SecondaryDestination(
    route: AppRoute.service,
    label: 'Bookings',
    icon: Icons.confirmation_number_outlined,
    group: 'Operations',
    tab: 'bookings',
  ),
  SecondaryDestination(
    route: AppRoute.service,
    label: 'Tables & hours',
    icon: Icons.table_restaurant_outlined,
    group: 'Operations',
    tab: 'tables',
  ),
  SecondaryDestination(
    route: AppRoute.experiences,
    label: 'Experience requests',
    icon: Icons.pending_actions_outlined,
    group: 'Experiences',
    tab: 'requests',
  ),
  SecondaryDestination(
    route: AppRoute.experiences,
    label: 'Host proposals',
    icon: Icons.handshake_outlined,
    group: 'Experiences',
    tab: 'proposals',
  ),
  SecondaryDestination(
    route: AppRoute.experiences,
    label: 'Experiences',
    icon: Icons.auto_awesome_outlined,
    group: 'Experiences',
    tab: 'experiences',
  ),
  SecondaryDestination(
    route: AppRoute.experiences,
    label: 'Hosts',
    icon: Icons.person_outline,
    group: 'Experiences',
    tab: 'hosts',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'Venue profile',
    icon: Icons.store_outlined,
    group: 'Venue',
    tab: 'profile',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'Menu',
    icon: Icons.restaurant_menu_outlined,
    group: 'Venue',
    tab: 'menu',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'Deals',
    icon: Icons.local_offer_outlined,
    group: 'Venue',
    tab: 'deals',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'QR code',
    icon: Icons.qr_code_2,
    group: 'Venue',
    tab: 'qr',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'Subscription',
    icon: Icons.card_giftcard_outlined,
    group: 'Money',
    tab: 'subscription',
  ),
  SecondaryDestination(
    route: AppRoute.business,
    label: 'Analytics',
    icon: Icons.query_stats_outlined,
    group: 'Money',
    tab: 'analytics',
  ),
  SecondaryDestination(
    route: AppRoute.inbox,
    label: 'Reviews',
    icon: Icons.star_outline,
    group: 'Guests',
    tab: 'reviews',
  ),
  SecondaryDestination(
    route: AppRoute.inbox,
    label: 'Support',
    icon: Icons.support_agent_outlined,
    group: 'Guests',
    tab: 'support',
  ),
  SecondaryDestination(
    route: AppRoute.inbox,
    label: 'Notifications',
    icon: Icons.notifications_none,
    group: 'Admin',
    tab: 'notifications',
  ),
  SecondaryDestination(
    route: AppRoute.settings,
    label: 'Settings & security',
    icon: Icons.settings_outlined,
    group: 'Admin',
  ),
];

/// Destinations shown in the expanded sidebar, grouped.
List<List<SecondaryDestination>> get sidebarGroups {
  final ordered = <String, List<SecondaryDestination>>{};
  for (final item in secondaryDestinations) {
    ordered.putIfAbsent(item.group, () => []).add(item);
  }
  return ordered.values.toList(growable: false);
}

/// Path without the query string.
String rootOf(String route) {
  final cut = route.indexOf('?');
  return cut == -1 ? route : route.substring(0, cut);
}

/// Query parameters of the current route, decoded by [AppRoute] helpers.
Map<String, String> queryOf(String route) {
  final cut = route.indexOf('?');
  if (cut == -1) return const {};
  final query = Uri.splitQueryString(route.substring(cut + 1));
  return query.map((key, value) => MapEntry(key, value));
}

/// Reads the active route's parameters from inside a screen.
Map<String, String> routeQuery(BuildContext context) {
  final name = ModalRoute.of(context)?.settings.name ?? '';
  return queryOf(name);
}

/// A single [MaterialApp] route table plus the detail routes that carry ids.
Map<String, WidgetBuilder> get appRoutes => {
  AppRoute.onboarding: (_) => const OnboardingCarousel(),
  // Routed to the gate rather than a bare login screen: a successful sign-in
  // mutates the session, and only the gate reacts to that by swapping itself
  // for the workspace. A standalone LoginScreen would sit there signed in.
  AppRoute.login: (_) => const AuthGate(),
  AppRoute.partnerGate: (_) => const PartnerGateScreen(),
  AppRoute.registration: (_) => const RegistrationWizard(),
  AppRoute.verification: (_) => const VerificationStatusScreen(),
  AppRoute.today: (_) => const HomeScreen(),
  AppRoute.service: (_) => const ServiceSectionScreen(),
  AppRoute.experiences: (_) => const ExperiencesSectionScreen(),
  AppRoute.business: (_) => const BusinessSectionScreen(),
  AppRoute.inbox: (_) => const InboxSectionScreen(),
  AppRoute.settings: (_) => const SettingsScreen(),
};

/// Resolves any requested route, including the query-bearing sub-tab links the
/// shell and dashboard navigate to (`/service?tab=checkin`).
///
/// The named [appRoutes] table only matches the bare path, so without this the
/// Navigator throws "could not find a generator" the moment a tab query is
/// pushed, the whole point of the web build's shareable URLs. The generated
/// route keeps the *original* [RouteSettings] so each section screen can still
/// read its active tab back out of the name via [routeQuery].
Route<dynamic>? generateRoute(RouteSettings settings) {
  final name = settings.name ?? '';
  final builder = appRoutes[rootOf(name)];
  // Every destination the app navigates to has a registered root, so the
  // fallback only fires for a hand-typed or stale deep link; land the operator
  // on the dashboard (which redirects to sign-in when there is no venue)
  // rather than crashing on an unresolvable route.
  return _FadeThroughRoute(builder ?? (_) => const HomeScreen(), settings);
}

/// A short fade-through page transition (180ms) shared by every generated
/// route, so tab switches read as one continuous surface rather than a hard
/// slide. Honors `MediaQuery.disableAnimations`, users who ask for reduced
/// motion get an instant swap, no fades at all.
class _FadeThroughRoute extends PageRouteBuilder<dynamic> {
  _FadeThroughRoute(WidgetBuilder builder, RouteSettings settings)
    : super(
        settings: settings,
        opaque: false,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
            return child;
          }
          // Incoming page fades in over the back half of the transition while
          // the outgoing page (whose `secondaryAnimation` drives it) fades out
          // over the front half, the Material "fade through" pattern.
          final incoming = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.35, 1, curve: Curves.easeOut),
          );
          final outgoing = CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0, 0.65, curve: Curves.easeOut),
          );
          return FadeTransition(
            opacity: incoming,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(outgoing),
              child: child,
            ),
          );
        },
      );
}
