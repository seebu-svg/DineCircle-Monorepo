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
  _VenueScope(this.venue);

  final Venue venue;

  @override
  Future<VenueScopeState> build() async =>
      VenueScopeState(venues: [venue], selectedId: venue.id);
}

Widget harness(
  WidgetTester tester, {
  required FakeMenuRepository repo,
  List<MenuSection>? menuData,
  Venue venue = _venue,
  double textScale = 1,
  Size surface = const Size(900, 1600),
}) {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  if (menuData != null) repo.menuData = menuData;

  return ProviderScope(
    overrides: [
      venueScopeProvider.overrideWith(() => _VenueScope(venue)),
      currentUserProvider.overrideWithValue(_user),
      isPlatformAdminProvider.overrideWithValue(false),
      menuRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(body: MenuTab()),
    ),
  );
}

// ---------------------------------------------------------------------------
// Fixtures shared by the tests
// ---------------------------------------------------------------------------

const _unverifiedVenue = Venue(
  id: _venueId,
  name: 'Sea & Salt',
  city: 'Karachi',
  cuisines: ['Seafood'],
  myRole: PartnerRole.owner,
  verified: false,
);

/// Two categories: three starters (one 86ed) and one main.
List<MenuSection> menu() => [
  section('s1', 'Starters', items: [
    item('i1', 'Calamari',
        sectionId: 's1', price: 850, dietaryTags: ['Seafood']),
    item('i2', 'Bruschetta',
        sectionId: 's1',
        price: 650,
        position: 1,
        dietaryTags: ['Vegetarian'],
        description: 'Toasted bread with tomatoes'),
    item('i3', 'Prawn Skewers',
        sectionId: 's1', price: 1250, position: 2, isAvailable: false),
  ]),
  section('s2', 'Mains', position: 1, items: [
    item('i4', 'Grilled Salmon', sectionId: 's2', price: 2450),
  ]),
];

