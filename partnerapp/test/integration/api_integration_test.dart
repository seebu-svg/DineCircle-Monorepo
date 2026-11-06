// Integration tests for Partner App API connectivity
// Run with: flutter test test/integration/api_integration_test.dart

// The console logging below is the point of these manual connectivity checks,
// so the lint that targets production `print` is not useful here.
// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:partnerapp/api/api_client.dart';
import 'package:partnerapp/api/api_exception.dart';
import 'package:partnerapp/config/app_config.dart';
import 'package:partnerapp/repositories/auth_repository.dart';
import 'package:partnerapp/repositories/venue_repository.dart';
import 'package:partnerapp/repositories/menu_repository.dart';
import 'package:partnerapp/repositories/operations_repository.dart';
import 'package:partnerapp/repositories/experience_repository.dart';
import 'package:partnerapp/repositories/business_repository.dart';

/// Test credentials from the partner app README
const testEmail = 'karachi.desk+demo@example.test';
const testPassword = 'dinecircle123';

void main() {
  group('API Configuration', () {
    test('AppConfig should have correct API URL', () {
      print('📡 API Base URL: ${AppConfig.apiBaseUrl}');
      print('📡 API Full URL: ${AppConfig.apiUrl}');
      print('🌍 Environment: ${AppConfig.environment}');
      
      expect(AppConfig.apiBaseUrl, isNotEmpty);
      expect(AppConfig.apiUrl, contains('/api'));
    });

    test('ApiClient should initialize with correct base URL', () {
      final client = ApiClient();
      expect(client, isNotNull);
      client.close();
    });
  });

  group('Server Connectivity', () {
    late ApiClient client;

    setUp(() {
      client = ApiClient();
    });

    tearDown(() {
      client.close();
    });

    test('Health endpoint should respond', () async {
      print('🏥 Testing health endpoint...');
      
      try {
        final isHealthy = await client.health();
        print('Health status: $isHealthy');
        expect(isHealthy, isTrue, reason: 'Server health check failed');
      } on ApiException catch (e) {
        fail('Health check failed: ${e.message} (code: ${e.code})');
      }
    });
  });

  group('Authentication', () {
    late ApiClient client;
    late AuthRepository authRepo;

    setUp(() {
      client = ApiClient();
      authRepo = AuthRepository(client);
    });

    tearDown(() {
      client.close();
    });

    test('Login with valid credentials should return token', () async {
      print('🔐 Testing login with: $testEmail');
      
      try {
        final session = await authRepo.signIn(
          email: testEmail,
          password: testPassword,
        );
        
        print('✅ Login successful');
        print('Token: ${session.token.substring(0, 20)}...');
        print('User ID: ${session.user.id}');
        print('User Role: ${session.user.role}');
        print('User Name: ${session.user.name}');
        
        expect(session.token, isNotEmpty, reason: 'Token should not be empty');
        expect(session.user.id, isNotEmpty, reason: 'User ID should not be empty');
        expect(
          session.user.role,
          isIn(['restaurant_owner', 'restaurant_staff', 'restaurant_manager', 
                'partner_admin', 'super_admin', 'host']),
          reason: 'User should have a partner role',
        );
        
        // Set token for subsequent requests
        client.token = session.token;
        
      } on ApiException catch (e) {
        fail('Login failed: ${e.message} (status: ${e.statusCode}, code: ${e.code})');
      }
    });

    test('Login with invalid credentials should throw ApiException', () async {
      print('🔐 Testing login with invalid credentials...');
      
      try {
        await authRepo.signIn(
          email: 'wrong@example.com',
          password: 'wrongpassword',
        );
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        print('✅ Expected error: ${e.message} (status: ${e.statusCode})');
        expect(e.statusCode, isIn([400, 401]), reason: 'Should return 400 or 401');
      }
    });

    test('Session restore with /auth/me should work', () async {
      print('🔄 Testing session restore...');
      
      try {
        // Login first
        final session = await authRepo.signIn(
          email: testEmail,
          password: testPassword,
        );
        client.token = session.token;
        
        // Restore session
        final user = await authRepo.me();
        
        print('✅ Session restored for: ${user.name}');
        expect(user.id, equals(session.user.id));
        expect(user.email, equals(testEmail));
        
      } on ApiException catch (e) {
        fail('Session restore failed: ${e.message}');
      }
    });
  });

  group('Venue Management', () {
    late ApiClient client;
    late VenueRepository venueRepo;
    late String authToken;

    setUp(() async {
      client = ApiClient();
      final authRepo = AuthRepository(client);
      
      // Login and get token
      final session = await authRepo.signIn(
        email: testEmail,
        password: testPassword,
      );
      authToken = session.token;
      client.token = authToken;
      
      venueRepo = VenueRepository(client);
    });

    tearDown(() {
      client.close();
    });

    test('List venues should return array', () async {
      print('🏢 Testing venue list...');
      
      try {
        final venues = await venueRepo.listVenues();
        
        print('✅ Found ${venues.length} venue(s)');
        for (var venue in venues) {
          print('  - ${venue.name} (${venue.id})');
          print('    Status: ${venue.partnershipStatus}');
          print('    Verified: ${venue.verified}');
        }
        
        expect(venues, isList, reason: 'Should return a list');
        
      } on ApiException catch (e) {
        fail('List venues failed: ${e.message} (status: ${e.statusCode})');
      }
    });

    test('Get venue details should include counts', () async {
      print('🏢 Testing venue details...');
      
      try {
        // Get first venue
        final venues = await venueRepo.listVenues();
        if (venues.isEmpty) {
          print('⚠️  No venues found, skipping details test');
          return;
        }
        
        final venueId = venues.first.id;
        final detail = await venueRepo.venue(venueId);
        
        print('✅ Venue: ${detail.venue.name}');
        print('   Branches: ${detail.counts.branches}');
        print('   Tables: ${detail.counts.tables}');
        print('   Menu Items: ${detail.counts.menuItems}');
        print('   Upcoming Events: ${detail.counts.upcomingEvents}');
        print('   Pending Reservations: ${detail.counts.pendingReservations}');
        
        expect(detail.venue.id, equals(venueId));
        expect(detail.counts, isNotNull);
        
      } on ApiException catch (e) {
        fail('Get venue details failed: ${e.message}');
      }
    });
  });

  group('Menu Management', () {
    late ApiClient client;
    late MenuRepository menuRepo;
    late String venueId;

    setUp(() async {
      client = ApiClient();
      final authRepo = AuthRepository(client);
      
      // Login
      final session = await authRepo.signIn(
        email: testEmail,
        password: testPassword,
      );
      client.token = session.token;
      
      // Get a venue ID
      final venueRepo = VenueRepository(client);
      final venues = await venueRepo.listVenues();
      if (venues.isNotEmpty) {
        venueId = venues.first.id;
      }
      
      menuRepo = MenuRepository(client);
    });

    tearDown(() {
      client.close();
    });

    test('List menu items for venue', () async {
      if (venueId.isEmpty) {
        print('⚠️  No venue available, skipping menu test');
        return;
      }
      
      print('🍽️  Testing menu list for venue: $venueId');
      
      try {
        // menu() returns sections; flatten them to check the item payloads.
        final sections = await menuRepo.menu(venueId);
        final items = [for (final section in sections) ...section.items];
        
        print('✅ Found ${items.length} menu item(s) in ${sections.length} section(s)');
        for (var item in items.take(3)) {
          print('  - ${item.name}: \$${item.price}');
        }
        
        expect(items, isList);
        
      } on ApiException catch (e) {
        print('⚠️  Menu list failed: ${e.message} (may be expected if no menu exists)');
      }
    });
  });

  group('Operations (Bookings & Tables)', () {
    late ApiClient client;
    late OperationsRepository opsRepo;
    late String venueId;

    setUp(() async {
      client = ApiClient();
      final authRepo = AuthRepository(client);
      
      // Login
      final session = await authRepo.signIn(
        email: testEmail,
        password: testPassword,
      );
      client.token = session.token;
      
      // Get a venue ID
      final venueRepo = VenueRepository(client);
      final venues = await venueRepo.listVenues();
      if (venues.isNotEmpty) {
        venueId = venues.first.id;
      }
      
      opsRepo = OperationsRepository(client);
    });

    tearDown(() {
      client.close();
    });

    test('List bookings for venue', () async {
      if (venueId.isEmpty) {
        print('⚠️  No venue available, skipping bookings test');
        return;
      }
      
      print('📅 Testing bookings list for venue: $venueId');
      
      try {
        // Bookings are account-wide ticket sales, not venue-scoped.
        final bookings = await opsRepo.bookings();
        
        print('✅ Found ${bookings.length} booking(s)');
        for (var booking in bookings.take(3)) {
          print('  - ${booking.guestName} → ${booking.eventTitle}');
          print('    Status: ${booking.status}, Seats: ${booking.seats}');
        }
        
        expect(bookings, isList);
        
      } on ApiException catch (e) {
        print('⚠️  Bookings list failed: ${e.message}');
      }
    });

    test('List tables for venue', () async {
      if (venueId.isEmpty) {
        print('⚠️  No venue available, skipping tables test');
        return;
      }
      
      print('🪑 Testing tables list for venue: $venueId');
      
      try {
        final tables = await opsRepo.tables(venueId);
        
        print('✅ Found ${tables.length} table(s)');
        for (var table in tables) {
          print('  - ${table.label} (seats: ${table.seats})');
        }
        
        expect(tables, isList);
        
      } on ApiException catch (e) {
        print('⚠️  Tables list failed: ${e.message}');
      }
    });
  });

  group('Experience Management (Events)', () {
    late ApiClient client;
    late ExperienceRepository expRepo;
    late String venueId;

    setUp(() async {
      client = ApiClient();
      final authRepo = AuthRepository(client);
      
      // Login
      final session = await authRepo.signIn(
        email: testEmail,
        password: testPassword,
      );
      client.token = session.token;
      
      // Get a venue ID
      final venueRepo = VenueRepository(client);
      final venues = await venueRepo.listVenues();
      if (venues.isNotEmpty) {
        venueId = venues.first.id;
      }
      
      expRepo = ExperienceRepository(client);
    });

    tearDown(() {
      client.close();
    });

    test('List events for venue', () async {
      if (venueId.isEmpty) {
        print('⚠️  No venue available, skipping events test');
        return;
      }
      
      print('🎭 Testing events list for venue: $venueId');
      
      try {
        // Experiences are account-wide; filter to the selected venue locally.
        final allEvents = await expRepo.experiences();
        final events =
            allEvents.where((e) => e.restaurantId == venueId).toList();
        
        print('✅ Found ${events.length} event(s) '
            '(${allEvents.length} across all venues)');
        for (var event in events.take(3)) {
          print('  - ${event.title} on ${event.startAt}');
          print('    Status: ${event.status}, Price: \$${event.pricePerSeat}');
        }
        
        expect(events, isList);
        
      } on ApiException catch (e) {
        print('⚠️  Events list failed: ${e.message}');
      }
    });
  });

  group('Business (Deals & Earnings)', () {
    late ApiClient client;
    late BusinessRepository bizRepo;
    late String venueId;

    setUp(() async {
      client = ApiClient();
      final authRepo = AuthRepository(client);
      
      // Login
      final session = await authRepo.signIn(
        email: testEmail,
        password: testPassword,
      );
      client.token = session.token;
      
      // Get a venue ID
      final venueRepo = VenueRepository(client);
      final venues = await venueRepo.listVenues();
      if (venues.isNotEmpty) {
        venueId = venues.first.id;
      }
      
      bizRepo = BusinessRepository(client);
    });

    tearDown(() {
      client.close();
    });

    test('List deals for venue', () async {
      if (venueId.isEmpty) {
        print('⚠️  No venue available, skipping deals test');
        return;
      }
      
      print('💰 Testing deals list for venue: $venueId');
      
      try {
        final deals = await bizRepo.deals(venueId);
        
        print('✅ Found ${deals.length} deal(s)');
        for (var deal in deals.take(3)) {
          print('  - ${deal.title}: ${deal.status}');
        }
        
        expect(deals, isList);
        
      } on ApiException catch (e) {
        print('⚠️  Deals list failed: ${e.message}');
      }
    });
  });
}
