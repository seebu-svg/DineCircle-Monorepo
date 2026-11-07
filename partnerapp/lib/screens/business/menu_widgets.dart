import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/money.dart';
import '../../widgets/media_image.dart';

/// Enhanced statistics grid showing menu overview metrics.
/// Displays: Total Sections, Total Items, Available, Sold Out, Missing Photos.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: 2 columns on narrow, 5 columns on wide
        final isCompact = constraints.maxWidth < 500;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _StatCard(
              icon: Icons.folder_outlined,
              label: 'Sections',
              value: '${sections.length}',
              color: AppColors.primary,
              flex: isCompact ? 0.48 : 0.19,
            ),
            _StatCard(
              icon: Icons.restaurant_menu,
              label: 'Total Items',
              value: '$_totalItems',
              color: AppColors.info,
              flex: isCompact ? 0.48 : 0.19,
            ),
            _StatCard(
              icon: Icons.check_circle_outline,
              label: 'Available',
              value: '$_availableItems',
              color: AppColors.success,
              flex: isCompact ? 0.31 : 0.19,
            ),
            _StatCard(
              icon: Icons.cancel_outlined,
              label: 'Sold Out',
              value: '$_soldOutItems',
              color: _soldOutItems > 0 ? AppColors.warning : AppColors.textTertiary,
              flex: isCompact ? 0.31 : 0.19,
              highlight: _soldOutItems > 0,
            ),
            _StatCard(
              icon: Icons.image_not_supported_outlined,
              label: 'No Photo',
              value: '$_missingPhotos',
              color: _missingPhotos > 0 ? AppColors.danger : AppColors.textTertiary,
              flex: isCompact ? 0.31 : 0.19,
              highlight: _missingPhotos > 0,
            ),
          ],
        );
      },
    );
  }
}

/// Individual statistic card with icon, value, and label.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.flex,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double flex;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: highlight ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: color.withValues(alpha: highlight ? 0.4 : 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const Spacer(),
                Text(
                  value,
                  style: AppTextStyles.numericMedium.copyWith(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
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

/// Enhanced horizontal scrollable chips for quick navigation to menu sections.
class SectionJumpChips extends StatefulWidget {
  const SectionJumpChips({
    super.key,
    required this.sections,
    required this.onJump,
  });

  final List<MenuSection> sections;
  final ValueChanged<String> onJump;

  @override
  State<SectionJumpChips> createState() => _SectionJumpChipsState();
}

class _SectionJumpChipsState extends State<SectionJumpChips> {
  String? _selectedSectionId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedSectionId = widget.sections.isNotEmpty ? widget.sections.first.id : null;
  }

  @override
  void didUpdateWidget(SectionJumpChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sections.isNotEmpty && 
        !widget.sections.any((s) => s.id == _selectedSectionId)) {
      _selectedSectionId = widget.sections.first.id;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onSectionTap(String sectionId) {
    setState(() => _selectedSectionId = sectionId);
    widget.onJump(sectionId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sections.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = widget.sections[index];
          final isSelected = _selectedSectionId == section.id;
          return InkWell(
            onTap: () => _onSectionTap(section.id),
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  Text(
                    section.name,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Text(
                      '${section.items.length}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced header with section name, item count, and controls.
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  // Section info
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      section.name,
                                      style: AppTextStyles.labelLarge.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!section.isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusPill,
                                        ),
                                        border: Border.all(
                                          color: AppColors.warning.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'Hidden',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.warning,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${section.items.length} ${section.items.length == 1 ? 'item' : 'items'} \u00b7 ${section.availableCount} available',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (v) => switch (v) {
                      'edit' => widget.onEditSection(),
                      'delete' => widget.onDeleteSection(),
                      'reorder' => widget.onReorderItems(),
                      _ => widget.onAddItem(),
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'add', child: Text('Add item')),
                      const PopupMenuItem(value: 'reorder', child: Text('Reorder items')),
                      const PopupMenuItem(value: 'edit', child: Text('Rename section')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete section',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                  // Expand/collapse icon
                  AnimatedBuilder(
                    animation: _expandAnimation,
                    builder: (context, _) => Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textTertiary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Collapsible content with improved spacing.
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                if (section.sortedItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                      horizontal: AppSpacing.md,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.restaurant_menu_outlined,
                          size: 40,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'No items in this section yet',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Tap the + button to add your first dish',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: widget.onAddItem,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      children: [
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
          ),
        ],
      ),
    );
  }
}

/// Enhanced dish row with larger food thumbnail (80px), name, description,
/// dietary tags, price in PKR, and availability toggle.
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Food thumbnail (80x80px as specified)
            _EnhancedPhotoThumb(photoUrl: item.photoUrl),
            const SizedBox(width: AppSpacing.md),
            // Name, description, dietary tags
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name with sold out badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!item.isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusPill,
                            ),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'Sold Out',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.danger,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Description
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Dietary tags
                  if (item.dietaryTags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final tag in item.dietaryTags)
                          _EnhancedDietaryTag(tag: tag),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Price and availability toggle
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatMoney(item.price, currency: 'PKR', decimals: 0),
                  style: AppTextStyles.numericMedium.copyWith(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 48,
                  height: 28,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Switch(
                      value: item.isAvailable,
                      onChanged: (v) => onToggle(v),
                      activeThumbColor: AppColors.success,
                      inactiveThumbColor: AppColors.textTertiary,
                      activeTrackColor: AppColors.success.withValues(alpha: 0.3),
                      inactiveTrackColor: AppColors.surfaceElevated,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced photo thumbnail (80x80px) with graceful placeholder.
class _EnhancedPhotoThumb extends StatelessWidget {
  const _EnhancedPhotoThumb({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: photoUrl.isEmpty
            ? Container(
                color: AppColors.surfaceElevated,
                child: Center(
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 32,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            : MediaImage(
                source: photoUrl,
                fallbackIcon: Icons.restaurant_menu,
              ),
      ),
    );
  }
}

/// Enhanced dietary tag badge with icon and better styling.
class _EnhancedDietaryTag extends StatelessWidget {
  const _EnhancedDietaryTag({required this.tag});

  final String tag;

  IconData _iconForTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'vegetarian':
        return Icons.eco;
      case 'vegan':
        return Icons.park;
      case 'spicy':
        return Icons.local_fire_department;
      case 'gluten-free':
        return Icons.grain_outlined;
      case 'contains nuts':
        return Icons.ac_unit;
      case 'dairy-free':
        return Icons.cookie_outlined;
      case 'halal':
        return Icons.verified_user;
      case 'seafood':
        return Icons.set_meal;
      default:
        return Icons.label;
    }
  }

  Color _colorForTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'vegetarian':
        return AppColors.success;
      case 'vegan':
        return AppColors.success;
      case 'spicy':
        return AppColors.danger;
      case 'gluten-free':
        return AppColors.info;
      case 'contains nuts':
        return AppColors.warning;
      case 'dairy-free':
        return AppColors.info;
      case 'halal':
        return AppColors.primary;
      case 'seafood':
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForTag(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForTag(tag),
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            tag,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
