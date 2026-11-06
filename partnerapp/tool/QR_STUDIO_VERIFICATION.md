# QR Studio verification

The studio reuses `venuePublicUrl`, `QrCodeView`, the selected venue and the existing active-deals provider. No backend, authentication, navigation, or API contracts changed. The venue model has no logo or category field; the templates use the real name, cover image and cuisines. Minimal White intentionally omits photography.

Flutter SDK platform channels connect to Android's document picker, `PdfDocument` and share intent, and iOS's document picker, `UIGraphicsPDFRenderer` and activity sheet. No new package dependencies or storage permissions are required. Export/share controls are disabled with guidance on other platforms. Native dialog cancellation does not produce a success message.

PNG exports are 1500 pixels wide. PDFs have a 105mm page width, 5mm white margins and a minimum 148mm page height. The page grows for long names and larger accessibility text; the image is never stretched or clipped to an A6 rectangle. QR artwork has four-module white quiet zones and no logo overlay. The PDF image resolution exceeds 300dpi at 95mm printable width.

## Completed in this environment

- Flutter rendering smoke check: all three templates at 320 logical pixels, 1× and 2× text scaling, with a long restaurant name and no cover image. No layout errors.
- Independent libzbar decoding of all six actual exported PNGs: every payload equals `https://dinecircle.app/menu/ven_123`.
- Kotlin compilation of `MainActivity.kt` against the cached Android 36 SDK, Flutter embedding, Kotlin 2.4 and AndroidX Core passed. This is a source compile, not an APK installation test.
- Flutter widget/service tests were added/updated for identity, quiet zones, templates, read-only collapsible deal codes, and native export request/cancellation/error contracts. The normal test runner cannot start in this sandbox because binding a localhost socket is denied.

## Repeatable checks

```sh
flutter analyze
flutter test test/widget/qr_tab_test.dart test/widget/qr_code_view_test.dart test/widget/qr_studio_card_test.dart test/services/qr_studio_export_test.dart
```

The SDK engine can render the smoke check without a test-runner socket. With `FLUTTER_ROOT` pointing to your Flutter installation:

```sh
"$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dartaotruntime" \
  "$FLUTTER_ROOT/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot" \
  --sdk-root "$FLUTTER_ROOT/bin/cache/artifacts/engine/common/flutter_patched_sdk" \
  --target=flutter --packages .dart_tool/package_config.json \
  --output-dill /tmp/qr-studio-smoke.dill tool/verify_qr_studio.dart
"$FLUTTER_ROOT/bin/cache/artifacts/engine/linux-x64/flutter_tester" \
  --disable-vm-service --run-forever /tmp/qr-studio-smoke.dill
python tool/decode_qr_studio.py
```

The Python decoder requires Pillow and libzbar. Artifacts remain in `/tmp/dinecircle-qr-verification`.

## Device validation still required

On Android and iOS, test all three styles with real restaurant data, a working cover URL, a missing cover and an unreachable cover URL. Verify long names and accessibility scaling. Save PNG and PDF through the system picker, cancel and retry, and share the PNG into another app. On iPad, check the share popover. Open Preview and compare the destination with Copy link.

Scan the screen, saved PNG and printed PDF at actual size using both Android and iOS cameras. Confirm the venue URL, including encoded venue IDs. PDF generation and native dialogs are implemented but cannot be executed on this Linux sandbox; these device checks must pass before release. Confirm unverified restaurants show guidance and their guest page is actually accessible before distributing cards.

## Platform references

- [Flutter SDK platform channels](https://docs.flutter.dev/platform-integration/platform-channels)
- [Android document creation without storage permissions](https://developer.android.com/training/data-storage/shared/documents-files)
- [Android PDF renderer](https://developer.android.com/reference/android/graphics/pdf/PdfDocument)
- [Apple PDF renderer](https://developer.apple.com/documentation/uikit/uigraphicspdfrenderer)
