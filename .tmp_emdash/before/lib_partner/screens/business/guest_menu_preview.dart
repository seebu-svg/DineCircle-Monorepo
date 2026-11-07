import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalog.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/links.dart';
import '../../widgets/brand.dart';
import '../../widgets/media_image.dart';
import '../../widgets/premium_cards.dart';
import '../../widgets/premium_feedback.dart';
import '../../widgets/qr_code_view.dart';
import '../../utils/money.dart';

/// A bottom sheet that fetches the *public* menu payload (the same one guests
/// see after scanning the QR code) and renders it verbatim. This proves the
/// server-side filtering of inactive sections and unavailable items rather
/// than approximating it from the partner's local data.
///
/// Falls back to the supplied local [sections] when the public fetch fails,
/// with an inline notice so the partner knows the preview is stale.
class GuestMenuPreviewSheet extends ConsumerStatefulWidget {
  const GuestMenuPreviewSheet({
    super.key,
    required this.venueId,
    required this.sections,
  });

  final String venueId;
  final List<MenuSection> sections;

  @override
  ConsumerState<GuestMenuPreviewSheet> createState() =>
      _GuestMenuPreviewSheetState();
}

class _GuestMenuPreviewSheetState extends ConsumerState<GuestMenuPreviewSheet> {
  late Future<_PreviewData> _future;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PreviewData> _load() async {
    try {
      final publicMenu =
          await ref.read(menuRepositoryProvider).publicMenu(widget.venueId);
      return _PreviewData(
        restaurantName: publicMenu.restaurant.name,
        restaurantCity: publicMenu.restaurant.city,
        sections: publicMenu.sections,
        fromPublicApi: true,
      );
    } catch (_) {
      return _PreviewData(
        restaurantName: '',
        restaurantCity: '',
        sections: widget.sections,
        fromPublicApi: false,
      );
    }
  }

  void _copyLink() {
    final link = venuePublicUrl(widget.venueId);
    if (link.isEmpty) return;
    Clipboard.setData(ClipboardData(text: link));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final link = venuePublicUrl(widget.venueId);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusSheet),
            ),
          ),
          child: Column(
            children: [
              // Handle bar.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.paddingScreen,
                  0,
                  AppSpacing.paddingScreen,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const BrandBadge(height: 32),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GUEST MENU PREVIEW',
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'What guests see when they scan the QR',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              // Scrollable content.
              Expanded(
                child: FutureBuilder<_PreviewData>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snap.data ??
                        _PreviewData(
                          restaurantName: '',
                          restaurantCity: '',
                          sections: widget.sections,
                          fromPublicApi: false,
                        );
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.paddingScreen),
                      children: [
                        // Live status pill.
                        _LiveStatusPill(fromPublicApi: data.fromPublicApi),
                        const SizedBox(height: AppSpacing.md),
                        // QR code card.
                        PremiumCard(
                          child: Column(
                            children: [
                              Text(
                                'SCAN TO VIEW MENU',
                                style: AppTextStyles.overline.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              QrCodeView(data: link, size: 180),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                link.isEmpty
                                    ? 'No venue link available'
                                    : link,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                alignment: WrapAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: link.isEmpty ? null : _copyLink,
                                    icon: Icon(
                                      _copied ? Icons.check : Icons.copy,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _copied ? 'Copied!' : 'Copy link',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: link.isEmpty ? null : _copyLink,
                                    icon: const Icon(
                                      Icons.ios_share_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Share menu'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Restaurant header (from public payload).
                        if (data.restaurantName.isNotEmpty) ...[
                          Text(
                            data.restaurantName.toUpperCase(),
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          if (data.restaurantCity.isNotEmpty)
                            Text(
                              data.restaurantCity,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        // Menu sections.
                        if (data.sections.isEmpty)
                          const InlineNotice(
                            message:
                                'No menu sections yet. Add dishes to see them here.',
                            kind: InlineNoticeKind.info,
                            icon: Icons.info_outline,
                          )
                        else
                          for (final section in data.sections) ...[
                            if (section.isActive) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                child: Text(
                                  section.name.toUpperCase(),
                                  style: AppTextStyles.overline.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              for (final item in section.sortedItems)
                                if (item.isAvailable)
                                  _GuestDishRow(item: item),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          ],
                        const NotTrackedTile(
                          metric: 'Modifiers and featured items',
                          reason:
                              'The DineCircle platform does not currently expose '
                              'modifiers or featured-item flags to partners. These '
                              'are managed on the guest app side.',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PreviewData {
  const _PreviewData({
    required this.restaurantName,
    required this.restaurantCity,
    required this.sections,
    required this.fromPublicApi,
  });

  final String restaurantName;
  final String restaurantCity;
  final List<MenuSection> sections;
  final bool fromPublicApi;
}

class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill({required this.fromPublicApi});

  final bool fromPublicApi;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: fromPublicApi
              ? AppColors.success.withValues(alpha: 0.12)
              : AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: fromPublicApi
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.warning.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fromPublicApi ? AppColors.success : AppColors.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                fromPublicApi
                    ? 'Live in Customer App'
                    : 'Showing saved menu. Live preview unavailable',
                style: AppTextStyles.labelSmall.copyWith(
                  color: fromPublicApi ? AppColors.success : AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single dish row in the guest preview (read-only, no toggle).
class _GuestDishRow extends StatelessWidget {
  const _GuestDishRow({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: SizedBox(
              width: 48,
              height: 48,
              child: MediaImage(
                source: item.photoUrl,
                fallbackIcon: Icons.restaurant_menu,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.dietaryTags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final tag in item.dietaryTags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusPill,
                            ),
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            tag.toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.info,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            formatMoney(item.price, currency: 'PKR', decimals: 0),
            style: AppTextStyles.numericMedium.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
