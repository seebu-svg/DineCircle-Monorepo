import '../api/json.dart';
import 'account.dart';

/// A venue the caller operates, exactly as `serializeVenue` answers it.
///
/// [verified] is the single predicate behind every selling gate on the server
/// (`is_partner && partnership_status == 'verified'`); screens use it instead of
/// re-deriving the pair, which is what the API contract asks of clients.
class Venue {
  const Venue({
    required this.id,
    required this.name,
    this.tagline = '',
    this.about = '',
    this.cuisines = const [],
    this.neighborhood = '',
    this.address = '',
    this.city = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.instagram = '',
    this.priceRange = r'$$',
    this.rating = 0,
    this.reviewCount = 0,
    this.seats = 0,
    this.tablesCount = 0,
    this.since = '',
    this.ownerName = '',
    this.amenities = const [],
    this.openingHours = const OpeningHours({}),
    this.profileCompletion = 0,
    this.acceptingBookings = false,
    this.coverImage = '',
    this.logo = '',
    this.gallery = const [],
    this.tags = const [],
    this.isPartner = false,
    this.partnershipStatus = 'unverified',
    this.verified = false,
    this.verifiedAt,
    this.rejectionNote = '',
    this.partnerPerk,
    this.requiresHostApproval = false,
    this.latitude,
    this.longitude,
    this.myRole = PartnerRole.staff,
  });

  factory Venue.fromJson(Map<String, dynamic> json) => Venue(
    id: asString(json['id']),
    name: asString(json['name']),
    tagline: asString(json['tagline']),
    about: asString(json['about']),
    cuisines: asStringList(json['cuisines']),
    neighborhood: asString(json['neighborhood']),
    address: asString(json['address']),
    city: asString(json['city']),
    phone: asString(json['phone']),
    email: asString(json['email']),
    website: asString(json['website']),
    instagram: asString(json['instagram']),
    priceRange: asString(json['priceRange'], fallback: r'$$'),
    rating: asDouble(json['rating']),
    reviewCount: asInt(json['reviewCount']),
    seats: asInt(json['seats']),
    tablesCount: asInt(json['tablesCount']),
    since: asString(json['since']),
    ownerName: asString(json['ownerName']),
    amenities: asStringList(json['amenities']),
    openingHours: OpeningHours.fromJson(json['openingHours']),
    profileCompletion: asInt(json['profileCompletion']),
    acceptingBookings: asBool(json['acceptingBookings']),
    coverImage: asString(json['coverImage']),
    logo: asString(json['logo']),
    gallery: asStringList(json['gallery']),
    tags: asStringList(json['tags']),
    isPartner: asBool(json['isPartner']),
    partnershipStatus: asString(json['partnershipStatus'], fallback: 'unverified'),
    verified: asBool(json['verified']),
    verifiedAt: asDate(json['verifiedAt']),
    rejectionNote: asString(json['rejectionNote']),
    partnerPerk: asStringOrNull(json['partnerPerk']),
    requiresHostApproval: asBool(json['requiresHostApproval']),
    latitude: asDoubleOrNull(json['latitude']),
    longitude: asDoubleOrNull(json['longitude']),
    myRole: PartnerRole.parse(asStringOrNull(json['myRole'])),
  );

  final String id;
  final String name;
  final String tagline;
  final String about;
  final List<String> cuisines;
  final String neighborhood;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String website;
  final String instagram;
  final String priceRange;
  final double rating;
  final int reviewCount;
  final int seats;
  final int tablesCount;
  final String since;
  final String ownerName;
  final List<String> amenities;
  final OpeningHours openingHours;
  final int profileCompletion;
  final bool acceptingBookings;
  final String coverImage;

  /// Square brand mark, separate from [coverImage]. Empty until the partner
  /// uploads one, in which case callers fall back to the cover.
  final String logo;

