import '../api/json.dart';

/// A dish on the venue menu (`…/menu/items`).
///
/// Price is server-held and validated there; the app only ever refuses obvious
/// local mistakes before sending.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.sectionId,
    required this.name,
    this.restaurantId = '',
    this.description = '',
    this.price = 0,
    this.position = 0,
    this.isAvailable = true,
    this.dietaryTags = const [],
    this.photoUrl = '',
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: asString(json['id']),
    restaurantId: asString(json['restaurantId']),
    sectionId: asString(json['sectionId']),
    name: asString(json['name']),
    description: asString(json['description']),
    price: asDouble(json['price']),
    position: asInt(json['position']),
    isAvailable: asBool(json['isAvailable'], fallback: true),
    dietaryTags: asStringList(json['dietaryTags']),
    photoUrl: asString(json['photoUrl']),
  );

  final String id;
  final String restaurantId;
  final String sectionId;
  final String name;
  final String description;
  final double price;
  final int position;
  final bool isAvailable;

  /// Dietary and allergen labels shown to guests (halal, vegetarian, nuts…).
  final List<String> dietaryTags;
  final String photoUrl;

  bool get isSoldOut => !isAvailable;

  MenuItem copyWith({bool? isAvailable}) => MenuItem(
    id: id,
    restaurantId: restaurantId,
    sectionId: sectionId,
    name: name,
    description: description,
    price: price,
    position: position,
    isAvailable: isAvailable ?? this.isAvailable,
    dietaryTags: dietaryTags,
    photoUrl: photoUrl,
  );
}

/// A menu section with its ordered items (`…/menu/sections`).
class MenuSection {
  const MenuSection({
    required this.id,
    required this.name,
    this.restaurantId = '',
    this.branchId,
    this.position = 0,
    this.isActive = true,
    this.items = const [],
  });

  factory MenuSection.fromJson(Map<String, dynamic> json) => MenuSection(
    id: asString(json['id']),
    restaurantId: asString(json['restaurantId']),
    branchId: asStringOrNull(json['branchId']),
    name: asString(json['name']),
    position: asInt(json['position']),
    isActive: asBool(json['isActive'], fallback: true),
    items: asMapList(json['items']).map(MenuItem.fromJson).toList(),
  );

  final String id;
  final String restaurantId;
  final String? branchId;
  final String name;
  final int position;
  final bool isActive;
  final List<MenuItem> items;

  int get availableCount => items.where((i) => i.isAvailable).length;

  List<MenuItem> get sortedItems =>
      [...items]..sort((a, b) => a.position.compareTo(b.position));

  /// `items` lets a screen show a narrowed subset (search, an availability
  /// filter) under the same category header, position and name. The server has
  /// no such concept, so this copy exists only in memory and is never sent.
  MenuSection copyWith({
    String? name,
    bool? isActive,
    int? position,
    List<MenuItem>? items,
  }) => MenuSection(
    id: id,
    restaurantId: restaurantId,
    branchId: branchId,
    name: name ?? this.name,
    position: position ?? this.position,
    isActive: isActive ?? this.isActive,
    items: items ?? this.items,
  );
}

/// A priced dining package (`special_menus`, created through `/partner/menus`).
///
/// The API supports create and list only, so an existing package is edited by
/// the platform, not here, the screen says so instead of offering a dead button.
class DiningPackage {
  const DiningPackage({
    required this.id,
    required this.name,
    this.restaurantId = '',
    this.restaurantName = '',
    this.description = '',
    this.status = 'active',
    this.pricePerGuest = 0,
    this.minGuests = 2,
    this.tags = const [],
    this.viewsThisWeek = 0,
    this.bookingsCount = 0,
  });

  factory DiningPackage.fromJson(Map<String, dynamic> json) => DiningPackage(
    id: asString(json['id']),
    restaurantId: asString(json['restaurantId']),
    restaurantName: asString(json['restaurantName']),
    name: asString(json['name']),
    description: asString(json['description']),
    status: asString(json['status'], fallback: 'active'),
    pricePerGuest: asDouble(json['pricePerGuest']),
    minGuests: asInt(json['minGuests'], fallback: 2),
    tags: asStringList(json['tags']),
    viewsThisWeek: asInt(json['viewsThisWeek']),
    bookingsCount: asInt(json['bookingsCount']),
  );

