import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Where a venue photo comes from.
enum ImageSourceChoice { camera, gallery }

/// Picks and downscales one photo, returning its bytes (null = the partner
/// cancelled). A provider so widget tests can swap the platform picker for
/// canned bytes instead of driving a real camera or gallery.
typedef VenueImagePicker = Future<Uint8List?> Function(
  ImageSourceChoice source,
);

/// Server ceiling for `POST /partner/restaurants/:id/images` — mirrors
/// `MAX_VENUE_IMAGE_BYTES` in `server/src/venue_images.ts`.
const int kMaxVenueImageBytes = 512 * 1024;

final venueImagePickerProvider = Provider<VenueImagePicker>((ref) {
  final picker = ImagePicker();
  return (source) async {
    // A dish or deal photo is rendered at card or hero size at most; 1280px at
    // quality 82 lands a typical JPEG near 100–200 KB, comfortably under the
    // 512 KB cap, which also keeps the base64 body under the server's 1 MB
    // express.json limit.
    final file = await picker.pickImage(
      source: source == ImageSourceChoice.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 82,
    );
    if (file == null) return null;
    return file.readAsBytes();
  };
});

/// Turns an image-picker [PlatformException] into a sentence a restaurant
/// manager can act on, for the same reason the customer app does: "permission
/// denied" is useless to a chef holding a phone.
String imagePickerError(PlatformException error, ImageSourceChoice source) {
  final code = error.code.toLowerCase();
  if (code.contains('access_denied') || code.contains('permission')) {
    return source == ImageSourceChoice.camera
        ? 'Camera access is off. Allow it in your device settings.'
        : 'Photo access is off. Allow it in your device settings.';
  }
  if (code.contains('no_available_camera')) {
    return 'No camera is available on this device.';
  }
  return 'Could not open that photo. Try another one.';
}