  final List<String> gallery;
  final List<String> tags;
  final bool isPartner;
  final String partnershipStatus;
  final bool verified;
  final DateTime? verifiedAt;
  final String rejectionNote;
  final String? partnerPerk;
  final bool requiresHostApproval;
  final double? latitude;
  final double? longitude;
  final PartnerRole myRole;

  bool get isPendingReview => partnershipStatus == 'pending_review';
  bool get isRejected => partnershipStatus == 'rejected';

  /// Every non-`verified` state is a non-selling state, and the app must say so
  /// instead of showing a dashboard full of zeros.
  bool get canSell => verified;

  String get statusLabel {
    switch (partnershipStatus) {
      case 'verified':
        return 'Verified';
      case 'pending_review':
        return 'Pending review';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unverified';
    }
  }

  /// Short human description of what a caller may do here.
  String get roleSummary => switch (myRole) {
    PartnerRole.staff => 'Day-list, check-in and read-only venue data',
    PartnerRole.manager => 'Operations, menu, tables, deals and earnings',
    PartnerRole.owner => 'Full control including the team',
  };
}

/// `counts` beside a single venue read (`GET …/restaurants/:id`).
class VenueCounts {
  const VenueCounts({
    this.branches = 0,
    this.tables = 0,
    this.menuItems = 0,
    this.upcomingEvents = 0,
    this.pendingReservations = 0,
  });

  factory VenueCounts.fromJson(Map<String, dynamic>? json) => VenueCounts(
    branches: asInt(json?['branches']),
    tables: asInt(json?['tables']),
    menuItems: asInt(json?['menu_items'] ?? json?['menuItems']),
    upcomingEvents: asInt(json?['upcoming_events'] ?? json?['upcomingEvents']),
    pendingReservations:
        asInt(json?['pending_reservations'] ?? json?['pendingReservations']),
  );

  final int branches;
  final int tables;
  final int menuItems;
  final int upcomingEvents;
  final int pendingReservations;
}

/// One branch of a venue. Availability and reservations are interpreted in
/// [timeZone], never in the device zone.
class Branch {
  const Branch({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.address = '',
    this.area = '',
    this.city = '',
    this.phone = '',
    this.latitude,
    this.longitude,
    this.isPrimary = false,
    this.acceptingReservations = true,
    this.timeZone = 'UTC',
    this.openingHours = const OpeningHours({}),
    this.createdAt,
  });

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    id: asString(json['id']),
    restaurantId: asString(json['restaurantId']),
    name: asString(json['name']),
    address: asString(json['address']),
    area: asString(json['area']),
    city: asString(json['city']),
    phone: asString(json['phone']),
    latitude: asDoubleOrNull(json['latitude']),
    longitude: asDoubleOrNull(json['longitude']),
    isPrimary: asBool(json['isPrimary']),
    acceptingReservations: asBool(json['acceptingReservations'], fallback: true),
    timeZone: asString(json['timeZone'], fallback: 'UTC'),
    openingHours: OpeningHours.fromJson(json['openingHours']),
    createdAt: asDate(json['createdAt']),
  );

  final String id;
  final String restaurantId;
  final String name;
  final String address;
  final String area;
  final String city;
  final String phone;
  final double? latitude;
  final double? longitude;
  final bool isPrimary;
  final bool acceptingReservations;
  final String timeZone;
  final OpeningHours openingHours;
  final DateTime? createdAt;

  bool get hasConfiguredHours => openingHours.isNotEmpty;

  String get locationLabel {
    final parts = [area, city].where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? 'No location set' : parts.join(', ');
  }
}

/// A single opening window, `HH:MM` on a 24-hour clock.
class HoursWindow {
  const HoursWindow({required this.open, required this.close});

  factory HoursWindow.fromJson(Map<String, dynamic> json) => HoursWindow(
    open: asString(json['open']),
    close: asString(json['close']),
  );

  final String open;
  final String close;

  Map<String, dynamic> toJson() => {'open': open, 'close': close};

