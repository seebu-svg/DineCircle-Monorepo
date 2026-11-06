import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:partnerapp/api/api_client.dart';
import 'package:partnerapp/models/account.dart';
import 'package:partnerapp/models/catalog.dart';
import 'package:partnerapp/models/venue.dart';
import 'package:partnerapp/providers/app_providers.dart';
import 'package:partnerapp/providers/venue_scope_provider.dart';
import 'package:partnerapp/repositories/menu_repository.dart';
import 'package:partnerapp/screens/business/menu_tab.dart';
import 'package:partnerapp/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _venueId = 'v1';

const _user = PartnerUser(
  id: 'u1',
  name: 'Ada Owner',
  role: 'restaurant_owner',
);

const _venue = Venue(
  id: _venueId,
  name: 'Sea & Salt',
  city: 'Karachi',
  cuisines: ['Seafood'],
  myRole: PartnerRole.owner,
  verified: true,
);

MenuSection section(
  String id,
  String name, {
  int position = 0,
  bool isActive = true,
  List<MenuItem> items = const [],
}) =>
    MenuSection(
      id: id,
      restaurantId: _venueId,
      name: name,
      position: position,
      isActive: isActive,
      items: items,
    );

MenuItem item(
  String id,
  String name, {
  required String sectionId,
  double price = 1450,
  int position = 0,
  bool isAvailable = true,
  List<String> dietaryTags = const [],
  String photoUrl = '',
  String description = '',
}) =>
    MenuItem(
      id: id,
      restaurantId: _venueId,
      sectionId: sectionId,
      name: name,
      description: description,
      price: price,
      position: position,
      isAvailable: isAvailable,
      dietaryTags: dietaryTags,
      photoUrl: photoUrl,
    );

// ---------------------------------------------------------------------------
// Fake MenuRepository
// ---------------------------------------------------------------------------

/// A [MenuRepository] backed by a fake [ApiClient] that never hits the network.
///
/// Tests configure [menuData] and flip [menuShouldFail] / [publicMenuShouldFail]
/// to control what the async methods return, and read the `*Calls` counters
/// afterwards to verify side-effects.
class FakeMenuRepository extends MenuRepository {
  FakeMenuRepository() : super(ApiClient(dio: Dio()));

  int deleteSectionCalls = 0;
  int deleteItemCalls = 0;
  int setAvailabilityCalls = 0;
  int reorderSectionsCalls = 0;
  int reorderItemsCalls = 0;
  int publicMenuCalls = 0;
  int createSectionCalls = 0;
  int createItemCalls = 0;
  int updateSectionCalls = 0;
  int updateItemCalls = 0;
  String? lastDeletedSectionId;
  String? lastDeletedItemId;
  List<String>? lastAvailabilityItemIds;
  bool? lastAvailabilityValue;

  List<MenuSection> menuData = const [];
  bool menuShouldFail = false;
  bool publicMenuShouldFail = false;

  @override
  Future<List<MenuSection>> menu(String venueId) async {
    if (menuShouldFail) throw Exception('Network error');
    return menuData;
  }

  @override
  Future<PublicMenu> publicMenu(String venueId) async {
    publicMenuCalls++;
    if (publicMenuShouldFail) throw Exception('Network error');
    return PublicMenu(
      restaurant: const PublicMenuRestaurant(
        id: _venueId,
        name: 'Sea & Salt',
        city: 'Karachi',
      ),
      sections: menuData,
    );
  }

  @override
  Future<void> deleteSection(String venueId, String sectionId) async {
    deleteSectionCalls++;
    lastDeletedSectionId = sectionId;
  }

  @override
  Future<void> deleteItem(String venueId, String itemId) async {
    deleteItemCalls++;
    lastDeletedItemId = itemId;
  }

  @override
  Future<List<String>> setAvailability(
    String venueId,
    List<String> itemIds, {
    required bool isAvailable,
  }) async {
    setAvailabilityCalls++;
    lastAvailabilityItemIds = itemIds;
    lastAvailabilityValue = isAvailable;
    return itemIds;
  }

  @override
  Future<void> reorderSections(
    String venueId,
    List<MenuSection> ordered,
  ) async {
    reorderSectionsCalls++;
  }

  @override
  Future<void> reorderItems(String venueId, List<MenuItem> ordered) async {
    reorderItemsCalls++;
  }

