import '../api/api_client.dart';
import '../api/json.dart';
import '../models/account.dart';

/// The result of a successful credential sign-in.
class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.expiresAt,
  });

  final String token;
  final PartnerUser user;
  final DateTime? expiresAt;
}

/// Sign-in, session restore and credential changes (`/auth/*`, `/users/me`).
///
/// The partner app shares the customer backend's auth surface: a desk account is
/// an ordinary user row with a partner platform role, so there is no separate
/// partner login. `/auth/signin` is the OTP path and is deliberately not used
/// here, the desk signs in with a password.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final body = await _api.postMap(
      '/auth/login',
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );
    final token = asString(body['token']);
    if (token.isEmpty) {
      // A 200 without a token is a contract break, not a user error.
      throw StateError('Sign-in returned no token');
    }
    return AuthSession(
      token: token,
      user: PartnerUser.fromJson(asMap(body['user'])),
      expiresAt: asDate(body['expiresAt']),
    );
  }

  Future<PartnerUser> me() async {
    final envelope = await _api.envelopeGet('/auth/me');
    return PartnerUser.fromJson(
      envelope.resourceMap('user') ?? envelope.data,
    );
  }

  Future<PartnerUser> profile() async {
    final envelope = await _api.envelopeGet('/users/me');
    return PartnerUser.fromJson(
      envelope.resourceMap('user') ?? envelope.data,
    );
  }

  /// Writes only the keys in [body]; the server's allowlist decides what lands.
  Future<PartnerUser> updateProfile(Map<String, dynamic> body) async {
    final envelope = await _api.envelopePatch('/users/me', body: body);
    return PartnerUser.fromJson(
      envelope.resourceMap('user') ?? envelope.data,
    );
  }

  Future<void> signOut() => _api.postJson('/auth/signout');

  /// Revokes every other session and keeps this device signed in.
  Future<PartnerUser> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final body = await _api.postMap(
      '/auth/change-password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    return PartnerUser.fromJson(asMap(body['user']));
  }

  /// Starts an email change. The server mints a challenge code; in development
  /// it echoes `devCode`, which the security screen surfaces so the flow is
  /// testable without a mailbox.
  Future<EmailChallenge> requestEmailChange({
    required String email,
    required String password,
  }) async {
    final body = await _api.postMap(
      '/auth/change-email',
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );
    return EmailChallenge(
      email: asString(body['email'], fallback: email),
      expiresAt: asDate(body['expiresAt']),
      devCode: asStringOrNull(body['devCode']),
    );
  }

  Future<PartnerUser> confirmEmailChange({
    required String email,
    required String code,
  }) async {
    final body = await _api.postMap(
      '/auth/change-email/confirm',
      body: {'email': email.trim().toLowerCase(), 'code': code.trim()},
    );
    return PartnerUser.fromJson(asMap(body['user']));
  }

  /// Revokes all sessions including this one, the caller must drop the local
  /// token whatever the server answers, since the credential it uses is gone.
  Future<void> logOutEveryDevice() => _api.postJson('/auth/logout-all');
}

class EmailChallenge {
  const EmailChallenge({
    required this.email,
    this.expiresAt,
    this.devCode,
  });

  final String email;
  final DateTime? expiresAt;

  /// Present only when the server runs in development mode.
  final String? devCode;
}