  @override
  String toString() => '$open–$close';
}

/// One weekday's configuration. A day absent from the map means "not
/// configured", which is different from `closed: true`.
class DayHours {
  const DayHours({this.closed = false, this.windows = const []});

  factory DayHours.fromJson(Map<String, dynamic> json) => DayHours(
    closed: asBool(json['closed']),
    windows: asMapList(json['windows']).map(HoursWindow.fromJson).toList(),
  );

  final bool closed;
  final List<HoursWindow> windows;

  bool get isConfigured => closed || windows.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'closed': closed,
    'windows': windows.map((w) => w.toJson()).toList(),
  };

  DayHours copyWith({bool? closed, List<HoursWindow>? windows}) => DayHours(
    closed: closed ?? this.closed,
    windows: windows ?? this.windows,
  );
}

/// The weekly `opening_hours` map, keyed by the server's three-letter days.
class OpeningHours {
  const OpeningHours(this.days);

  /// Server order: `mon … sun`. A missing key means "not configured".
  static const List<String> weekdayKeys = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  static const List<String> weekdayLabels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static OpeningHours fromJson(Object? value) {
    final map = asMap(value);
    return OpeningHours({
      for (final key in weekdayKeys)
        if (map[key] != null) key: DayHours.fromJson(asMap(map[key])),
    });
  }

  static OpeningHours empty() => const OpeningHours({});

  final Map<String, DayHours> days;

  bool get isNotEmpty => days.isNotEmpty;
  bool get isEmpty => days.isEmpty;

  DayHours day(String key) => days[key] ?? const DayHours();

  Map<String, dynamic> toJson() => {
    for (final entry in days.entries) entry.key: entry.value.toJson(),
  };

  OpeningHours withDay(String key, DayHours hours) => OpeningHours({
    ...days,
    key: hours,
  });

  /// Convenience for the availability summary line: total trading hours in the
  /// week, ignoring overlaps across different days.
  int get weeklyOpenMinutes {
    var total = 0;
    for (final hours in days.values) {
      if (hours.closed) continue;
      for (final window in hours.windows) {
        total += _minutes(window.close) - _minutes(window.open);
      }
    }
    return total;
  }

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }
}

/// Everything the self-service registration wizard collects.
///
/// Field-for-field the same contract as `registerVenueSchema`, including its
/// limits, so a wizard that validates locally cannot be rejected for shape.
class RegisterVenueInput {
  const RegisterVenueInput({
    required this.name,
    required this.city,
    this.tagline = '',
    this.about = '',
    this.cuisines = const [],
    this.timezone = 'UTC',
    this.area = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.instagram = '',
    this.priceRange = '\$\$',
    this.seats = 0,
    this.tablesCount = 0,
    this.amenities = const [],
    this.coverImage = '',
  });

  final String name;
  final String city;
  final String tagline;
  final String about;
  final List<String> cuisines;
  final String timezone;
  final String area;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String instagram;
  final String priceRange;
  final int seats;
  final int tablesCount;
  final List<String> amenities;
  final String coverImage;

  static const List<String> priceRanges = [r'$', r'$$', r'$$$', r'$$$$'];

  RegisterVenueInput copyWith({
    String? name,
    String? city,
    String? tagline,
    String? about,
    List<String>? cuisines,
    String? timezone,
    String? area,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? instagram,
    String? priceRange,
    int? seats,
    int? tablesCount,
    List<String>? amenities,
    String? coverImage,
  }) => RegisterVenueInput(
    name: name ?? this.name,
    city: city ?? this.city,
    tagline: tagline ?? this.tagline,
    about: about ?? this.about,
    cuisines: cuisines ?? this.cuisines,
    timezone: timezone ?? this.timezone,
    area: area ?? this.area,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    website: website ?? this.website,
    instagram: instagram ?? this.instagram,
    priceRange: priceRange ?? this.priceRange,
    seats: seats ?? this.seats,
    tablesCount: tablesCount ?? this.tablesCount,
    amenities: amenities ?? this.amenities,
    coverImage: coverImage ?? this.coverImage,
  );

