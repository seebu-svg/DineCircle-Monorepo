import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/money.dart';
import '../../widgets/media_image.dart';
import '../../widgets/premium_cards.dart';
import '../../widgets/premium_feedback.dart';

/// Summary strip showing menu statistics: sections, items, available, sold out,
/// and missing photos.
class MenuSummaryStrip extends StatelessWidget {
  const MenuSummaryStrip({
    super.key,
    required this.sections,
  });

  final List<MenuSection> sections;

  int get _totalItems => sections.fold(0, (sum, s) => sum + s.items.length);
  int get _availableItems =>
      sections.fold(0, (sum, s) => sum + s.availableCount);
  int get _soldOutItems => _totalItems - _availableItems;
  int get _missingPhotos => sections.fold(
        0,
        (sum, s) => sum + s.items.where((i) => i.photoUrl.isEmpty).length,
      );

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          _StatChip(
            label: 'Sections',
            value: '${sections.length}',
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatChip(
            label: 'Items',
            value: '$_totalItems',
            color: AppColors.info,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatChip(
            label: 'Available',
            value: '$_availableItems',
            color: AppColors.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatChip(
            label: 'Sold out',
            value: '$_soldOutItems',
            color: _soldOutItems > 0 ? AppColors.warning : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatChip(
            label: 'No photo',
            value: '$_missingPhotos',
            color: _missingPhotos > 0 ? AppColors.danger : AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.numericMedium.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable chips for quick navigation to menu sections.
class SectionJumpChips extends StatelessWidget {
  const SectionJumpChips({
    super.key,
    required this.sections,
    required this.onJump,
  });

  final List<MenuSection> sections;
  final ValueChanged<String> onJump;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final section = sections[index];
          return ActionChip(
            label: Text(section.name),
            onPressed: () => onJump(section.id),
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            labelStyle: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          );
        },
      ),
    );
  }
}

/// A collapsible section card with premium styling.
class CollapsibleSectionCard extends StatefulWidget {
  const CollapsibleSectionCard({
    super.key,
    required this.section,
    required this.onEditSection,
    required this.onDeleteSection,
    required this.onAddItem,
    required this.onReorderItems,
    required this.onEditItem,
    required this.onDeleteItem,
    required this.onToggleItem,
    this.initiallyExpanded = true,
  });

  final MenuSection section;
  final VoidCallback onEditSection;
  final VoidCallback onDeleteSection;
  final VoidCallback onAddItem;
  final VoidCallback onReorderItems;
  final void Function(MenuItem item) onEditItem;
  final void Function(MenuItem item) onDeleteItem;
  final void Function(MenuItem item, bool available) onToggleItem;
  final bool initiallyExpanded;

  @override
  State<CollapsibleSectionCard> createState() => _CollapsibleSectionCardState();
}

class _CollapsibleSectionCardState extends State<CollapsibleSectionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: _isExpanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with section name and expand/collapse toggle.
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              section.name.toUpperCase(),
                              style: AppTextStyles.overline.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            if (!section.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusPill,
                                  ),
                                ),
                                child: Text(
                                  'HIDDEN',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.warning,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${section.availableCount} of ${section.items.length} available',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) => switch (v) {
                      'edit' => widget.onEditSection(),
                      'delete' => widget.onDeleteSection(),
                      'reorder' => widget.onReorderItems(),
                      _ => widget.onAddItem(),
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'add', child: Text('Add dish')),
                      PopupMenuItem(value: 'edit', child: Text('Rename section')),
                      PopupMenuItem(
                        value: 'reorder',
                        child: Text('Reorder dishes'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete section')),
                    ],
                  ),
                  AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, _) => Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Collapsible content.
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                if (section.sortedItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: InlineNotice(
                      message: 'No dishes yet. Tap + to add one.',
                      kind: InlineNoticeKind.info,
                      icon: Icons.info_outline,
                    ),
                  ),
                for (var i = 0; i < section.sortedItems.length; i++)
                  _DishRow(
                    index: i,
                    item: section.sortedItems[i],
                    onEdit: () => widget.onEditItem(section.sortedItems[i]),
                    onDelete: () => widget.onDeleteItem(section.sortedItems[i]),
                    onToggle: (available) =>
                        widget.onToggleItem(section.sortedItems[i], available),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single dish row with photo thumb, name, price, dietary pills, and
/// sold-out switch.
class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final int index;
  final MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool available) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, color: AppColors.border),
        InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Position badge.
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                // Photo thumb or placeholder.
                _PhotoThumb(photoUrl: item.photoUrl),
                const SizedBox(width: AppSpacing.sm),
                // Name, description, dietary tags.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!item.isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusPill,
                                ),
                              ),
                              child: Text(
                                'SOLD OUT',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.danger,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
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
                                  tag,
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
                // Price and availability toggle.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(item.price, currency: 'PKR', decimals: 0),
                      style: AppTextStyles.numericMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: item.isAvailable,
                        onChanged: (v) => onToggle(v),
                        activeThumbColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Photo thumbnail with graceful placeholder for missing images.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: SizedBox(
        width: 56,
        height: 56,
        child: MediaImage(
          source: photoUrl,
          fallbackIcon: Icons.restaurant_menu,
        ),
      ),
    );
  }
}
