import 'package:flutter/material.dart';

import '../../models/experience.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/async_views.dart';
import '../../widgets/media_image.dart';
import '../../widgets/status_chip.dart';

/// Shared presentation for the Experiences module.
///
/// Requests, Proposals and Experiences are three views of one business, so the
/// photographs, the header, the filter rail, the card shell and the status
/// pills live here instead of being re-invented per tab. Nothing in this file
/// reads a provider or writes to the API; it only decides how a row looks.

/// Bundled dining photography per experience format.
///
/// `GET /partner/events` did not return cover art when this screen was built,
/// and a host proposal may arrive without a photo. A card still has to look
/// like a dining experience rather than a database row, so each format falls
/// back to a real photograph from the venue's own library. The asset is
/// deliberately never labelled as the event's photo.
String experienceArtAsset(ExperienceType type) => switch (type) {
  ExperienceType.dinner => 'assets/images/dish_steak.png',
  ExperienceType.tasting => 'assets/images/hero_tasting.png',
  ExperienceType.supperClub => 'assets/images/venue_interior.png',
  ExperienceType.brunch => 'assets/images/dish_brunch.png',
  ExperienceType.workshop => 'assets/images/dish_dessert.png',
  ExperienceType.festival => 'assets/images/venue_rooftop.png',
};

/// The 16:9-ish photo band at the top of an experience card.
///
/// The height is fixed and the photo is painted with `Positioned.fill`, while
/// any overlaid content is a normal child, so the widget stays bounded under a
/// scroll view and cannot blow up an unbounded parent.
class ExperienceArt extends StatelessWidget {
  const ExperienceArt({
    super.key,
    this.source = '',
    required this.type,
    this.height = 118,
    this.topRadius = AppSpacing.radiusLg,
    this.overlay,
  });

  /// Stored media value from the API; empty or unreadable falls back to
  /// [experienceArtAsset].
  final String source;
  final ExperienceType type;
  final double height;
  final double topRadius;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final fallback = experienceArtAsset(type);
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(
              child: MediaImage(
                source: source.trim().isEmpty ? fallback : source,
                fit: BoxFit.cover,
                cacheWidth: 720,
                fallbackIcon: Icons.dinner_dining_outlined,
              ),
            ),
            // A scrim rather than a colour wash: the photo stays readable and
            // a light-on-dark pill still passes contrast at the top edge.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC0A090C), Color(0x1A0A090C)],
                    stops: [0, 0.72],
                  ),
                ),
              ),
            ),
            if (overlay != null)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: overlay,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The photograph-led section header.
///
/// The restaurant name is the overline and never a control: the header says
/// which desk you are at, not which desk you could be at. Counts are plain
/// figures with labels so they stay legible at large text scales.
class ExperienceHeader extends StatelessWidget {
  const ExperienceHeader({
    super.key,
    required this.venueName,
    required this.subtitle,
    this.metrics = const [],
    this.action,
    this.artAsset = 'assets/images/venue_rooftop.png',
  });

