
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/deals.dart';
import '../../models/venue.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../services/qr_studio_export.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/links.dart';
import '../../widgets/async_views.dart';
import '../../widgets/qr_studio_card.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

class QrTab extends ConsumerStatefulWidget {
  const QrTab({super.key});

  @override
  ConsumerState<QrTab> createState() => _QrTabState();
}

class _QrTabState extends ConsumerState<QrTab> {
  final GlobalKey _cardKey = GlobalKey();

  QrCardStyle _style = QrCardStyle.classicIvory;
  bool _busy = false;
  bool _showDeals = false;

  Future<void> _openPage(String link) async {
    try {
      final opened = await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        showToast(
          context,
          'No browser could open that link.',
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        reportError(
          context,
          error,
          prefix: 'Could not open the page:',
        );
      }
    }
  }

  Future<void> _export(
    Venue venue, {
    bool pdf = false,
    bool share = false,
  }) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      if (_style != QrCardStyle.minimalWhite &&
          venue.coverImage.trim().isNotEmpty) {
        await precacheImage(
          NetworkImage(venue.coverImage),
          context,
          onError: (_, _) {},
        ).timeout(const Duration(seconds: 20));
      }

      if (!mounted) return;

      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) return;

      final renderObject =
          _cardKey.currentContext?.findRenderObject();

      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('QR preview is not ready.');
      }

      if (renderObject.size.width <= 0) {
        throw StateError('QR preview has an invalid size.');
      }

      final image = await renderObject.toImage(
        pixelRatio: 1500 / renderObject.size.width,
      );

      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (data == null) {
          throw StateError('Could not render the QR card.');
        }

        final outcome = await QrStudioExport.send(
          png: data.buffer.asUint8List(),
          filename:
              'dinecircle-qr-${venue.id.replaceAll(RegExp(r"[^a-zA-Z0-9_-]"), "")}',
          pdf: pdf,
          share: share,
        );

        if (mounted && outcome == 'saved') {
          showToast(
            context,
            '${pdf ? "PDF" : "PNG"} saved successfully.',
          );
        }
      } finally {
        image.dispose();
      }
    } catch (error) {
      if (mounted) {
        reportError(
          context,
          error,
          prefix: 'Could not export QR card:',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(selectedVenueProvider);

    if (venue == null) {
      final scope = ref.watch(venueScopeProvider);

      if (scope.isLoading) {
        return const SingleChildScrollView(
          child: LoadingSkeleton(
            count: 2,
            itemHeight: 150,
          ),
        );
      }

      final error = scope.error ??
          (scope.valueOrNull?.loadError.isNotEmpty == true
              ? StateError(scope.valueOrNull!.loadError)
              : null);

      if (error != null) {
        return ErrorView(
          error: error,
          onRetry: () => ref.invalidate(venueScopeProvider),
        );
      }

      return const EmptyState(
        title: 'Your restaurant QR',
        message:
            'Complete your restaurant profile in Business '
            'to create your branded QR card.',
        icon: Icons.storefront_outlined,
      );
    }

    final link = venuePublicUrl(venue.id);

    final exportEnabled =
        QrStudioExport.supported && link.isNotEmpty && !_busy;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final padding = compact ? 16.0 : 20.0;

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              padding,
              16,
              padding,
              36,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 720,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QrHeader(venue: venue),

                    const SizedBox(height: 20),

                    if (!venue.verified) ...[
                      const StatusBanner(
                        title: 'Not public yet',
                        message:
                            'Your restaurant is awaiting verification. '
                            'Preview your QR card now and confirm '
                            'the guest page is live before printing.',
                        tone: BannerTone.warning,
                        icon: Icons.verified_user_outlined,
                      ),
                      const SizedBox(height: 16),
                    ],

                    _QrPreviewPanel(
                      cardKey: _cardKey,
                      venue: venue,
                      style: _style,
                    ),

                    const SizedBox(height: 16),

                    _QrActions(
                      enabled: exportEnabled,
                      canPreview: link.isNotEmpty,
                      busy: _busy,
                      onPng: () => _export(venue),
                      onPdf: () => _export(venue, pdf: true),
                      onShare: () => _export(venue, share: true),
                      onPreview: () => _openPage(link),
                    ),

                    const SizedBox(height: 26),

                    _SectionHeading(
                      title: 'Customize your QR',
                      subtitle:
                          'Choose a card style that matches your brand.',
                    ),

                    const SizedBox(height: 12),

                    _QrStyleSelector(
                      selected: _style,
                      enabled: !_busy,
                      onChanged: (style) {
                        setState(() => _style = style);
                      },
                    ),

                    const SizedBox(height: 14),

                    const _PrintNotice(),

                    const SizedBox(height: 26),

                    _SectionHeading(
                      title: 'Restaurant Link',
                      subtitle:
                          'Share your digital restaurant page anywhere.',
                    ),

                    const SizedBox(height: 12),

                    _VenueLinkCard(
                      link: link,
                      onPreview: link.isNotEmpty
                          ? () => _openPage(link)
                          : null,
                    ),

                    const SizedBox(height: 26),

                    _SectionHeading(
                      title: 'Promotional Codes',
                      subtitle:
                          'View active deals and copy their promo codes.',
                    ),

                    const SizedBox(height: 12),

                    _DealsPanel(
                      expanded: _showDeals,
                      onExpansionChanged: (value) {
                        setState(() => _showDeals = value);
                      },
                      venueId: venue.id,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QrHeader extends StatelessWidget {
  const _QrHeader({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digital QR Studio',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your restaurant, one scan away.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                venue.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.qr_code_2_rounded,
            color: AppColors.primary,
            size: 27,
          ),
        ),
      ],
    );
  }
}

class _QrPreviewPanel extends StatelessWidget {
  const _QrPreviewPanel({
    required this.cardKey,
    required this.venue,
    required this.style,
  });

  final GlobalKey cardKey;
  final Venue venue;
  final QrCardStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LIVE CARD PREVIEW',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420,
              ),
              child: RepaintBoundary(
                key: cardKey,
                child: QrStudioCard(
                  venue: venue,
                  style: style,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ready for tables, counters and printed displays',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QrActions extends StatelessWidget {
  const _QrActions({
    required this.enabled,
    required this.canPreview,
    required this.busy,
    required this.onPng,
    required this.onPdf,
    required this.onShare,
    required this.onPreview,
  });

  final bool enabled;
  final bool canPreview;
  final bool busy;
  final VoidCallback onPng;
  final VoidCallback onPdf;
  final VoidCallback onShare;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: MenuAnchor(
            menuChildren: [
              MenuItemButton(
                onPressed: enabled ? onPng : null,
                leadingIcon:
                    const Icon(Icons.image_outlined),
                child: const Text('Download PNG'),
              ),
              MenuItemButton(
                onPressed: enabled ? onPdf : null,
                leadingIcon:
                    const Icon(Icons.picture_as_pdf_outlined),
                child: const Text('Download PDF'),
              ),
            ],
            builder: (context, controller, _) {
              return FilledButton.icon(
                onPressed: enabled
                    ? () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      }
                    : null,
                icon: busy
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  busy ? 'Preparing QR card...' : 'Download QR Card',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? onShare : null,
                icon: const Icon(
                  Icons.ios_share_outlined,
                  size: 18,
                ),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canPreview ? onPreview : null,
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: 18,
                ),
                label: const Text('Preview'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ],
        ),
        if (!QrStudioExport.supported) ...[
          const SizedBox(height: 10),
          Text(
            'Downloads and native sharing are available '
            'in the Android and iOS app.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _QrStyleSelector extends StatelessWidget {
  const _QrStyleSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final QrCardStyle selected;
  final bool enabled;
  final ValueChanged<QrCardStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final style in QrCardStyle.values)
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: ChoiceChip(
                selected: selected == style,
                showCheckmark: false,
                onSelected:
                    enabled ? (_) => onChanged(style) : null,
                avatar: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: style.background,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),
                ),
                label: Text(style.label),
                selectedColor:
                    AppColors.primary.withValues(alpha: 0.13),
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: selected == style
                      ? AppColors.primary
                      : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: AppTextStyles.labelSmall.copyWith(
                  color: selected == style
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: selected == style
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrintNotice extends StatelessWidget {
  const _PrintNotice();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.print_outlined,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Print ready: PNG exports at 1500px wide. '
              'PDF uses a 105mm page with 5mm margins. '
              'Print at actual size for the best result.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VenueLinkCard extends StatelessWidget {
  const _VenueLinkCard({
    required this.link,
    required this.onPreview,
  });

  final String link;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.link_rounded,
                color: AppColors.primary,
                size: 21,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Public restaurant page',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.border),
            ),
            child: SelectableText(
              link.isEmpty ? 'Link unavailable' : link,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: link.isNotEmpty
                    ? () => copyToClipboard(
                          context,
                          link,
                          'Venue link',
                        )
                    : null,
                icon: const Icon(
                  Icons.copy_rounded,
                  size: 17,
                ),
                label: const Text('Copy Link'),
              ),
              TextButton.icon(
                onPressed: onPreview,
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: 17,
                ),
                label: const Text('Open Page'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DealsPanel extends StatelessWidget {
  const _DealsPanel({
    required this.expanded,
    required this.onExpansionChanged,
    required this.venueId,
  });

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final String venueId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        onExpansionChanged: onExpansionChanged,
        leading: const Icon(
          Icons.local_offer_outlined,
          color: AppColors.primary,
        ),
        title: Text(
          'Live Deal Codes',
          style: AppTextStyles.titleSmall,
        ),
        subtitle: Text(
          'Published promotions · Read only',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          14,
          0,
          14,
          14,
        ),
        children: [
          if (expanded) _DealCodes(venueId: venueId),
        ],
      ),
    );
  }
}

class _DealCodes extends ConsumerWidget {
  const _DealCodes({required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = dealsProvider(
      (venue: venueId, status: 'active'),
    );

    final deals = ref.watch(provider);

    return AsyncView<List<Deal>>(
      value: deals,
      onRetry: () => ref.invalidate(provider),
      emptyState: const EmptyState(
        compact: true,
        title: 'No live deals',
        message: 'Manage promotions in Business > Deals.',
        icon: Icons.local_offer_outlined,
      ),
      builder: (context, rows) {
        final live = rows.where((deal) => deal.isLive).toList();

        if (live.isEmpty) {
          return const EmptyState(
            compact: true,
            title: 'No live deals',
            message:
                'Scheduled promotions appear when they start.',
          );
        }

        return Column(
          children: [
            for (final deal in live)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DealCodeTile(deal: deal),
              ),
          ],
        );
      },
    );
  }
}

class _DealCodeTile extends StatelessWidget {
  const _DealCodeTile({required this.deal});

  final Deal deal;

  @override
  Widget build(BuildContext context) {
    final code = deal.code?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.sell_outlined,
              color: AppColors.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deal.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deal.valueLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  code.isEmpty
                      ? 'No promo code set'
                      : code,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: code.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: code.isEmpty ? 0 : 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (code.isNotEmpty)
            IconButton(
              tooltip: 'Copy ${deal.title} code',
              onPressed: () => copyToClipboard(
                context,
                code,
                '${deal.title} code',
              ),
              icon: const Icon(
                Icons.copy_all_outlined,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
