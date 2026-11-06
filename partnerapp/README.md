# DineCircle Partner App

Restaurant partner application for the DineCircle platform. Built with Flutter, connecting to the Express backend API.

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Provider (Riverpod-ready)
- **Networking**: HTTP client with centralized error handling
- **Backend**: Express.js API (shared with main DineCircle app)
- **Database**: PostgreSQL 17 (via Express API)
- **Authentication**: Bearer token (scrypt password hashing)

## Project Structure

```
lib/
├── api/              # HTTP client, error handling, API config
├── config/           # Build-time configuration (AppConfig)
├── data/             # Data sources and repositories
├── models/           # Data models and entities
├── providers/        # State management providers
├── repositories/     # Business logic repositories
├── screens/          # UI screens
│   ├── auth/        # Login/authentication
│   ├── dashboard/   # Partner dashboard
│   ├── events/      # Event management
│   ├── bookings/    # Booking management
│   └── settings/    # App settings
├── services/         # Platform services (storage, notifications)
├── theme/            # App theme and styling
├── utils/            # Utility functions
└── widgets/          # Reusable UI components
```

## Setup

### Prerequisites

- Flutter SDK 3.x
- Android SDK / Xcode for mobile builds
- DineCircle backend server running

### Configuration

1. Copy the example config file:
   ```bash
   cp dart-defines.example.json dart-defines.json
   ```

2. Edit `dart-defines.json` with your API endpoint:
   ```json
   {
     "API_BASE_URL": "http://YOUR_SERVER_IP:4000"
   }
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

## Running the App

### Development (Local Network)

```bash
flutter run --dart-define-from-file=dart-defines.json
```

### Build APK

```bash
flutter build apk --debug --dart-define-from-file=dart-defines.json
```

### Build Release APK

```bash
flutter build apk --release --dart-define-from-file=dart-defines.json
```

## Test Accounts

The partner app uses the same backend as the main DineCircle app. Test with partner accounts:

| Email | Password | Role |
|-------|----------|------|
| `karachi.desk+demo@example.test` | `dinecircle123` | Partner Admin |

## API Endpoints

All API calls go through the Express backend. Key partner endpoints:

- `POST /api/auth/login` - Authenticate
- `GET /api/restaurants/:id` - Get restaurant details
- `GET /api/restaurants/:id/events` - Get events for restaurant
- `POST /api/events` - Create new event
- `GET /api/bookings` - Get bookings
- `GET /api/payouts` - Get earnings

## Architecture Notes

- **ApiClient**: Centralized HTTP client in `lib/api/api_client.dart`
- **Error Handling**: All API errors wrapped in `ApiException` with structured `ApiError`
- **Config**: Build-time config via `AppConfig` class, read from dart-define flags
- **Auth**: Bearer token authentication, managed via session providers

## Development

### Code Style

Follow the existing DineCircle code style:
- Use `final` for immutable variables
- Document public APIs with dartdoc
- Keep screens thin, push logic to providers/repositories

### Adding a New Screen

1. Create screen file in `lib/screens/`
2. Add route in `lib/main.dart`
3. Create provider if needed in `lib/providers/`
4. Use `ApiClient` for all HTTP calls

### Testing

```bash
flutter test
```

## Deployment

### Android

1. Update version in `pubspec.yaml`
2. Build release APK:
   ```bash
   flutter build apk --release --dart-define-from-file=dart-defines.json
   ```
3. APK located at `build/app/outputs/flutter-apk/app-release.apk`

### iOS

1. Update version in `pubspec.yaml` and Xcode project
2. Build release:
   ```bash
   flutter build ios --release --dart-define-from-file=dart-defines.json
   ```
3. Open in Xcode and archive for distribution

## License

Proprietary - DineCircle Platform
