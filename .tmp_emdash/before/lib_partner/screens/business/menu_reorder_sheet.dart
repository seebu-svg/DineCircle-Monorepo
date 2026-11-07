import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalog.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/money.dart';
import '../../widgets/media_image.dart';
import '../../widgets/role_gate_builder.dart';

/// Shows a reorder sheet for either top-level sections or one section's items.
///
/// Commits only the positions that actually changed, so a partner who opens
/// and closes without dragging issues zero PATCHes.
Future<void> showReorderSheet(
  BuildContext context, {
  required String venueId,
  required ReorderMode mode,
  List<MenuSection>? sections,
  MenuSection? section,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReorderSheet(
      venueId: venueId,
      mode: mode,
      sections: sections ?? const [],
      section: section,
    ),
  );
}

enum ReorderMode { sections, items }

class _ReorderSheet extends ConsumerStatefulWidget {
  const _ReorderSheet({
    required this.venueId,
    required this.mode,
    required this.sections,
    this.section,
  });

  final String venueId;
  final ReorderMode mode;
  final List<MenuSection> sections;
  final MenuSection? section;

  @override
  ConsumerState<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends ConsumerState<_ReorderSheet> {
  late List<MenuSection> _sections;
  late List<MenuItem> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _sections = [...widget.sections]
      ..sort((a, b) => a.position.compareTo(b.position));
    if (widget.section != null) {
      _items = [...widget.section!.items]
        ..sort((a, b) => a.position.compareTo(b.position));
    }
  }

  Future<void> _commit() async {
    setState(() => _busy = true);
    final repo = ref.read(menuRepositoryProvider);
    try {
      if (widget.mode == ReorderMode.sections) {
        await repo.reorderSections(widget.venueId, _sections);
      } else {
        await repo.reorderItems(widget.venueId, _items);
      }
      ref.invalidate(menuProvider(widget.venueId));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not reorder:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSections = widget.mode == ReorderMode.sections;
    final title = isSections ? 'Reorder sections' : 'Reorder dishes';
    final subtitle = isSections
        ? 'Drag to set the order guests see on the menu.'
        : 'Drag to set the order within ${widget.section?.name ?? 'this section'}.';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
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
              // List.
              Expanded(
                child: isSections
                    ? ReorderableListView.builder(
                        scrollController: scrollController,
                        padding: const EdgeInsets.all(AppSpacing.paddingScreen),
                        itemCount: _sections.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final item = _sections.removeAt(oldIndex);
                            _sections.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final section = _sections[index];
                          return _ReorderTile(
                            key: ValueKey(section.id),
                            index: index,
                            title: section.name,
                            subtitle:
                                '${section.items.length} dishes · ${section.isActive ? 'Visible' : 'Hidden'}',
                            trailing: const Icon(Icons.drag_handle),
                          );
                        },
                      )
                    : ReorderableListView.builder(
                        scrollController: scrollController,
                        padding: const EdgeInsets.all(AppSpacing.paddingScreen),
                        itemCount: _items.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final item = _items.removeAt(oldIndex);
                            _items.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _ReorderTile(
                            key: ValueKey(item.id),
                            index: index,
                            title: item.name,
                            subtitle:
                                '${formatMoney(item.price, currency: 'PKR', decimals: 0)} · ${item.isAvailable ? 'Available' : 'Sold out'}',
                            photoUrl: item.photoUrl,
                            trailing: const Icon(Icons.drag_handle),
                          );
                        },
                      ),
              ),
              // Commit button.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.paddingScreen,
                  AppSpacing.md,
                  AppSpacing.paddingScreen,
                  AppSpacing.lg,
                ),
                child: FilledButton(
                  onPressed: _busy ? null : _commit,
                  child: Text(_busy ? 'Saving…' : 'Save order'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReorderTile extends StatelessWidget {
  const _ReorderTile({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.photoUrl,
  });

  final int index;
  final String title;
  final String subtitle;
  final Widget trailing;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Position badge.
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (photoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: SizedBox(
                width: 40,
                height: 40,
                child: MediaImage(
                  source: photoUrl!,
                  fallbackIcon: Icons.restaurant_menu,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