  final String id;
  final String restaurantId;
  final String restaurantName;
  final String name;
  final String description;
  final String status;
  final double pricePerGuest;
  final int minGuests;
  final List<String> tags;
  final int viewsThisWeek;
  final int bookingsCount;

  bool get isActive => status == 'active';
}

/// A physical table (`…/tables`). Capacity for the venue is the sum of the
/// active tables' seats, which is what the availability engine uses.
class DiningTable {
  const DiningTable({
    required this.id,
    required this.label,
    required this.seats,
    this.restaurantId = '',
    this.branchId,
    this.zone = '',
    this.isActive = true,
    this.createdAt,
  });

  factory DiningTable.fromJson(Map<String, dynamic> json) => DiningTable(
    id: asString(json['id']),
    restaurantId: asString(json['restaurantId']),
    branchId: asStringOrNull(json['branchId']),
    label: asString(json['label']),
    seats: asInt(json['seats']),
    zone: asString(json['zone']),
    isActive: asBool(json['isActive'], fallback: true),
    createdAt: asDate(json['createdAt']),
  );

  final String id;
  final String restaurantId;
  final String? branchId;
  final String label;
  final int seats;
  final String zone;
  final bool isActive;
  final DateTime? createdAt;

  String get seatLabel => '$seats seats';
  String get zoneLabel => zone.isEmpty ? 'Unzoned' : zone;
}

/// The public (unauthenticated) menu payload, what guests see after scanning
/// the QR code. Mirrors `GET /api/public/menu/:id`.
class PublicMenu {
  const PublicMenu({
    required this.restaurant,
    required this.sections,
  });

  factory PublicMenu.fromJson(Map<String, dynamic> json) => PublicMenu(
    restaurant: PublicMenuRestaurant.fromJson(
      (json['restaurant'] as Map<String, dynamic>?) ?? const {},
    ),
    sections: (json['sections'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MenuSection.fromJson)
        .toList(),
  );

  final PublicMenuRestaurant restaurant;
  final List<MenuSection> sections;
}

/// The restaurant metadata the public menu endpoint returns alongside sections.
class PublicMenuRestaurant {
  const PublicMenuRestaurant({
    this.id = '',
    this.name = '',
    this.city = '',
    this.neighborhood = '',
    this.address = '',
    this.coverImage = '',
  });

  factory PublicMenuRestaurant.fromJson(Map<String, dynamic> json) =>
      PublicMenuRestaurant(
        id: asString(json['id']),
        name: asString(json['name']),
        city: asString(json['city']),
        neighborhood: asString(json['neighborhood']),
        address: asString(json['address']),
        coverImage: asString(json['coverImage']),
      );

  final String id;
  final String name;
  final String city;
  final String neighborhood;
  final String address;
  final String coverImage;
}

/// One bookable 90-minute slot for a service day (`…/availability`).
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.startAt,
    required this.endAt,
    required this.available,
    required this.seatsLeft,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) => AvailabilitySlot(
    startAt: asDateOr(json['startAt'], DateTime.now()),
    endAt: asDateOr(json['endAt'], DateTime.now()),
    available: asBool(json['available']),
    seatsLeft: asInt(json['seatsLeft']),
  );

  final DateTime startAt;
  final DateTime endAt;

  /// False when the venue stopped accepting bookings, the party no longer fits
  /// a table, the room is full, or the slot has already passed.
  final bool available;
  final int seatsLeft;

  bool get isFull => seatsLeft <= 0;
}

/// The availability response for one day, including whether hours are
/// configured, an empty day with no hours is a setup problem, not a busy one.
class DayAvailability {
  const DayAvailability({
    required this.date,
    required this.timeZone,
    required this.slots,
    required this.capacity,
    required this.configuredHours,
  });

  factory DayAvailability.fromJson(Map<String, dynamic> json) =>
      DayAvailability(
        date: asString(json['date']),
        timeZone: asString(json['timeZone'], fallback: 'UTC'),
        slots: asMapList(json['slots'])
            .map(AvailabilitySlot.fromJson)
            .toList(growable: false),
        capacity: asInt(json['capacity']),
        configuredHours: asBool(json['configuredHours']),
      );

  final String date;
  final String timeZone;
  final List<AvailabilitySlot> slots;
  final int capacity;
  final bool configuredHours;

  bool get isClosed => !configuredHours || slots.isEmpty;
  int get bookableCount => slots.where((s) => s.available).length;
}