  @override
  Future<MenuSection> createSection(
    String venueId, {
    required String name,
    int position = 0,
    bool isActive = true,
    String? branchId,
  }) async {
    createSectionCalls++;
    return MenuSection(
      id: 'new-s',
      restaurantId: venueId,
      name: name,
      position: position,
      isActive: isActive,
    );
  }

  @override
  Future<MenuSection> updateSection(
    String venueId,
    String sectionId, {
    String? name,
    int? position,
    bool? isActive,
  }) async {
    updateSectionCalls++;
    return MenuSection(
      id: sectionId,
      restaurantId: venueId,
      name: name ?? 'updated',
      position: position ?? 0,
      isActive: isActive ?? true,
    );
  }

  @override
  Future<MenuItem> createItem(
    String venueId, {
    required String sectionId,
    required String name,
    required double price,
    String description = '',
    int position = 0,
    bool isAvailable = true,
    List<String> dietaryTags = const [],
    String photoUrl = '',
  }) async {
    createItemCalls++;
    return MenuItem(
      id: 'new-i',
      restaurantId: venueId,
      sectionId: sectionId,
      name: name,
      price: price,
      position: position,
      isAvailable: isAvailable,
      dietaryTags: dietaryTags,
      photoUrl: photoUrl,
    );
  }

