import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';

/// Resolves a stored media reference into an absolute URL, or null when it is
/// not a remote reference at all.
///
/// The server stores uploaded photos as `/public/venue-images/<id>`, relative
/// to the API root, so the value survives a host change. `Image.network` needs
/// an absolute URL, so that prefix is expanded against [AppConfig.apiUrl] here
/// rather than at each call site.
String? mediaImageUrl(String? source) {
  final value = source?.trim() ?? '';
  if (value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  if (value.startsWith('/')) return '${AppConfig.apiUrl}$value';
  return null;
}

/// Image loader for every media value the partner API returns.
///
/// Three shapes arrive in the same string columns:
///  * `/public/venue-images/<id>`, a photo uploaded through the partner app,
///    stored relative to the API root and expanded by [mediaImageUrl];
///  * `http(s)://…`, an external URL;
///  * anything else, a bundled asset (seeded rows, older records).
///
/// Empty and unreadable sources degrade to a branded placeholder instead of
/// throwing, so a missing photo never blanks a card or a form preview.
///
/// Wrap it in a sized or aspect-ratio-constrained parent; the widget fills that
/// box.
class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.fallbackIcon = Icons.image_outlined,
    this.cacheWidth,
  });

  /// Raw media value from the API; may be null or empty.
  final String? source;
  final BoxFit fit;

  /// Icon painted by the placeholder when no image is available.
  final IconData fallbackIcon;

  /// Decode remote images at this logical width to bound memory on lists.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final raw = source?.trim() ?? '';
    if (raw.isEmpty) return _placeholder();
    final url = mediaImageUrl(raw);
    if (url == null) {
      return Image.asset(
        raw,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }
    // The placeholder paints underneath so a slow upload never flashes a blank
    // region where the photo will land.
    return Stack(
      fit: StackFit.expand,
      children: [
        _placeholder(),
        Image.network(
          url,
          fit: fit,
          cacheWidth: cacheWidth,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: child,
            );
          },
          errorBuilder: (context, error, stackTrace) => _placeholder(),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceElevated, AppColors.surfaceHigh],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(fallbackIcon, color: AppColors.textTertiary),
      ),
    );
  }
}