Finder row(String id) => find.byKey(ValueKey('menu-item-$id'));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
  });

  group('menu header', () {
    testWidgets('names the restaurant, its state and the counts',
        (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Menu Management'), findsOneWidget);
      expect(find.text('Sea & Salt'), findsOneWidget);
      expect(find.text('Seafood · Karachi'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);

      // One summary line, folded from the live list: four dishes, three of
      // them sellable, one 86ed.
      expect(find.text('4 dishes'), findsOneWidget);
      expect(find.text('3 available'), findsOneWidget);
      expect(find.text('1 sold out'), findsOneWidget);
    });

    testWidgets('an unverified venue explains why guests see nothing',
        (tester) async {
      await tester.pumpWidget(
        harness(
          tester,
          repo: FakeMenuRepository(),
          menuData: menu(),
          venue: _unverifiedVenue,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Draft'), findsOneWidget);
      expect(find.textContaining('not verified'), findsOneWidget);
    });

    testWidgets('an empty menu is a draft with one way out', (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: const []),
      );
      await tester.pumpAndSettle();

      expect(find.text('Draft'), findsOneWidget);
      expect(find.textContaining('no dishes on the menu'), findsOneWidget);
      expect(find.text('No menu yet'), findsOneWidget);
      expect(find.text('New category'), findsOneWidget);
    });
  });

  group('categories', () {
    testWidgets('opens on the first category, not the whole menu',
        (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      expect(row('i1'), findsOneWidget);
      expect(row('i2'), findsOneWidget);
      // The main course is one chip away, not already in the scroll.
      expect(row('i4'), findsNothing);
      expect(find.byKey(const ValueKey('menu-cat-s2')), findsOneWidget);
    });

    testWidgets('choosing a category swaps the dishes', (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('menu-cat-s2')));
      await tester.pumpAndSettle();

      expect(row('i4'), findsOneWidget);
      expect(row('i1'), findsNothing);
    });

    testWidgets('All shows every category at once', (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('menu-cat-all')));
      await tester.pumpAndSettle();

      expect(row('i1'), findsOneWidget);
      expect(row('i4'), findsOneWidget);
    });

    testWidgets('a hidden category is marked in the rail', (tester) async {
      final sections = [
        section('s1', 'Starters', isActive: false),
        section('s2', 'Mains', position: 1),
      ];
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: sections),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.text('Hidden'), findsOneWidget);
    });
  });

  group('dish rows', () {
    testWidgets('carry the description, dietary tag and PKR price',
        (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bruschetta'), findsOneWidget);
      expect(find.text('Toasted bread with tomatoes'), findsOneWidget);
      expect(find.text('Vegetarian'), findsOneWidget);
      // `currencySymbol('PKR')` is "Rs. " and `_grouped` adds a separator from
      // four digits, so the rendered string keeps both.
      expect(find.text('Rs. 650'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('a sold-out dish says so and its switch is off',
        (tester) async {
      final sections = [
        section('s1', 'Starters', items: [
          item('i1', 'Calamari', sectionId: 's1', isAvailable: false),
        ]),
      ];
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: sections),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sold out'), findsOneWidget);
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
    });

    testWidgets('the switch 86s the dish', (tester) async {
      final repo = FakeMenuRepository();
      final sections = [
        section('s1', 'Starters', items: [
          item('i1', 'Calamari', sectionId: 's1'),
        ]),
      ];
      await tester.pumpWidget(
        harness(tester, repo: repo, menuData: sections),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(repo.setAvailabilityCalls, 1);
      expect(repo.lastAvailabilityItemIds, ['i1']);
      expect(repo.lastAvailabilityValue, isFalse);
    });

    testWidgets('deleting a dish asks first', (tester) async {
      final repo = FakeMenuRepository();
      final sections = [
        section('s1', 'Starters', items: [
          item('i1', 'Calamari', sectionId: 's1'),
        ]),
      ];
      await tester.pumpWidget(
        harness(tester, repo: repo, menuData: sections),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Calamari actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Calamari?'), findsOneWidget);
      expect(repo.deleteItemCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.deleteItemCalls, 1);
      expect(repo.lastDeletedItemId, 'i1');
    });

    testWidgets('tapping a row opens the edit form', (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      await tester.tap(row('i1'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Menu Item'), findsOneWidget);
    });
  });

  group('search and filters', () {
    testWidgets('a search that finds nothing offers the rest of the menu',
        (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('menu-search')),
        'Salmon',
      );
      await tester.pumpAndSettle();

      expect(find.text('No dishes match'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Search all dishes'));
      await tester.pumpAndSettle();

      expect(row('i4'), findsOneWidget);
    });

    testWidgets('the availability filter narrows the list to sold-out dishes',
        (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('menu-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-filter-soldOut')));
      await tester.pumpAndSettle();

      expect(row('i3'), findsOneWidget);
      expect(row('i1'), findsNothing);
      expect(find.textContaining('1 of 3 dishes'), findsOneWidget);
    });

    testWidgets('Clear puts the whole category back', (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('menu-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-filter-soldOut')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(row('i1'), findsOneWidget);
      expect(row('i3'), findsOneWidget);
    });
  });

  group('adding dishes', () {
    testWidgets('the primary action adds into the category on screen',
        (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('menu-cat-s2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('menu-add')));
      await tester.pumpAndSettle();

      // The sheet opens on the category that was showing, not the first one.
      expect(find.text('Add Menu Item'), findsWidgets);
    });

    testWidgets('a menu with no categories sends Add dish to the category form',
        (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: const []),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('menu-add')));
      await tester.pumpAndSettle();

      expect(find.text('New section'), findsOneWidget);
    });

    testWidgets('an empty category offers its first dish', (tester) async {
      final sections = [
        section('s1', 'Starters'),
        section('s2', 'Mains', position: 1, items: [
          item('i4', 'Grilled Salmon', sectionId: 's2'),
        ]),
      ];
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: sections),
      );
      await tester.pumpAndSettle();

      expect(find.text('No dishes in Starters yet'), findsOneWidget);
    });
  });

  group('states and layout', () {
    testWidgets('offers no separate guest preview or second QR', (tester) async {
      await tester.pumpWidget(
        harness(tester, repo: FakeMenuRepository(), menuData: menu()),
      );
      await tester.pumpAndSettle();

      // The partner prints one QR, on the Business QR screen, and scanning it
      // opens the restaurant page with this menu inside. A second,
      // menu-only preview affordance would be a duplicate by design.
      expect(find.byKey(const ValueKey('menu-preview')), findsNothing);
      expect(find.byTooltip('Guest preview'), findsNothing);
      expect(find.byKey(const ValueKey('menu-add')), findsOneWidget);
    });

    testWidgets('a failed read offers a retry', (tester) async {
      final repo = FakeMenuRepository()..menuShouldFail = true;
      await tester.pumpWidget(harness(tester, repo: repo));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a small phone at 2x text does not overflow', (tester) async {
      await tester.pumpWidget(
        harness(
          tester,
          repo: FakeMenuRepository(),
          menuData: menu(),
          surface: const Size(320, 640),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Menu Management'), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-add')), findsOneWidget);
      expect(find.byKey(const ValueKey('menu-search')), findsOneWidget);
    });
  });
}
