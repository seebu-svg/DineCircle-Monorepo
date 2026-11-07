import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/account.dart';
import '../repositories/auth_repository.dart';
import '../repositories/business_repository.dart';
import '../repositories/experience_repository.dart';
import '../repositories/image_repository.dart';
import '../repositories/menu_repository.dart';
import '../repositories/operations_repository.dart';
import '../repositories/venue_repository.dart';
import '../services/websocket_service.dart';

/// Token storage key. Deliberately distinct from the customer app's key so the
/// two clients can be installed side by side without signing each other out.
const String kTokenKey = 'dinecircle.partner.token';

const FlutterSecureStorage _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => _storage,
);

/// Web-compatible token storage using SharedPreferences.
/// FlutterSecureStorage doesn't work reliably on web, so we use plain localStorage.
Future<String?> readToken() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kTokenKey);
  }
  return await _storage.read(key: kTokenKey);
}

Future<void> writeToken(String token) async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTokenKey, token);
  } else {
    await _storage.write(key: kTokenKey, value: token);
  }
}

Future<void> deleteToken() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTokenKey);
  } else {
    await _storage.delete(key: kTokenKey);
  }
}

/// The one HTTP client for the whole app.
///
/// A `401` from any repository routes through the session controller rather
/// than surfacing a login error on an unrelated screen: a token revoked on
/// another device must not leave the desk looking signed in.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  client.onUnauthorized = () {
    final session = ref.read(sessionProvider.notifier);
    session.onTokenRejected();
  };
  ref.onDispose(client.close);
  return client;
});

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
final venueRepositoryProvider = Provider(
  (ref) => VenueRepository(ref.watch(apiClientProvider)),
);
final menuRepositoryProvider = Provider(
  (ref) => MenuRepository(ref.watch(apiClientProvider)),
);
final operationsRepositoryProvider = Provider(
  (ref) => OperationsRepository(ref.watch(apiClientProvider)),
);
final experienceRepositoryProvider = Provider(
  (ref) => ExperienceRepository(ref.watch(apiClientProvider)),
);
final businessRepositoryProvider = Provider(
  (ref) => BusinessRepository(ref.watch(apiClientProvider)),
);
final imageRepositoryProvider = Provider(
  (ref) => ImageRepository(ref.watch(apiClientProvider)),
);

/// Where the session is, independent of whether the account may use this app.
enum SessionStatus { unknown, signedOut, signedIn, notPartner }

/// Restored credentials plus the account they belong to.
class SessionState {
  const SessionState({
    required this.status,
    this.user,
    this.token,
  });

  const SessionState.signedOut() : this(status: SessionStatus.signedOut);

  const SessionState.unknown() : this(status: SessionStatus.unknown);

  final SessionStatus status;
  final PartnerUser? user;
  final String? token;

  bool get isSignedIn => status == SessionStatus.signedIn;

  /// The shell only appears once there is a confirmed account.
  bool get isReady => isSignedIn && user != null;

  String get userId => user?.id ?? '';
}

/// Sign-in, restore and sign-out.
///
/// Restores on first read (`GET /auth/me`) so a desk that left the browser tab
/// open comes back to the same account without retyping a password, and treats
/// any restore failure as "not signed in" rather than blocking startup on a
/// transient network blip.
class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final token = await readToken();
    if (token == null || token.isEmpty) {
      return const SessionState.signedOut();
    }
    final client = ref.read(apiClientProvider);
    client.token = token;
    try {
      final user = await ref.read(authRepositoryProvider).me();
      return SessionState(
        status: partnerRoles.contains(user.role)
            ? SessionStatus.signedIn
            // A diner account with a live token is signed in to DineCircle but
            // has no partner surface; the gate screen offers registration.
            : SessionStatus.notPartner,
        user: user,
        token: token,
      );
    } catch (_) {
      await deleteToken();
      client.token = null;
      return const SessionState.signedOut();
    }
  }

  /// Platform roles that reach `/partner/*`. A plain `user` may still register
  /// a venue, which is what the registration entry point is for.
  static const List<String> partnerRoles = [
    'restaurant_owner',
    'restaurant_staff',
    'restaurant_manager',
    'partner_admin',
    'super_admin',
    'host',
  ];

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      await writeToken(session.token);
      ref.read(apiClientProvider).token = session.token;
      return SessionState(
        status: partnerRoles.contains(session.user.role)
            ? SessionStatus.signedIn
            : SessionStatus.notPartner,
        user: session.user,
        token: session.token,
      );
    });
    if (state.hasError) {
      state = AsyncData(const SessionState.signedOut());
    }
  }

  /// Called after a self-service registration, when the same account suddenly
  /// does have a partner role.
  Future<void> reload() async {
    ref.read(apiClientProvider).token = state.valueOrNull?.token;
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).me();
      return SessionState(
        status: partnerRoles.contains(user.role)
            ? SessionStatus.signedIn
            : SessionStatus.notPartner,
        user: user,
        token: state.valueOrNull?.token,
      );
    });
  }

  Future<void> updateUser(PartnerUser user) async {
    final current = state.valueOrNull;
    state = AsyncData(
      SessionState(
        status: current?.status ?? SessionStatus.signedIn,
        user: user,
        token: current?.token,
      ),
    );
  }

  /// Clears local credentials. The server already dropped the token, this is
  /// the half of signing out that happens on the device.
  Future<void> signOut() async {
    ref.read(apiClientProvider).token = null;
    try {
      await deleteToken();
    } catch (_) {
      // A storage failure must not keep a signed-in shell on screen.
    }
    state = AsyncData(const SessionState.signedOut());
    ref.invalidateSelf();
  }

  /// Invoked by the client on a `401`: always drops to signed-out, even if the
  /// request that failed was a background poll.
  void onTokenRejected() {
    if (state.valueOrNull?.isSignedIn ?? false) {
      signOut();
    }
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );

/// Whether the shell may build at all.
final sessionReadyProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider).valueOrNull?.isReady ?? false,
);

/// The signed-in account, or null while the session is still resolving.
final currentUserProvider = Provider<PartnerUser?>(
  (ref) => ref.watch(sessionProvider).valueOrNull?.user,
);

/// Device preferences, overridden in `main()` after `getInstance()` so no
/// screen ever awaits storage mid-build.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// WebSocket service for real-time updates.
///
/// Connects automatically when the session becomes signed-in and disconnects
/// on sign-out. Screens subscribe to specific events (new bookings, chat
/// messages) via [WebSocketService.on] and unsubscribe via [off].
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService.instance;

  // Watch the session and connect/disconnect the socket accordingly.
  ref.listen<AsyncValue<SessionState>>(sessionProvider, (previous, next) {
    final prevState = previous?.value;
    final nextState = next.value;
    final wasSignedIn = prevState?.isSignedIn ?? false;
    final isSignedIn = nextState?.isSignedIn ?? false;
    final token = nextState?.token;

    if (!wasSignedIn && isSignedIn && token != null) {
      // Session just became signed-in: open the socket.
      service.connect(token);
    } else if (wasSignedIn && !isSignedIn) {
      // Session just signed out: tear down the socket.
      service.disconnect();
    }
  });

  ref.onDispose(() => service.disconnect());
  return service;
});

/// Current WebSocket connection status, surfaced for UI indicators.
final webSocketStatusProvider = Provider<WebSocketStatus>((ref) {
  return ref.watch(webSocketServiceProvider).status;
});
