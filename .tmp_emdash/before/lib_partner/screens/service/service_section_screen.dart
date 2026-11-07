import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_routes.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_tabs.dart';
import '../auth/auth_gate.dart';
import 'bookings_screen.dart';
import 'checkin_screen.dart';
import 'reservations_board.dart';
import 'tables_screen.dart';

/// The Operations desk: reservations, the door, ticket sales and the floor.
///
/// Four related surfaces behind one destination. The initial tab comes from the
/// route query (`/#/service?tab=checkin`) so a shared link or the browser back
/// button opens the right surface rather than always the day board.
class ServiceSectionScreen extends ConsumerWidget {
  const ServiceSectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(selectedVenueProvider);
    if (venue == null) return const AuthGate();

    final tab = routeQuery(context)['tab'];
    return AppShell(
      active: PrimaryDestination.business,
      title: 'Service',
      child: SectionTabs(
        initialTab: tab,
        tabs: const [
          SectionTab(
            key: 'reservations',
            label: 'Reservations',
            icon: Icons.event_available_outlined,
            child: ReservationsBoard(),
          ),
          SectionTab(
            key: 'checkin',
            label: 'Check-in',
            icon: Icons.how_to_reg_outlined,
            child: CheckinScreen(),
          ),
          SectionTab(
            key: 'bookings',
            label: 'Bookings',
            icon: Icons.confirmation_number_outlined,
            child: BookingsScreen(),
          ),
          SectionTab(
            key: 'tables',
            label: 'Tables & hours',
            icon: Icons.table_restaurant_outlined,
            child: _Padded(child: TablesScreen()),
          ),
        ],
      ),
    );
  }
}

/// Gives a `ListView`-less child the standard horizontal breathing room.
class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: child,
      );
}
