import 'dart:convert';
import 'dart:typed_data';

import '../api/api_client.dart';

/// Venue photo uploads: `POST /partner/restaurants/:id/images`.
///
/// This repository deliberately does ONE thing — store bytes and hand back the
/// URL the server minted. Repointing a column at that URL stays with whichever
/// form owns the field (profile, menu item, deal), so "upload" never becomes a
/// second, parallel way to edit a venue.
class ImageRepository {
  ImageRepository(this._api);

  final ApiClient _api;

  static String base(String venueId) => '/partner/restaurants/$venueId';

  /// Uploads [bytes] as a venue photo and returns its stored path
  /// (`/public/venue-images/<id>`, relative to the API root).
  ///
  /// [onProgress] reports 0..1 while the base64 body uploads, so a manager on a
  /// slow connection sees movement rather than a frozen spinner.
  Future<String> upload(
    String venueId,
    Uint8List bytes, {
    String kind = 'general',
    void Function(double progress)? onProgress,
  }) async {
    final envelope = await _api.envelopePost(
      '${base(venueId)}/images',
      body: {'image': base64Encode(bytes), 'kind': kind},
      onSendProgress: onProgress == null
          ? null
          : (sent, total) {
              if (total <= 0) return;
              onProgress((sent / total).clamp(0.0, 1.0));
            },
    );
    final image = envelope.resourceMap('image');
    final url = image?['url'];
    if (url is! String || url.isEmpty) {
      // The server always answers a URL; if it does not, the field must not
      // silently store an empty string and look like a successful upload.
      throw StateError('The upload did not return a photo URL');
    }
    return url;
  }

  /// Retires one upload by id. Best effort: callers use it when replacing a
  /// photo, where a failure only leaves an orphaned row, never a broken screen.
  Future<void> delete(String venueId, String imageId) async {
    await _api.deleteJson('${base(venueId)}/images/$imageId');
  }
}

/// The uploaded id of a stored path, or null when it is not one of ours.
///
/// Needed only by the "replace" path, which retires the photo it supersedes.
String? venueImageId(String? storedPath) {
  final value = storedPath?.trim() ?? '';
  const prefix = '/public/venue-images/';
  if (!value.startsWith(prefix)) return null;
  final id = value.substring(prefix.length);
  return id.isEmpty || id.contains('/') ? null : id;
}
