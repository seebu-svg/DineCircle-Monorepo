/// Form validators that mirror the server's Zod schemas.
///
/// Keeping the numbers in one file means a rejected write is a rare fallback
/// rather than the normal path, and a schema change lands in one place. Every
/// limit below is copied from `server/src/routes/*.ts`.
class Validators {
  Validators._();

  static final _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static const int venueNameMax = 120;
  static const int taglineMax = 160;
  static const int aboutMax = 4000;
  static const int amenitiesMax = 20;
  static const int cuisinesMax = 12;
  static const int galleryMax = 20;
  static const int seatsMax = 5000;
  static const int tablesMax = 500;
  static const int eventSeatsMax = 200;
  static const int pricePerSeatMax = 10000;
  static const int declineReasonMax = 500;
  static const int dietaryTagsMax = 10;
  static const int hoursWindowsMax = 4;

  static String? text(
    String? value, {
    String field = 'This field',
    int min = 0,
    int max = 500,
    bool required = true,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return required ? '$field is required' : null;
    }
    if (trimmed.length < min) return '$field needs at least $min characters';
    if (trimmed.length > max) return '$field is too long (max $max)';
    return null;
  }

  static String? email(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? 'Email is required' : null;
    if (!_email.hasMatch(trimmed)) return 'Enter a valid email address';
    if (trimmed.length > 160) return 'Email is too long';
    return null;
  }

  static String? phone(String? value, {bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? 'Phone is required' : null;
    if (trimmed.length > 40) return 'Phone is too long';
    if (!RegExp(r'^[0-9+()\-\s.]+$').hasMatch(trimmed)) {
      return 'Phone may only contain digits, spaces and + ( ) -';
    }
    return null;
  }

  /// Image fields are URLs, the platform has no partner media upload yet.
  static String? url(String? value, {String field = 'Link', bool required = false}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? '$field is required' : null;
    if (trimmed.length > 400) return '$field is too long';
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return '$field must start with http:// or https://';
    }
    return null;
  }

  static String? integer(
    String? value, {
    String field = 'Value',
    int min = 0,
    int max = 999999,
    bool required = true,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? '$field is required' : null;
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return '$field must be a whole number';
    if (parsed < min) return '$field cannot be below $min';
    if (parsed > max) return '$field cannot be above $max';
    return null;
  }

  static String? money(
    String? value, {
    String field = 'Price',
    double min = 0.01,
    double max = 100000,
    bool required = true,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return required ? '$field is required' : null;
    final parsed = double.tryParse(trimmed.replaceAll(',', ''));
    if (parsed == null) return '$field must be a number';
    if (parsed < min) {
      return '$field must be greater than ${_whole(min - 0.01)}';
    }
    if (parsed > max) return '$field cannot be above ${_whole(max)}';
    return null;
  }

  /// 100000, not `100000.0`: a price ceiling reads as rupees, and a partner
  /// told their Rs. 150,000 dish price "cannot be above 100000.0" is reading a
  /// float rather than a limit.
  static String _whole(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  /// A percentage, not a money amount.
  ///
  /// Written out rather than delegated to [money]: money reports its ceiling
  /// with its own decimals, so a partner saving 101% was told "cannot be above
  /// 100.0", which reads like a price rather than a discount.
  static String? percent(String? value, {String field = 'Discount'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$field is required';
    final parsed = double.tryParse(trimmed.replaceAll(',', ''));
    if (parsed == null) return '$field must be a number';
    if (parsed < 1) return '$field must be at least 1%';
    if (parsed > 100) return '$field cannot exceed 100%';
    return null;
  }

  static String? time(String? value, {String field = 'Time'}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$field is required';
    if (!_time.hasMatch(trimmed)) return 'Use 24-hour HH:MM (for example 18:30)';
    return null;
  }

  static String? futureDate(DateTime? value, {String field = 'Date'}) {
    if (value == null) return '$field is required';
    final today = DateTime.now();
    if (value.isBefore(DateTime(today.year, today.month, today.day))) {
      return '$field must be today or later';
    }
    return null;
  }

  static String? orderedRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Both dates are required';
    if (!end.isAfter(start)) return 'The end must be after the start';
    return null;
  }

  static String? listLength(
    List<Object?> value, {
    String field = 'Entries',
    int max = 20,
    int min = 0,
  }) {
    if (value.length > max) return 'At most $max $field allowed';
    if (value.length < min) return 'At least $min $field required';
    return null;
  }

  /// A pasted booking reference or UUID, accepted by the manual check-in field.
  static String? bookingReference(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter a reference or booking id';
    if (trimmed.length < 4) return 'That reference looks too short';
    if (trimmed.length > 80) return 'That reference is too long';
    return null;
  }

  static bool looksLikeUuid(String value) => _uuid.hasMatch(value.trim());

  static String? requiredChoice(Object? value, {String field = 'Choice'}) =>
      value == null ? 'Select a $field' : null;
}
