# Partner App - Quick Setup Guide

## ✅ Project Created Successfully

The DineCircle Partner App has been set up with the same tech stack as the main app.

## 📁 Project Structure

```
partnerapp/
├── lib/
│   ├── api/              # HTTP client & error handling
│   │   ├── api_client.dart
│   │   ├── api_error.dart
│   │   └── app_config.dart
│   ├── config/           # Build-time configuration
│   │   └── app_config.dart
│   ├── screens/          # UI screens
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── events/
│   │   ├── bookings/
│   │   └── settings/
│   ├── models/
│   ├── providers/
│   ├── repositories/
│   ├── services/
│   ├── theme/
│   ├── utils/
│   └── widgets/
├── dart-defines.json     # Your local config (points to 192.168.100.70:4000)
├── dart-defines.example.json
├── pubspec.yaml
└── README.md
```

## 🚀 Next Steps

### 1. Verify Backend is Running
The partner app connects to the same Express backend as the main app:
```bash
# Check if server is running on your machine
curl http://192.168.100.70:4000/health
```

### 2. Run the App
```bash
cd /home/til3fishnix001/Downloads/Projects/DineCircle/partnerapp

# Run on connected device/emulator
flutter run --dart-define-from-file=dart-defines.json

# Or run on specific device
flutter devices  # List available devices
flutter run -d <device-id> --dart-define-from-file=dart-defines.json
```

### 3. Build APK
```bash
# Debug build
flutter build apk --debug --dart-define-from-file=dart-defines.json

# Release build
flutter build apk --release --dart-define-from-file=dart-defines.json
```

## 🔑 Test Login Credentials

Use the partner admin account:
- **Email**: `karachi.desk+demo@example.test`
- **Password**: `dinecircle123`

## 📡 API Configuration

The app is configured to connect to your local network server:
- **API Base URL**: `http://192.168.100.70:4000`
- **Timeout**: 30 seconds

To change this, edit `dart-defines.json`:
```json
{
  "API_BASE_URL": "http://YOUR_NEW_IP:4000"
}
```

## 🏗️ Architecture

### API Client
All HTTP calls go through `ApiClient` (lib/api/api_client.dart):
- Centralized error handling
- Automatic Bearer token authentication
- Timeout management
- JSON parsing

### Configuration
Build-time config via `AppConfig` (lib/config/app_config.dart):
- Read from dart-define flags
- Environment-specific values
- No hardcoded secrets

### Error Handling
Structured errors via `ApiError` and `ApiException`:
- Parse backend error responses
- Include status codes and error details
- Type-safe error handling

## 📝 Adding Features

### Create a New Screen
1. Add screen file in `lib/screens/<feature>/`
2. Create provider in `lib/providers/` if needed
3. Add route in `lib/main.dart`
4. Use `ApiClient` for API calls

### Example: Fetch Restaurant Data
```dart
import 'package:partnerapp/api/api_client.dart';

final client = ApiClient();
client.setAuthToken('your-token');

try {
  final data = await client.get('/api/restaurants/abc123');
  // Handle success
} catch (e) {
  // Handle error (ApiException)
}
```

## 🔍 Code Quality

Run analysis:
```bash
flutter analyze
```

Run tests:
```bash
flutter test
```

Format code:
```bash
dart format lib/
```

## 📦 Dependencies

Current dependencies (pubspec.yaml):
- `flutter`: SDK
- `http`: ^1.2.0 (API calls)
- `cupertino_icons`: ^1.0.8 (iOS icons)

Add more as needed:
```bash
flutter pub add provider  # Example: state management
```

## 🎨 Theming

Add your theme in `lib/theme/`:
```dart
// lib/theme/partner_theme.dart
import 'package:flutter/material.dart';

class PartnerTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      // ... your theme
    );
  }
}
```

## 📱 Platform Setup

### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 34
- Located in `android/app/build.gradle`

### iOS
- Minimum iOS: 12.0
- Located in `ios/Runner/Info.plist`

### Web
- Already configured
- Run with: `flutter run -d chrome`

## �� Troubleshooting

### "API_BASE_URL not reachable"
1. Check if server is running: `curl http://192.168.100.70:4000/health`
2. Verify your device is on the same network
3. Update IP in `dart-defines.json` if needed

### "Build fails with dependency conflict"
```bash
flutter pub upgrade --major-versions
flutter clean
flutter pub get
```

### "No devices found"
```bash
flutter devices  # Check connected devices
flutter doctor   # Verify Flutter setup
```

## 📚 Resources

- [Flutter Documentation](https://docs.flutter.dev)
- [Dart Language Tour](https://dart.dev/language)
- Main DineCircle app: `/home/til3fishnix001/Downloads/Projects/DineCircle/DineCircle-master`

## ✅ Verification Checklist

- [x] Flutter project created
- [x] Folder structure set up
- [x] API client implemented
- [x] Error handling in place
- [x] Configuration system ready
- [x] Dependencies installed
- [x] Code analysis passes
- [x] README and docs created

---

**Ready to start building!** 🎉
