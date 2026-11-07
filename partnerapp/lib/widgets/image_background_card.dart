import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Maps semantic card types to appropriate restaurant/food photography assets.
///
/// Each key is a logical card purpose; the value is the asset path that best
/// represents it visually. Images are chosen from the bundled set to match
/// the card's function (reservations → dining tables, QR → menu stands, etc.).
class CardImageAssets {
  CardImageAssets._();

  // ── Today's Overview KPIs ─────────────────────────────────────────────────
  static const String reservations = 'assets/images/venue_interior.png';
  static const String qrScans = 'assets/images/venue_bar.png';
  static const String activeDeals = 'assets/images/dish_steak.png';
  static const String experiences = 'assets/images/hero_tasting.png';

  // ── Quick Actions ─────────────────────────────────────────────────────────
  static const String editMenu = 'assets/images/dish_pasta.png';
  static const String createDeal = 'assets/images/dish_brunch.png';
  static const String qrCode = 'assets/images/venue_rooftop.png';
  static const String reservationsBoard = 'assets/images/dish_sushi.png';

  // ── Section backgrounds ───────────────────────────────────────────────────
  static const String upcomingReservations = 'assets/images/venue_interior.png';
  static const String recentActivity = 'assets/images/venue_bar.png';
}

/// A card with a photographic background and a dark scrim overlay for readability.
///
/// The image is painted edge-to-edge behind the [child], with a gradient overlay
/// that ensures text remains legible regardless of the photograph's brightness.
/// The overlay runs from a translucent dark at the top to a more opaque dark at
/// the bottom, matching the dashboard's premium dark aesthetic.
///
/// When [imageAsset] is null or empty, falls back to a plain dark surface so
/// the card never renders a broken image.
class ImageBackgroundCard extends StatelessWidget {
  const ImageBackgroundCard({
    super.key,
    required this.child,
    this.imageAsset,
    this.overlayOpacity = 0.65,
    this.borderRadius,
    this.border,
  });

  /// The foreground content (text, icons, stats) rendered above the image.
  final Widget child;

  /// Repo-relative path to the background photograph.
  final String? imageAsset;

  /// How dark the scrim overlay is. 0 = transparent, 1 = opaque black.
  /// Defaults to 0.65 for optimal text readability over busy photographs.
  final double overlayOpacity;

  /// Corner radius. Defaults to [AppSpacing.radiusLg].
  final BorderRadius? borderRadius;

  /// Optional border drawn atop the image (inside the clip).
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg);
    final hasImage = imageAsset != null && imageAsset!.isNotEmpty;

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border ?? Border.all(color: AppColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background layer ──────────────────────────────────────────
            if (hasImage)
              Image.asset(
                imageAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _2, _3) => _fallbackBackground(),
              )
            else
              _fallbackBackground(),

            // ── Dark scrim overlay ────────────────────────────────────────
            if (hasImage)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: overlayOpacity * 0.7),
                      Colors.black.withValues(alpha: overlayOpacity),
                    ],
                  ),
                ),
              ),

            // ── Foreground content ────────────────────────────────────────
            child,
          ],
        ),
      ),
    );
  }

  /// Plain dark surface used when no image is available or the image fails.
  Widget _fallbackBackground() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surfaceElevated],
        ),
      ),
    );
  }
}
