import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/catalog.dart';

/// Menu sections/items, the 86-list and priced packages.
///
/// Packages come from the account-wide `/partner/menus` surface (special menus),
/// which supports create and list only, there is no edit or delete route, so
/// the screen offers neither.
class MenuRepository {
  MenuRepository(this._api);

  final ApiClient _api;

  static String base(String venueId) => '/partner/restaurants/$venueId';

  Future<List<MenuSection>> menu(String venueId) async {
    final envelope = await _api.envelopeGet('${base(venueId)}/menu');
    return envelope.list('sections', MenuSection.fromJson);
  }

  Future<MenuSection> createSection(
    String venueId, {
    required String name,
    int position = 0,
    bool isActive = true,
    String? branchId,
  }) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/menu/sections',
      body: {
        'name': name.trim(),
        'position': position,
        'isActive': isActive,
        'branchId': ?branchId,
      },
    );
    final section = envelope.single('section', MenuSection.fromJson);
    if (section == null) throw StateError('Section payload missing');
    return section;
  }

  /// Sends only the keys that changed; the patch schema is fully optional.
  Future<MenuSection> updateSection(
    String venueId,
    String sectionId, {
    String? name,
    int? position,
    bool? isActive,
  }) async {
    final envelope = await _api.envelopePatch(
      '${base(venueId)}/menu/sections/$sectionId',
      body: {
        if (name != null) 'name': name.trim(),
        'position': ?position,
        'isActive': ?isActive,
      },
    );
    final section = envelope.single('section', MenuSection.fromJson);
    if (section == null) throw StateError('Section payload missing');
    return section;
  }

  Future<void> deleteSection(String venueId, String sectionId) =>
      _api.deleteJson('${base(venueId)}/menu/sections/$sectionId');

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
    final envelope = await _api.envelopePost(
      '${base(venueId)}/menu/items',
      body: {
        'sectionId': sectionId,
        'name': name.trim(),
        'description': description.trim(),
        'price': price,
        'position': position,
        'isAvailable': isAvailable,
        'dietaryTags': dietaryTags,
        'photoUrl': photoUrl.trim(),
      },
    );
    final item = envelope.single('item', MenuItem.fromJson);
    if (item == null) throw StateError('Item payload missing');
    return item;
  }

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
    final envelope = await _api.envelopePatch(
      '${base(venueId)}/menu/items/$itemId',
      body: {
        'sectionId': ?sectionId,
        if (name != null) 'name': name.trim(),
        if (description != null) 'description': description.trim(),
        'price': ?price,
        'position': ?position,
        'isAvailable': ?isAvailable,
        'dietaryTags': ?dietaryTags,
        if (photoUrl != null) 'photoUrl': photoUrl.trim(),
      },
    );
    final item = envelope.single('item', MenuItem.fromJson);
    if (item == null) throw StateError('Item payload missing');
    return item;
  }

  Future<void> deleteItem(String venueId, String itemId) =>
      _api.deleteJson('${base(venueId)}/menu/items/$itemId');

  /// The 86-list: one idempotent bulk write for a batch of items.
  ///
  /// Returns the ids the server actually touched, which lets the screen confirm
  /// a toggle rather than assuming it.
  Future<List<String>> setAvailability(
    String venueId,
    List<String> itemIds, {
    required bool isAvailable,
  }) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/menu/availability',
      body: {'itemIds': itemIds, 'isAvailable': isAvailable},
    );
    return (envelope.raw('updated') as List? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
  }

  // ── Public menu (unauthenticated, same payload guests see) ─────────────

  /// Fetches the guest-facing menu from the public route. The response is
  /// top-level JSON (no `data` envelope), with server-side filtering of
  /// inactive sections and unavailable items.
  Future<PublicMenu> publicMenu(String venueId) async {
    final raw = await _api.getJson('/public/menu/$venueId');
    if (raw is! Map<String, dynamic>) {
      throw StateError('Public menu payload is not a JSON object');
    }
    return PublicMenu.fromJson(raw);
  }

  // ── Reorder helpers ───────────────────────────────────────────────────────

  /// Writes the new category order as one PATCH per section that moved.
  ///
  /// The API exposes no bulk reorder route, so an order is N writes and can
  /// fail half way. When it does, the positions already committed are put back
  /// to what they were when this call started and the original error is
  /// rethrown: a menu left in an order that is neither the old one nor the new
  /// one is worse than a drag that simply did not take. Rollback is best
  /// effort, because the caller surfaces the first failure and reloads the
  /// list from the server either way.
  Future<void> reorderSections(
    String venueId,
    List<MenuSection> ordered,
  ) async {
    final committed = <(String id, int position)>[];
    try {
      for (var i = 0; i < ordered.length; i++) {
        final section = ordered[i];
        if (section.position == i) continue;
        await updateSection(venueId, section.id, position: i);
        committed.add((section.id, section.position));
      }
    } catch (error) {
      for (final (id, position) in committed.reversed) {
        try {
          await updateSection(venueId, id, position: position);
        } catch (rollbackError) {
          debugPrint(
            'Section reorder rollback failed for $id: $rollbackError',
          );
        }
      }
      rethrow;
    }
  }

  /// Writes the new dish order as one PATCH per item that moved, rolling back
  /// the ones that already landed if a later write fails. See
  /// [reorderSections] for why the rollback exists and why it is best effort.
  Future<void> reorderItems(
    String venueId,
    List<MenuItem> ordered,
  ) async {
    final committed = <(String id, int position)>[];
    try {
      for (var i = 0; i < ordered.length; i++) {
        final item = ordered[i];
        if (item.position == i) continue;
        await updateItem(venueId, item.id, position: i);
        committed.add((item.id, item.position));
      }
    } catch (error) {
      for (final (id, position) in committed.reversed) {
        try {
          await updateItem(venueId, id, position: position);
        } catch (rollbackError) {
          debugPrint('Item reorder rollback failed for $id: $rollbackError');
        }
      }
      rethrow;
    }
  }

  // ── Packages (special menus) ───────────────────────────────────────────────

  /// Account-wide: menus across every venue the caller operates, not just the
  /// selected one, so the screen labels the list accordingly.
  Future<List<DiningPackage>> packages() async {
    final envelope = await _api.envelopeGet('/partner/menus');
    return envelope.list('menus', DiningPackage.fromJson);
  }

  Future<DiningPackage> createPackage({
    required String restaurantId,
    required String name,
    required double pricePerGuest,
    String description = '',
    int minGuests = 2,
    List<String> tags = const [],
  }) async {
    final envelope = await _api.envelopePost(
      '/partner/menus',
      body: {
        'restaurantId': restaurantId,
        'name': name.trim(),
        'description': description.trim(),
        'pricePerGuest': pricePerGuest,
        'minGuests': minGuests,
        'tags': tags,
      },
    );
    final menu = envelope.single('menu', DiningPackage.fromJson);
    if (menu == null) throw StateError('Menu payload missing');
    return menu;
  }
}