  @override
  Future<MenuItem> updateItem(
    String venueId,
    String itemId, {
    String? sectionId,
    String? name,
    String? description,
    double? price,
    int? position,
    bool? isAvailable,
    List<String>? dietaryTags,
    String? photoUrl,
  }) async {
    updateItemCalls++;
    return MenuItem(
      id: itemId,
      restaurantId: venueId,
      sectionId: sectionId ?? 's1',
      name: name ?? 'updated',
      description: description ?? '',
      price: price ?? 0,
      position: position ?? 0,
      isAvailable: isAvailable ?? true,
      dietaryTags: dietaryTags ?? const [],
      photoUrl: photoUrl ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

class _VenueScope extends VenueScopeController {
  @override
  Future<VenueScopeState> build() async =>
      VenueScopeState(venues: const [_venue], selectedId: _venue.id);
}

Widget harness(
  WidgetTester tester, {
  required FakeMenuRepository repo,
  List<MenuSection>? menuData,
  Size surface = const Size(900, 2400),
}) {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  if (menuData != null) repo.menuData = menuData;

  return ProviderScope(
    overrides: [
      venueScopeProvider.overrideWith(_VenueScope.new),
      currentUserProvider.overrideWithValue(_user),
      isPlatformAdminProvider.overrideWithValue(false),
      menuRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(body: MenuTab()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('Menu tab — rendering', () {
    testWidgets('shows sections and items with PKR prices', (tester) async {
      final repo = FakeMenuRepository();
      final sections = [
        section('s1', 'Starters', items: [
          item('i1', 'Calamari',
              sectionId: 's1', price: 850, dietaryTags: ['Seafood']),
          item('i2', 'Bruschetta',
              sectionId: 's1',
              price: 650,
              dietaryTags: ['Vegetarian'],
              description: 'Toasted bread with tomatoes'),
        ]),
        section('s2', 'Mains', position: 1, items: [
          item('i3', 'Grilled Salmon',
              sectionId: 's2', price: 2450, dietaryTags: ['Spicy']),
        ]),
      ];

      await tester.pumpWidget(harness(tester, repo: repo, menuData: sections));
      await tester.pumpAndSettle();

      // Section names render.
      expect(find.text('STARTERS'), findsOneWidget);
      expect(find.text('MAINS'), findsOneWidget);

      // Item names render.
      expect(find.text('Calamari'), findsOneWidget);
      expect(find.text('Bruschetta'), findsOneWidget);
      expect(find.text('Grilled Salmon'), findsOneWidget);

      // Prices in PKR, never $.
      expect(find.text('Rs 850'), findsOneWidget);
      expect(find.text('Rs 650'), findsOneWidget);
      expect(find.text('Rs 2450'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);

      // Dietary tags render uppercased.
      expect(find.text('SEAFOOD'), findsOneWidget);
      expect(find.text('VEGETARIAN'), findsOneWidget);
      expect(find.text('SPICY'), findsOneWidget);
    });

    testWidgets('shows live status pill in header', (tester) async {
      final repo = FakeMenuRepository();
      await tester.pumpWidget(
        harness(tester, repo: repo, menuData: [section('s1', 'Starters')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live in Customer App'), findsOneWidget);
    });

    testWidgets('summary strip shows section and item counts', (tester) async {
      final repo = FakeMenuRepository();
      final sections = [
        section('s1', 'Starters', items: [
          item('i1', 'A', sectionId: 's1'),
          item('i2', 'B', sectionId: 's1', isAvailable: false),
        ]),
      ];

      await tester.pumpWidget(harness(tester, repo: repo, menuData: sections));
      await tester.pumpAndSettle();

      // The MenuSummaryStrip shows counts.
      expect(find.text('1'), findsWidgets); // 1 section
      expect(find.text('2'), findsWidgets); // 2 items
    });

    testWidgets('empty state when no sections', (tester) async {
      final repo = FakeMenuRepository();
      await tester.pumpWidget(
        harness(tester, repo: repo, menuData: const []),
      );
      await tester.pumpAndSettle();

      expect(find.text('No menu yet'), findsOneWidget);
    });

    testWidgets('error state with retry', (tester) async {
      final repo = FakeMenuRepository()..menuShouldFail = true;
      await tester.pumpWidget(harness(tester, repo: repo));
      await tester.pumpAndSettle();

      // AsyncView shows a 'Try again' button on error.
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Menu tab — availability toggle', () {
    testWidgets('sold-out switch calls setAvailability', (tester) async {
      final repo = FakeMenuRepository();
      final sections = [
        section('s1', 'Starters', items: [
          item('i1', 'Calamari', sectionId: 's1', isAvailable: true),
        ]),
      ];

      await tester.pumpWidget(harness(tester, repo: repo, menuData: sections));
      await tester.pumpAndSettle();

      // Find the Switch widget and toggle it off.
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(repo.setAvailabilityCalls, 1);
      expect(repo.lastAvailabilityItemIds, ['i1']);
      expect(repo.lastAvailabilityValue, false);
    });
  });

  group('Menu tab — section jump chips', () {
    testWidgets('jump chips render for each section', (tester) async {
      final repo = FakeMenuRepository();
      final sections = [
        section('s1', 'Starters'),
        section('s2', 'Mains'),
        section('s3', 'Desserts'),
      ];

      await tester.pumpWidget(harness(tester, repo: repo, menuData: sections));
      await tester.pumpAndSettle();

      // SectionJumpChips renders each section name.
      expect(find.text('Starters'), findsWidgets);
      expect(find.text('Mains'), findsWidgets);
      expect(find.text('Desserts'), findsWidgets);
    });
  });

  group('Menu tab — action buttons', () {
    testWidgets('header shows Preview, Reorder, Section buttons',
        (tester) async {
      final repo = FakeMenuRepository();
      await tester.pumpWidget(
        harness(tester, repo: repo, menuData: [section('s1', 'Starters')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Reorder'), findsOneWidget);
      expect(find.text('Section'), findsOneWidget);
    });
  });

  group('CollapsibleSectionCard', () {
    testWidgets('shows hidden badge for inactive section', (tester) async {
      final repo = FakeMenuRepository();
      final sections = [
        section('s1', 'Starters', isActive: false),
      ];

      await tester.pumpWidget(harness(tester, repo: repo, menuData: sections));
      await tester.pumpAndSettle();

      expect(find.text('HIDDEN'), findsOneWidget);
    });

    testWidgets('shows sold out badge for unavailable item', (tester) async {
      final repo = FakeMenuRepository();
      final sections = [
        section('s1', 'Starters', items: [
          item('i1', 'Calamari', sectionId: 's1', isAvailable: false),
        ]),
      ];

      await tester.pumpWidget(harness(tester, repo: repo, menuData: sections));
      await tester.pumpAndSettle();

      expect(find.text('SOLD OUT'), findsOneWidget);
    });
  });

  group('Menu tab — position badges', () {
    testWidgets('items show numbered position badges', (tester) async {
      final repo = FakeMenuRepository();
      final sections = [
        section('s1', 'Starters', items: [
          item('i1', 'First', sectionId: 's1', position: 0),
          item('i2', 'Second', sectionId: 's1', position: 1),
          item('i3', 'Third', sectionId: 's1', position: 2),
        ]),
      ];

      await tester.pumpWidget(harness(tester, repo: repo, menuData: sections));
      await tester.pumpAndSettle();

      // Position badges: 1, 2, 3
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);
    });
  });
}
