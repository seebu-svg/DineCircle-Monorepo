# Partner App API Integration Guide

This document describes how the DineCircle Partner app connects to the shared Express backend API.

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Configuration](#configuration)
3. [Authentication Flow](#authentication-flow)
4. [API Endpoints](#api-endpoints)
5. [Data Models](#data-models)
6. [Error Handling](#error-handling)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

The DineCircle platform consists of:

- **Customer App** (`DineCircle-master/`): Flutter app for diners to discover and book experiences
- **Partner App** (`partnerapp/`): Flutter app for restaurant operators to manage venues, events, and bookings
- **Backend API** (`DineCircle-master/server/`): Express.js server with PostgreSQL database

Both Flutter apps connect to the **same backend API**, which provides:
- RESTful endpoints under `/api/*`
- WebSocket support for real-time updates
- Bearer token authentication
- Role-based access control (RBAC)

### Network Topology

```
┌─────────────────┐
│  Customer App   │
│  (port 8080)    │
└────────┬────────┘
         │
         │ HTTP/WebSocket
         │
┌────────▼────────┐      ┌──────────────┐
│  Backend API    │◄────►│  PostgreSQL  │
│  (port 4000)    │      │  (port 5433) │
└────────┬────────┘      └──────────────┘
         │
         │ HTTP/WebSocket
         │
┌────────▼────────┐
│  Partner App    │
│  (port 8080)    │
└─────────────────┘
```

---

## Configuration

### API Base URL

Both apps use build-time configuration via `dart-defines.json`:

**Customer App** (`DineCircle-master/dart-defines.json`):
```json
{
  "API_BASE_URL": "http://192.168.100.70:4000",
  "API_TIMEOUT_MS": "30000",
  "ENVIRONMENT": "development"
}
```

**Partner App** (`partnerapp/dart-defines.json`):
```json
{
  "API_BASE_URL": "http://192.168.100.70:4000",
  "API_TIMEOUT_MS": "30000",
  "ENVIRONMENT": "development"
}
```

⚠️ **Important**: Both apps must point to the same `API_BASE_URL` to share the backend.

### Configuration Class

The Partner app reads configuration in `lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
  
  static String get apiUrl => '$apiBaseUrl/api';
  
  static const int apiTimeoutMs = int.fromEnvironment(
    'API_TIMEOUT_MS',
    defaultValue: 30000,
  );
}
```

### Server CORS Configuration

The Express server (`server/src/server.ts`) allows requests from both apps:

```typescript
app.use(cors({
  origin: (origin, callback) => {
    const allowed = [
      'http://localhost:3000',
      'http://localhost:4000',
      'http://localhost:8080',
      'http://192.168.100.70:4000',  // Customer app
      'http://192.168.100.46:4000',  // Partner app (alt IP)
    ];
    if (allowed.includes(origin)) return callback(null, true);
    if (process.env.NODE_ENV !== 'production') return callback(null, true);
    callback(new Error('CORS: origin not allowed'));
  },
}));
```

In development mode (`NODE_ENV=development`), all origins are allowed.

---

## Authentication Flow

### 1. Login

**Endpoint**: `POST /api/auth/login`

**Request**:
```json
{
  "email": "karachi.desk+demo@example.test",
  "password": "dinecircle123"
}
```

**Response** (200 OK):
```json
{
  "token": "abc123def456...",
  "user": {
    "id": "uuid-here",
    "email": "karachi.desk+demo@example.test",
    "name": "Karachi Desk",
    "role": "partner_admin"
  },
  "expiresAt": "2026-11-09T12:00:00.000Z"
}
```

**Partner App Implementation** (`lib/repositories/auth_repository.dart`):
```dart
Future<AuthSession> signIn({
  required String email,
  required String password,
}) async {
  final body = await _api.postMap(
    '/auth/login',
    body: {'email': email.trim().toLowerCase(), 'password': password},
  );
  final token = asString(body['token']);
  return AuthSession(
    token: token,
    user: PartnerUser.fromJson(asMap(body['user'])),
    expiresAt: asDate(body['expiresAt']),
  );
}
```

### 2. Token Storage

The token is stored securely using `flutter_secure_storage`:

```dart
const kTokenKey = 'dinecircle.partner.token';

await storage.write(key: kTokenKey, value: session.token);
```

### 3. Session Restore

On app restart, the session is restored via `GET /api/auth/me`:

```dart
Future<PartnerUser> me() async {
  final envelope = await _api.envelopeGet('/auth/me');
  return PartnerUser.fromJson(envelope.resourceMap('user') ?? envelope.data);
}
```

**Flow**:
1. Read token from secure storage
2. Set `ApiClient.token`
3. Call `/auth/me` to validate token
4. If valid → `SessionStatus.signedIn`
5. If invalid (401) → clear token → `SessionStatus.signedOut`

### 4. Bearer Token Authentication

All authenticated requests include the token in the `Authorization` header:

```dart
class ApiClient {
  String? token;
  
  Future<dynamic> _send(String method, String path, {...}) async {
    final options = Options(
      method: method,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return dio.request(path, data: body, options: options);
  }
}
```

### 5. 401 Handling

When the server returns 401 (token expired/revoked):

```dart
ApiClient.onUnauthorized = () {
  SessionController.onTokenRejected();
};

// In SessionController:
void onTokenRejected() {
  if (state.valueOrNull?.isSignedIn ?? false) {
    signOut();  // Clears token and redirects to login
  }
}
```

### 6. Partner Roles

Only users with these roles can access partner endpoints:

```dart
static const List<String> partnerRoles = [
  'restaurant_owner',
  'restaurant_staff',
  'restaurant_manager',
  'partner_admin',
  'super_admin',
  'host',
];
```

The server enforces role-based access in `server/src/access.ts`.

---

## API Endpoints

### Authentication Endpoints

| Method | Endpoint | Purpose | Auth Required |
|--------|----------|---------|---------------|
| POST | `/auth/login` | Sign in | No |
| POST | `/auth/signout` | Sign out | Yes |
| GET | `/auth/me` | Get current user | Yes |
| GET | `/users/me` | Get user profile | Yes |
| PATCH | `/users/me` | Update profile | Yes |
| POST | `/auth/change-password` | Change password | Yes |
| POST | `/auth/change-email` | Start email change | Yes |
| POST | `/auth/change-email/confirm` | Confirm email change | Yes |
| POST | `/auth/logout-all` | Revoke all sessions | Yes |

### Venue Management Endpoints

| Method | Endpoint | Purpose | Role Required |
|--------|----------|---------|---------------|
| GET | `/partner/restaurants` | List venues | Partner |
| GET | `/partner/restaurants/:id` | Venue details | Partner |
| POST | `/partner/restaurants` | Register venue | Partner |
| PATCH | `/partner/restaurants/:id` | Update profile | Manager+ |
| POST | `/partner/restaurants/:id/verification` | Request verification | Owner+ |
| GET | `/partner/verification/requests` | Verification queue | Super Admin |
| POST | `/partner/verification/requests/:id/review` | Approve/reject | Super Admin |

### Menu Management Endpoints

| Method | Endpoint | Purpose | Role Required |
|--------|----------|---------|---------------|
| GET | `/partner/restaurants/:id/menu` | List menu items | Partner |
| POST | `/partner/restaurants/:id/menu` | Create item | Manager+ |
| PATCH | `/partner/restaurants/:id/menu/:itemId` | Update item | Manager+ |
| DELETE | `/partner/restaurants/:id/menu/:itemId` | Remove item | Manager+ |

### Operations Endpoints

| Method | Endpoint | Purpose | Role Required |
|--------|----------|---------|---------------|
| GET | `/partner/restaurants/:id/bookings` | List bookings | Partner |
| PATCH | `/partner/restaurants/:id/bookings/:bid` | Update status | Staff+ |
| POST | `/partner/restaurants/:id/checkin` | Check-in guest | Staff+ |
| GET | `/partner/restaurants/:id/tables` | List tables | Partner |
| POST | `/partner/restaurants/:id/tables` | Create table | Manager+ |
| PATCH | `/partner/restaurants/:id/tables/:tid` | Update table | Manager+ |

### Experience (Events) Endpoints

| Method | Endpoint | Purpose | Role Required |
|--------|----------|---------|---------------|
| POST | `/partner/events` | Create event | Manager+ |
| PUT | `/partner/events/:id` | Update event | Manager+ |
| DELETE | `/partner/events/:id` | Cancel event | Manager+ |
| GET | `/partner/restaurants/:id/events` | List venue events | Partner |
| GET | `/partner/restaurants/:id/hosts` | List host applications | Partner |
| PATCH | `/partner/restaurants/:id/hosts/:hid` | Approve/reject host | Manager+ |

### Business Endpoints

| Method | Endpoint | Purpose | Role Required |
|--------|----------|---------|---------------|
| GET | `/partner/restaurants/:id/deals` | List deals | Partner |
| POST | `/partner/restaurants/:id/deals` | Create deal | Manager+ |
| PATCH | `/partner/restaurants/:id/deals/:did` | Update deal | Manager+ |
| DELETE | `/partner/restaurants/:id/deals/:did` | Remove deal | Manager+ |
| GET | `/partner/restaurants/:id/earnings` | Earnings report | Owner+ |
| GET | `/partner/restaurants/:id/payouts` | Payout history | Owner+ |
| GET | `/partner/restaurants/:id/reviews` | Guest reviews | Partner |

---

## Data Models

### PartnerUser

```dart
class PartnerUser {
  final String id;
  final String email;
  final String name;
  final String role;  // partner_admin, restaurant_owner, etc.
  final String? phone;
  final String? avatarUrl;
  
  factory PartnerUser.fromJson(Map<String, dynamic> json) {
    return PartnerUser(
      id: asString(json['id']),
      email: asString(json['email']),
      name: asString(json['name']),
      role: asString(json['role']),
      phone: asStringOrNull(json['phone']),
      avatarUrl: asStringOrNull(json['avatarUrl']),
    );
  }
}
```

### Venue

```dart
class Venue {
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
  final String priceRange;
  final double rating;
  final int reviewCount;
  final int seats;
  final int tablesCount;
  final bool verified;
  final String partnershipStatus;
  final List<String> amenities;
  final Map<String, dynamic> openingHours;
  
  factory Venue.fromJson(Map<String, dynamic> json) => ...;
}
```

### Experience (Event)

```dart
class Experience {
  final String id;
  final String title;
  final String restaurantId;
  final DateTime startAt;
  final DateTime endAt;
  final int seatsTotal;
  final int seatsBooked;
  final double pricePerSeat;
  final String status;  // draft, confirmed, live, completed, cancelled
  final String type;  // dinner, tasting, brunch, etc.
  final String audience;  // public, followers, inviteOnly
  
  factory Experience.fromJson(Map<String, dynamic> json) => ...;
}
```

### Booking

```dart
class Booking {
  final String id;
  final String eventId;
  final String userId;
  final String guestName;
  final String guestEmail;
  final int partySize;
  final DateTime date;
  final String status;  // pending, confirmed, seated, completed, cancelled
  final double amount;
  
  factory Booking.fromJson(Map<String, dynamic> json) => ...;
}
```

### MenuItem

```dart
class MenuItem {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;  // starter, main, dessert, drink
  final bool available;
  
  factory MenuItem.fromJson(Map<String, dynamic> json) => ...;
}
```

### Deal

```dart
class Deal {
  final String id;
  final String restaurantId;
  final String title;
  final String description;
  final double value;
  final String? code;
  final DateTime startsAt;
  final DateTime endsAt;
  final int maxRedemptions;
  final int currentRedemptions;
  final String status;  // draft, live, paused, expired
  
  factory Deal.fromJson(Map<String, dynamic> json) => ...;
}
```

---

## Error Handling

### ApiException

All API errors are wrapped in `ApiException`:

```dart
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  
  ApiException({
    required this.message,
    this.statusCode,
    this.code,
  });
  
  factory ApiException.fromStatus(int? status, dynamic data) {
    switch (status) {
      case 400:
        return ApiException(
          message: data?['error'] ?? 'Bad request',
          statusCode: 400,
          code: 'bad_request',
        );
      case 401:
        return ApiException(
          message: 'Unauthorized',
          statusCode: 401,
          code: 'unauthorized',
        );
      case 403:
        return ApiException(
          message: 'Access denied',
          statusCode: 403,
          code: 'forbidden',
        );
      case 404:
        return ApiException(
          message: 'Resource not found',
          statusCode: 404,
          code: 'not_found',
        );
      case 409:
        return ApiException(
          message: data?['error'] ?? 'Conflict',
          statusCode: 409,
          code: 'conflict',
        );
      case 422:
        return ApiException(
          message: data?['error'] ?? 'Validation failed',
          statusCode: 422,
          code: 'validation_error',
        );
      case 500:
      default:
        return ApiException(
          message: 'Server error',
          statusCode: status,
          code: 'server_error',
        );
    }
  }
  
  factory ApiException.timeout() => ApiException(
    message: 'The server took too long to respond.',
    code: 'timeout',
  );
  
  factory ApiException.network([String? message]) => ApiException(
    message: message ?? 'No connection. Check your network and try again.',
    code: 'network',
  );
}
```

### Error Response Format

The server returns errors in this format:

```json
{
  "error": "Descriptive error message",
  "issues": [...]  // Only for validation errors (422)
}
```

### Handling Errors in UI

```dart
try {
  final venues = await venueRepo.listVenues();
  // Show venues
} on ApiException catch (e) {
  if (e.statusCode == 401) {
    // Redirect to login
  } else if (e.statusCode == 403) {
    // Show "access denied" message
  } else if (e.code == 'network') {
    // Show "check your connection" message
  } else {
    // Show generic error message
  }
}
```

---

## Testing

### 1. Connectivity Test

Run the shell script to verify server reachability:

```bash
./test_api_connectivity.sh
```

This tests:
- Server health endpoint
- CORS configuration
- Login endpoint availability

### 2. Integration Tests

Run the Flutter integration tests:

```bash
cd partnerapp
flutter test test/integration/api_integration_test.dart
```

These tests cover:
- Configuration validation
- Server connectivity
- Authentication flow
- Venue management
- Menu operations
- Bookings & tables
- Events
- Deals & earnings

### 3. Manual Testing

**Login**:
```bash
cd partnerapp
flutter run --dart-define-from-file=dart-defines.json
```

Use test credentials:
- Email: `karachi.desk+demo@example.test`
- Password: `dinecircle123`

**Verify**:
1. ✅ Login succeeds
2. ✅ Dashboard loads with venue list
3. ✅ Can navigate to different tabs (Business, Experiences, Service)
4. ✅ Can create/edit events
5. ✅ Can view bookings
6. ✅ Can manage menu items

---

## Troubleshooting

### "Connection refused" or "No connection"

**Cause**: Server not running or unreachable

**Solution**:
1. Start the server:
   ```bash
   cd DineCircle-master/server
   npm run dev
   ```

2. Verify server is running:
   ```bash
   curl http://192.168.100.70:4000/health
   ```

3. Check firewall allows port 4000

4. Verify IP address in `dart-defines.json`

### "401 Unauthorized" on every request

**Cause**: Token expired or not set

**Solution**:
1. Login again to get a new token
2. Check token is stored in `FlutterSecureStorage`
3. Verify `ApiClient.token` is set correctly

### "CORS: origin not allowed"

**Cause**: Server blocking partner app origin

**Solution**:
1. Check `server/src/server.ts` CORS configuration
2. Add partner app URL to allowed origins
3. Restart server

### "403 Forbidden" on partner endpoints

**Cause**: User doesn't have partner role

**Solution**:
1. Check user role in database:
   ```sql
   SELECT id, email, role FROM users WHERE email = 'your@email.com';
   ```

2. Update role if needed:
   ```sql
   UPDATE users SET role = 'partner_admin' WHERE email = 'your@email.com';
   ```

3. Re-login to get new token with updated role

### Empty venue list

**Cause**: No venues registered or API error

**Solution**:
1. Register a venue first via the partner app
2. Check server logs for query errors
3. Verify user has partner role
4. Test directly with curl:
   ```bash
   curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://192.168.100.70:4000/api/partner/restaurants
   ```

### "Timeout" errors

**Cause**: Server taking too long to respond

**Solution**:
1. Increase timeout in `dart-defines.json`:
   ```json
   {
     "API_TIMEOUT_MS": "60000"
   }
   ```

2. Check server performance (database queries, etc.)

3. Verify network latency between device and server

---

## API Client Architecture

### ApiClient (lib/api/api_client.dart)

Central HTTP client with:
- Dio-based HTTP requests
- Automatic Bearer token injection
- Centralized error mapping
- Retry logic for transient failures
- 401 → sign-out callback

```dart
class ApiClient {
  final Dio dio;
  String? token;
  void Function()? onUnauthorized;
  
  Future<dynamic> getJson(String path, {Map<String, dynamic>? query});
  Future<dynamic> postJson(String path, {Object? body});
  Future<dynamic> patchJson(String path, {Object? body});
  Future<dynamic> deleteJson(String path, {Object? body});
  
  // Envelope helpers for structured responses
  Future<ApiEnvelope> envelopeGet(String path);
  Future<ApiEnvelope> envelopePost(String path, {Object? body});
}
```

### Repository Pattern

Each domain has a repository:
- `AuthRepository` - Authentication & session
- `VenueRepository` - Venue management
- `MenuRepository` - Menu CRUD
- `OperationsRepository` - Bookings & tables
- `ExperienceRepository` - Events & hosts
- `BusinessRepository` - Deals & earnings

Repositories:
- Take `ApiClient` as constructor parameter
- Handle JSON serialization/deserialization
- Throw `ApiException` on errors
- Return typed domain models

### Provider Setup (lib/providers/app_providers.dart)

Riverpod providers wire everything together:

```dart
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  client.onUnauthorized = () {
    ref.read(sessionProvider.notifier).onTokenRejected();
  };
  ref.onDispose(client.close);
  return client;
});

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final sessionProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
```

---

## Security Considerations

1. **Token Storage**: Use `flutter_secure_storage` (encrypted on both iOS and Android)
2. **HTTPS in Production**: Always use HTTPS for `API_BASE_URL` in production
3. **Token Expiry**: Check `expiresAt` and refresh before expiry
4. **Role Verification**: Server enforces RBAC; client checks are UX-only
5. **CORS**: Restrict allowed origins in production
6. **Rate Limiting**: Server enforces rate limits (100/min API, 10/min auth)

---

## Deployment Checklist

Before deploying to production:

- [ ] Update `API_BASE_URL` to production server (HTTPS)
- [ ] Set `ENVIRONMENT=production` in `dart-defines.json`
- [ ] Configure server CORS for production domain
- [ ] Enable analytics and crash reporting
- [ ] Test with production database
- [ ] Verify SSL certificates
- [ ] Set up monitoring/alerting
- [ ] Document production server IP/hostname
- [ ] Test rollback procedure

---

## Resources

- **Server Code**: `DineCircle-master/server/src/`
- **Partner App Code**: `partnerapp/lib/`
- **API Routes**: `DineCircle-master/server/src/routes/`
- **Database Schema**: `DineCircle-master/server/database/schema.sql`
- **Test Credentials**: See README.md in both apps

---

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review server logs (`npm run dev` output)
3. Run integration tests for diagnostics
4. Check API response with curl/Postman

---

**Last Updated**: 2026-11-02  
**API Version**: 1.0  
**Backend**: Express.js + PostgreSQL  
**Client**: Flutter 3.x + Riverpod
