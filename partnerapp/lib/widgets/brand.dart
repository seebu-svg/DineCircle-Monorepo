import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Brand assets used across the partner app.
///
/// The three PNGs under `assets/branding/` are derived from the two source
/// artworks at the repo root by `tool/prepare_brand_assets.py`. They are
/// committed to the repo so the build does not depend on Python at runtime.
class _BrandAssets {
  _BrandAssets._();

  static const String wordmarkLight = 'assets/branding/wordmark_light.png';
  static const String wordmarkDark = 'assets/branding/wordmark_dark.png';
  static const String partnerBadge = 'assets/branding/partner_badge.png';
}

/// The horizontal wordmark, rendered at a fixed logical height.
///
/// Uses the light variant by default (transparent bg, recoloured text) so it
/// reads on the dark theme. Pass [variant] = [BrandWordmarkVariant.dark] for
/// light surfaces such as the login card or printed receipts.
///
/// Falls back to a styled text lockup if the asset is unavailable, so a
/// missing PNG can never blank a screen.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    super.key,
    this.height = 28,
    this.variant = BrandWordmarkVariant.light,
  });

  final double height;
  final BrandWordmarkVariant variant;

  @override
  Widget build(BuildContext context) {
    final asset = variant == BrandWordmarkVariant.light
        ? _BrandAssets.wordmarkLight
        : _BrandAssets.wordmarkDark;
    return Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _TextFallback(height: height),
    );
  }
}

enum BrandWordmarkVariant { light, dark }

/// The rounded-square partner badge, rendered at a fixed logical height.
///
/// The badge carries its own navy field so it reads on any surface; the
/// transparent corners let it sit on tinted panels without a halo.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _BrandAssets.partnerBadge,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => SizedBox(
        height: height,
        width: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.brandNavy,
            borderRadius: BorderRadius.circular(height * 0.22),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(
              'dc',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The full lockup: badge + wordmark + "PARTNER" eyebrow.
///
/// Used on the login screen, the about section and anywhere the brand needs to
/// be announced in full. On tight surfaces use [BrandMark] instead.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.badgeHeight = 48,
    this.wordmarkHeight = 28,
    this.showEyebrow = true,
  });

  final double badgeHeight;
  final double wordmarkHeight;
  final bool showEyebrow;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandBadge(height: badgeHeight),
        const SizedBox(height: 12),
        BrandWordmark(height: wordmarkHeight),
        if (showEyebrow) ...[
          const SizedBox(height: 6),
          Text(
            'PARTNER',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.primary,
              letterSpacing: 2.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact mark for the app-shell header: badge + short wordmark.
///
/// Fits beside the venue switcher on phones without pushing the title off
/// screen. On desktop the sidebar uses [BrandLockup] instead.
///
/// [compact] drops the wordmark and keeps the badge. The header uses it on a
/// phone, where the wordmark plus the venue chip left no room for the venue
/// name and the switcher ellipsised to three letters. The badge is the brand
/// on its own, and the wordmark is still one tap away in the account menu.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        color: AppColors.surface.withValues(alpha: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandBadge(height: 30),
          if (!compact) ...[
            const SizedBox(width: 8),
            const BrandWordmark(height: 18),
          ],
        ],
      ),
    );
  }
}

/// Text fallback used when an asset cannot be loaded.
///
/// Keeps the layout stable and the brand legible even if the asset bundle is
/// missing or the PNG is corrupt.
class _TextFallback extends StatelessWidget {
  const _TextFallback({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'dine',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Circle',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
