import 'json.dart';

/// Pagination + counters from the partner list envelope.
///
/// New partner endpoints return `{ data, meta }` with `page/limit/total/
/// hasMore`; the five legacy operations routes (`/partner/events`,
/// `/partner/bookings`, `/partner/menus`, `/partner/notifications`,
/// `/partner/analytics`) are `limit`-only and report just `total` (notifications
/// also carries `unread` for the badge). Both shapes parse here so callers get
/// one object with safe defaults.
class ApiMeta {
  const ApiMeta({
    this.page = 1,
    this.limit = 50,
    this.total = 0,
    this.hasMore = false,
    this.unread = 0,
    this.hasMeta = false,
  });

  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  /// Unread notification count, present only on `GET /partner/notifications`.
  final int unread;

  /// False when the response carried no `meta` object at all (single resources
  /// and the unpaginated legacy analytics payload), which a paged list uses to
  /// avoid offering an infinite "load more".
  final bool hasMeta;

  factory ApiMeta.fromJson(Object? value) {
    final json = asMap(value);
    if (json.isEmpty) return const ApiMeta();
    return ApiMeta(
      page: asInt(json['page'], fallback: 1),
      limit: asInt(json['limit'], fallback: 50),
      total: asInt(json['total']),
      hasMore: asBool(json['hasMore']),
      unread: asInt(json['unread']),
      hasMeta: true,
    );
  }
}

/// The partner response contract, unwrapped exactly once.
///
/// `{ data: { resource: ... } }` for a single, `{ data: { resource: [...],
/// meta: ... }` for a list. `data` is always an object, so a new sibling key
/// (the dashboard returns five of them) never breaks a reader.
class ApiEnvelope {
  const ApiEnvelope({required this.data, required this.meta});

  final Map<String, dynamic> data;
  final ApiMeta meta;

  factory ApiEnvelope.parse(Object? body) {
    final map = asMap(body);
    // A body without `data` is either a bare resource object or an unexpected
    // shape; passing the map through keeps readers forgiving.
    final payload = map.containsKey('data') ? asMap(map['data']) : map;
    return ApiEnvelope(
      data: payload,
      meta: ApiMeta.fromJson(map['meta']),
    );
  }

  /// Raw value under [key] inside `data`, for scalars and nested maps.
  Object? raw(String key) => data[key];

  Map<String, dynamic>? resourceMap(String key) {
    final value = data[key];
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  List<Map<String, dynamic>> resources(String key) => asMapList(data[key]);

  /// Maps the single resource under [key], or null when the server omitted it.
  T? single<T>(String key, T Function(Map<String, dynamic>) map) {
    final value = resourceMap(key);
    return value == null ? null : map(value);
  }

  /// Maps the collection under [key]; an absent key yields an empty list, which
  /// renders as the screen's empty state rather than an error.
  List<T> list<T>(String key, T Function(Map<String, dynamic>) map) =>
      resources(key).map(map).toList(growable: false);

  /// For payloads whose `data` object *is* the resource (dashboard, earnings).
  T whole<T>(T Function(Map<String, dynamic>) map) => map(data);
}

/// One page of a list: the items plus the meta needed to drive "load more".
class ApiPage<T> {
  const ApiPage({
    required this.items,
    required this.meta,
  });

  final List<T> items;
  final ApiMeta meta;

  bool get hasMore => meta.hasMeta && meta.hasMore;
  int get total => meta.total;

  ApiPage<T> append(List<T> more) =>
      ApiPage(items: [...items, ...more], meta: meta);
}
