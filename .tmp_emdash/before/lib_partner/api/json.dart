/// Typed extraction helpers for the loosely-typed JSON the API returns.
///
/// The partner surface is consistent, but a few legacy routes still answer
/// numbers as strings (`SUM(x)::text`) and dates as either ISO strings or epoch
/// milliseconds. Every model reads through these helpers instead of `as`
/// casts, so one odd field never takes a whole screen down.
library;

String asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String? asStringOrNull(Object? value) {
  if (value == null) return null;
  final text = value is String ? value : value.toString();
  return text.isEmpty ? null : text;
}

int asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.isFinite ? value.round() : fallback;
  if (value is String) {
    final i = int.tryParse(value);
    if (i != null) return i;
    final d = double.tryParse(value);
    if (d != null && d.isFinite) return d.round();
    return fallback;
  }
  return fallback;
}

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.isFinite ? value.round() : null;
  if (value is String) {
    final i = int.tryParse(value);
    if (i != null) return i;
    final d = double.tryParse(value);
    if (d != null && d.isFinite) return d.round();
    return null;
  }
  return null;
}

double asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return fallback;
}

List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  return value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}

Map<String, dynamic> asMap(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

/// ISO-8601 (UTC) or epoch milliseconds → local [DateTime]; `null` when absent.
DateTime? asDate(Object? value) {
  if (value == null) return null;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is double) {
    return DateTime.fromMillisecondsSinceEpoch(value.round());
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed?.toLocal();
  }
  return null;
}

DateTime asDateOr(Object? value, DateTime fallback) => asDate(value) ?? fallback;