  final String venueName;
  final String subtitle;
  final List<({String value, String label})> metrics;
  final Widget? action;
  final String artAsset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              artAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: AppColors.surfaceElevated),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xF20A090C), Color(0xB30A090C)],
                  stops: [0.1, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 14,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Expanded(
                      child: Text(
                        venueName.trim().isEmpty
                            ? 'Your restaurant'
                            : venueName.toUpperCase(),
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.gold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('Experiences', style: AppTextStyles.headlineLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 3,
                ),
                if (metrics.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      for (final metric in metrics)
                        _HeaderMetric(value: metric.value, label: metric.label),
                    ],
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTextStyles.numericMedium.copyWith(color: AppColors.textPrimary),
        ),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

/// One chip in a [ExperienceFilterRail].
class ExperienceFilterOption {
  const ExperienceFilterOption({
    required this.key,
    required this.label,
    this.count,
  });

  /// `null` is the "everything" chip; every other key is a wire status.
  final String? key;
  final String label;

  /// Omitted while the read behind it has not answered, so a chip never shows
  /// a zero it has not measured.
  final int? count;
}

/// The status rail shared by all three tabs.
class ExperienceFilterRail extends StatelessWidget {
  const ExperienceFilterRail({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<ExperienceFilterOption> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingScreen,
          vertical: AppSpacing.sm,
        ),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final option = options[index];
          return _FilterPill(
            option: option,
            selected: option.key == selected,
            onTap: () => onSelected(option.key),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ExperienceFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                option.label,
                style: AppTextStyles.labelMedium.copyWith(color: color),
              ),
              if (option.count != null) ...[
                const SizedBox(width: AppSpacing.xs + 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.22)
                        : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Text(
                    '${option.count}',
                    style: AppTextStyles.labelSmall.copyWith(color: color),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The card shell every experience surface shares.
class ExperienceCard extends StatelessWidget {
  const ExperienceCard({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A labelled icon fact on a card: when, how full, how much.
class ExperienceMetaRow extends StatelessWidget {
  const ExperienceMetaRow({
    super.key,
    required this.icon,
    required this.label,
    this.value = '',
    this.tone,
  });

  final IconData icon;
  final String label;

  /// Rendered after the label in the primary text colour; empty shows the
  /// label alone.
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: tone ?? AppColors.textTertiary),
          const SizedBox(width: AppSpacing.xs + 2),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (value.trim().isNotEmpty)
                    TextSpan(
                      text: '  $value',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seat fill as a thin bar plus a caption.
///
/// Capacity is the one number that tells a venue whether an evening is worth
/// running, so it reads as a proportion rather than a fraction buried in text.
class ExperienceFillBar extends StatelessWidget {
  const ExperienceFillBar({
    super.key,
    required this.booked,
    required this.total,
  });

  final int booked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (booked / total).clamp(0.0, 1.0);
    final left = (total - booked).clamp(0, total);
    final color = ratio >= 0.85
        ? AppColors.success
        : ratio >= 0.4
        ? AppColors.primary
        : AppColors.textTertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          total <= 0
              ? 'Seats not set'
              : '$booked of $total seats filled · $left left',
          style: AppTextStyles.caption,
          maxLines: 2,
        ),
      ],
    );
  }
}

/// The host's identity on a request or proposal card.
class ExperienceHostIdentity extends StatelessWidget {
  const ExperienceHostIdentity({
    super.key,
    required this.name,
    this.handle = '',
    this.avatarUrl = '',
    this.caption = '',
  });

  final String name;
  final String handle;
  final String avatarUrl;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final display = name.trim().isEmpty ? 'Host' : name.trim();
    final tag = handle.trim().isEmpty
        ? ''
        : '@${handle.trim().replaceFirst('@', '')}';
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderLight),
          ),
          clipBehavior: Clip.antiAlias,
          child: MediaImage(
            source: avatarUrl,
            fit: BoxFit.cover,
            fallbackIcon: Icons.person_outline,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display,
                style: AppTextStyles.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                [tag, caption].where((part) => part.isNotEmpty).join('  ·  '),
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A compact empty state that still says what to do next.
class ExperienceEmpty extends StatelessWidget {
  const ExperienceEmpty({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome_outlined,
    this.action,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: EmptyState(
        title: title,
        message: message,
        icon: icon,
        compact: true,
        action: action,
      ),
    );
  }
}

/// A feature the deployed server does not provide.
///
/// This is not an error state and not an empty state: the route is absent, so
/// the honest answer is to name the gap, quote what the API said, and keep the
/// retry beside it. Silently showing "no proposals" would claim the venue has
/// none, which is a different and wrong claim.
class ExperienceUnavailable extends StatelessWidget {
  const ExperienceUnavailable({
    super.key,
    required this.title,
    required this.message,
    this.detail = '',
    this.onRetry,
  });

  final String title;
  final String message;

  /// The server's own words, shown in a monospace-ish small block so the
  /// operator can quote it to whoever deploys the API.
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatusBanner(
          title: title,
          message: message,
          tone: BannerTone.warning,
          icon: Icons.extension_off_outlined,
          actionLabel: onRetry == null ? null : 'Check again',
          onAction: onRetry,
        ),
        if (detail.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              detail.trim(),
              style: AppTextStyles.caption.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
