import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'envelope.dart';

/// Timeouts mirror the customer app: a slow paired device on a phone hotspot
/// should still get an answer, but a dead LAN IP must fail fast enough for the
/// desk to notice.
Dio _buildDefaultDio() => Dio(
  BaseOptions(
    baseUrl: AppConfig.apiUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: Duration(milliseconds: AppConfig.apiTimeoutMs),
    sendTimeout: const Duration(seconds: 10),
    headers: const <String, dynamic>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    // Every status is inspected by [_toException]; nothing auto-throws early.
    validateStatus: (status) => status != null && status < 400,
  ),
);

/// Thin, typed wrapper around Dio used by every partner repository.
///
/// Responsibilities:
///  * attach `Authorization: Bearer <token>` to every request;
///  * map transport and HTTP failures into one [ApiException] that keeps the
///    status code (the partner contract gives `403`/`404`/`409`/`422` meaning);
///  * retry an idempotent GET once on a transient network/timeout failure;
///  * notify the session layer when the server rejects the token (`401`).
class ApiClient {
  ApiClient({Dio? dio, this.token}) : dio = dio ?? _buildDefaultDio() {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final currentToken = token;
          if (currentToken != null && currentToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $currentToken';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;

  /// Current bearer token, if signed in. Mutated by the session layer.
  String? token;

  /// Invoked whenever a request fails with `401` so the session can clear
  /// itself, a token revoked on another device must not leave the app looking
  /// signed in.
  void Function()? onUnauthorized;

  // ── Verbs ──────────────────────────────────────────────────────────────────

  /// GET that returns the decoded JSON body. Retried once on a transient
  /// failure because every partner read is idempotent and safe to repeat.
  Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) async {
    try {
      return await _send('GET', path, query: query);
    } on ApiException catch (error) {
      if (!error._isTransient) rethrow;
      return _send('GET', path, query: query);
    }
  }

  Future<dynamic> postJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    void Function(int sent, int total)? onSendProgress,
  }) => _send(
    'POST',
    path,
    body: body,
    query: query,
    onSendProgress: onSendProgress,
  );

  Future<dynamic> putJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send('PUT', path, body: body, query: query);

  Future<dynamic> patchJson(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => _send('PATCH', path, body: body, query: query);

  Future<dynamic> deleteJson(String path, {Object? body}) =>
      _send('DELETE', path, body: body);

  // ── Envelope shortcuts ─────────────────────────────────────────────────────

  Future<ApiEnvelope> envelopeGet(
    String path, {
    Map<String, dynamic>? query,
  }) async => ApiEnvelope.parse(await getJson(path, query: query));

  Future<ApiEnvelope> envelopePost(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    void Function(int sent, int total)? onSendProgress,
  }) async => ApiEnvelope.parse(
    await postJson(
      path,
      body: body,
      query: query,
      onSendProgress: onSendProgress,
    ),
  );

  Future<ApiEnvelope> envelopePatch(String path, {Object? body}) async =>
      ApiEnvelope.parse(await patchJson(path, body: body));

  Future<ApiEnvelope> envelopePut(String path, {Object? body}) async =>
      ApiEnvelope.parse(await putJson(path, body: body));

  /// `POST` that answers a bare object (no `data` wrapper worth modelling),
  /// still unwrapped defensively so callers can read `envelope.data['token']`.
  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? body,
  }) async {
    final raw = await postJson(path, body: body);
    return raw is Map<String, dynamic> ? raw : const {};
  }

  /// Liveness + reachability check without auth, used by the login screen's
  /// "server unreachable" hint.
  Future<bool> health() async {
    try {
      final res = await dio.get<dynamic>('/health');
      return res.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  void close() => dio.close(force: true);

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final response = await dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method),
        // Only an upload passes this; a base64 photo body reports real byte
        // progress, which is the difference between a bar and a spinner.
        onSendProgress: onSendProgress,
      );
      return response.data;
    } on DioException catch (error) {
      throw _toException(error);
    }
  }

  ApiException _toException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.timeout();
      case DioExceptionType.cancel:
        return ApiException.cancelled();
      case DioExceptionType.connectionError:
        return ApiException.network();
      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'The server certificate could not be verified.',
          statusCode: -1,
          code: 'bad_certificate',
        );
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401) onUnauthorized?.call();
        return ApiException.fromStatus(status, error.response?.data);
      case DioExceptionType.unknown:
        final message = error.error?.toString() ?? '';
        return ApiException.network(
          message.isEmpty ? null : 'Network error: $message',
        );
      default:
        // A transform failure (bad body serialisation) is still a request the
        // desk could not make; report it rather than crash on an unmatched enum
        // value added by a future Dio.
        return ApiException(
          message: 'The request could not be completed.',
          code: 'transport',
        );
    }
  }
}

extension on ApiException {
  /// Only transport failures are worth repeating automatically.
  bool get _isTransient =>
      statusCode == 0 || statusCode == 408 || code == 'timeout' || code == 'network';
}
