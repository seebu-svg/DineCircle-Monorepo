import 'package:flutter/material.dart';

import '../models/venue.dart';
import '../theme/app_colors.dart';
import '../utils/links.dart';
import 'qr_code_view.dart';

enum QrCardStyle {
  classicIvory('Classic Ivory', Color(0xFFF7F1E5), Color(0xFF292722)),
  midnightPremium('Midnight Premium', Color(0xFF1C1C1E), Color(0xFFF7F1E5)),
  minimalWhite('Minimal White', Colors.white, Color(0xFF222222));

  const QrCardStyle(this.label, this.background, this.ink);
  final String label;
  final Color background;
  final Color ink;
}

/// The same widget is previewed and captured: exports cannot drift from the card.
/// Identity comes exclusively from the venue. The API has no logo/category field.
class QrStudioCard extends StatelessWidget {
  const QrStudioCard({super.key, required this.venue, required this.style});
  final Venue venue;
  final QrCardStyle style;

  @override
  Widget build(BuildContext context) {
    final minimal = style == QrCardStyle.minimalWhite;
    final cover = Uri.tryParse(venue.coverImage.trim());
    final hasCover =
        !minimal &&
        cover != null &&
        (cover.scheme == 'https' || cover.scheme == 'http') &&
        cover.host.isNotEmpty;
    return ColoredBox(
      color: style.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasCover)
            LayoutBuilder(
              builder: (_, constraints) => Image.network(
                cover.toString(),
                width: constraints.maxWidth,
                height: constraints.maxWidth / 3.4,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        height: constraints.maxWidth / 3.4,
                        child: const Center(
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!minimal) ...[
                  Container(width: 28, height: 2, color: AppColors.primary),
                  const SizedBox(height: 16),
                ],
                Text(
                  venue.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: style.ink,
                    fontSize: minimal ? 24 : 28,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    fontFamily: minimal ? null : 'Georgia',
                    fontFamilyFallback: const ['Noto Serif', 'serif'],
                  ),
                ),
                if (venue.cuisines.isNotEmpty && !minimal) ...[
                  const SizedBox(height: 8),
                  Text(
                    venue.cuisines.join(' · '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: style.ink.withValues(alpha: .7),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (_, constraints) => QrCodeView(
                    data: venuePublicUrl(venue.id),
                    size: constraints.maxWidth.clamp(0, 260).toDouble(),
                    foreground: Colors.black,
                    semanticsLabel: 'Venue QR code for ${venue.name}',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan. Explore. Enjoy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: style.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Discover our menu on DineCircle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: style.ink.withValues(alpha: .65),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Powered by DineCircle',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: style.ink.withValues(alpha: .65),
                    fontSize: 11,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
