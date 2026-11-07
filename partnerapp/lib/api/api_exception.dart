/// A single field-level validation failure, mirroring the server's Zod issues.
class ApiFieldIssue {
  const ApiFieldIssue({required this.path, required this.message});

  /// Dot path as reported by Zod, e.g. `gallery[3]`.
  final String path;
  final String message;

  factory ApiFieldIssue.fromJson(Map<String, dynamic> json) => ApiFieldIssue(
    path: (json['path'] as List?)?.join('.') ?? json['path']?.toString() ?? '',
    message: json['message']?.toString() ?? 'Invalid value',
  );

  @override
  String toString() => path.isEmpty ? message : '$path: $message';
}

/// The one error type every layer of the app catches.
///
/// [statusCode] carries the HTTP status where one exists, and the synthetic
/// codes the transport failures map to (`0` = no connection, `408` = timeout).
/// The status is *meaningful* on the partner surface: `403` means the role is
/// too low or the venue belongs to someone else, `404` means the venue id is
/// unknown, `409` means the state moved under the operator, `422` means a
/// referenced row does not belong to this venue, so screens branch on it
/// instead of printing a generic toast.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.issues = const [],
  });

  final String message;
  final int? statusCode;
  final String? code;
  final List<ApiFieldIssue> issues;

  factory ApiException.fromStatus(int? statusCode, Object? body) {
    if (body is Map<String, dynamic>) {
      return ApiException(
        message: body['error']?.toString() ??
            body['message']?.toString() ??
            'Request failed',
        statusCode: statusCode,
        code: body['code']?.toString(),
        issues: (body['issues'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ApiFieldIssue.fromJson)
            .toList(),
      );
    }
    final text = body?.toString() ?? '';
    return ApiException(
      message: text.isNotEmpty ? text : 'Request failed',
      statusCode: statusCode,
    );
  }

  factory ApiException.network([String? message]) => ApiException(
    message: message ?? 'Cannot reach the DineCircle API. Check your connection.',
    statusCode: 0,
    code: 'network',
  );

  factory ApiException.timeout() => ApiException(
    message: 'The server took too long to respond. Please try again.',
    statusCode: 408,
    code: 'timeout',
  );

  factory ApiException.cancelled() => ApiException(
    message: 'Request cancelled.',
    code: 'cancelled',
  );

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidation => statusCode == 400 || statusCode == 422;

  /// Field errors keyed by path, ready for `InputDecorator(errorText: …)`.
  Map<String, String> get issuesByPath => {
    for (final issue in issues)
      if (issue.path.isNotEmpty) issue.path: issue.message,
  };

  @override
  String toString() =>
      'ApiException($statusCode): $message${issues.isEmpty ? '' : ' ${issues.join('; ')}'}';
}