  Map<String, dynamic> toBody() => {
    'name': name.trim(),
    'tagline': tagline.trim(),
    'about': about.trim(),
    'cuisines': cuisines,
    'city': city.trim(),
    'timezone': timezone.trim(),
    'area': area.trim(),
    'address': address.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'website': website.trim(),
    'instagram': instagram.trim(),
    'priceRange': priceRange,
    'seats': seats,
    'tablesCount': tablesCount,
    'amenities': amenities,
    'coverImage': coverImage.trim(),
  };
}

/// A partial venue profile write (`PATCH …/restaurants/:id`).
///
/// Only keys the operator actually touched are sent: `patchVenueSchema` is
/// entirely optional, and sending an untouched `email: ''` would blank a real
/// address, so absent means "leave as is" here.
class VenueProfileEdit {
  const VenueProfileEdit({
    this.name,
    this.tagline,
    this.about,
    this.cuisines,
    this.neighborhood,
    this.address,
    this.city,
    this.phone,
    this.email,
    this.website,
    this.instagram,
    this.priceRange,
    this.seats,
    this.tablesCount,
    this.amenities,
    this.coverImage,
    this.logo,
    this.gallery,
    this.tags,
    this.partnerPerk,
    this.acceptingBookings,
    this.requiresHostApproval,
  });

  final String? name;
  final String? tagline;
  final String? about;
  final List<String>? cuisines;
  final String? neighborhood;
  final String? address;
  final String? city;
  final String? phone;
  final String? email;
  final String? website;
  final String? instagram;
  final String? priceRange;
  final int? seats;
  final int? tablesCount;
  final List<String>? amenities;
  final String? coverImage;
  final String? logo;
  final List<String>? gallery;
  final List<String>? tags;
  final String? partnerPerk;
  final bool? acceptingBookings;
  final bool? requiresHostApproval;

  bool get isEmpty => toBody().isEmpty;

  Map<String, dynamic> toBody() {
    final body = <String, dynamic>{};
    void put(String key, Object? value) {
      if (value != null) body[key] = value;
    }

    put('name', name?.trim());
    put('tagline', tagline?.trim());
    put('about', about?.trim());
    put('cuisines', cuisines);
    put('neighborhood', neighborhood?.trim());
    put('address', address?.trim());
    put('city', city?.trim());
    put('phone', phone?.trim());
    put('email', email?.trim());
    put('website', website?.trim());
    put('instagram', instagram?.trim());
    put('priceRange', priceRange);
    put('seats', seats);
    put('tablesCount', tablesCount);
    put('amenities', amenities);
    put('coverImage', coverImage?.trim());
    put('logo', logo?.trim());
    put('gallery', gallery);
    put('tags', tags);
    put('partnerPerk', partnerPerk?.trim());
    put('acceptingBookings', acceptingBookings);
    put('requiresHostApproval', requiresHostApproval);
    return body;
  }
}

/// Create/update payload for a branch (`branchSchema`).
class BranchInput {
  const BranchInput({
    required this.name,
    this.address = '',
    this.area = '',
    this.city = '',
    this.phone = '',
    this.isPrimary = false,
    this.acceptingReservations = true,
    this.timezone = 'UTC',
  });

  final String name;
  final String address;
  final String area;
  final String city;
  final String phone;
  final bool isPrimary;
  final bool acceptingReservations;
  final String timezone;

  Map<String, dynamic> toBody() => {
    'name': name.trim(),
    'address': address.trim(),
    'area': area.trim(),
    'city': city.trim(),
    'phone': phone.trim(),
    'isPrimary': isPrimary,
    'acceptingReservations': acceptingReservations,
    'timezone': timezone.trim(),
  };
}

