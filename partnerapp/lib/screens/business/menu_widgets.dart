import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../models/venue.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/money.dart';
import '../../widgets/media_image.dart';

/// ─── Publish state ─────────────────────────────────────────────────────────

/// Whether the menu is actually visible to guests right now.
///
/// The platform has no staged menu, so "live" is not a flag to flip: it is the
/// fact that the public route can serve at least one dish. A menu of hidden
/// categories, or one where every dish is 86ed, is not live for a guest even
/// though the partner's own rows all exist, so the screen says Draft.
enum MenuPublishState { live, draft }

/// The Live/Draft pill in the menu header.
class MenuStatusPill extends StatelessWidget {
  const MenuStatusPill({super.key, required this.state});

  final MenuPublishState state;

  @override
  Widget build(BuildContext context) {
    final live = state == MenuPublishState.live;
    final color = live ? AppColors.success : AppColors.warning;
    return Semantics(
      label: live
          ? 'Menu is live for guests'
          : 'Menu is not visible to guests yet',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 5),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                live ? 'Live' : 'Draft',
                style: AppTextStyles.labelSmall.copyWith(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Header ────────────────────────────────────────────────────────────────

/// The compact identity block at the top of Menu Management.
///
/// It answers three questions in one card: whose menu this is, whether guests
/// can see it, and how much of it is sellable right now. The counts are folded
/// from the live section list the screen already holds, so the header cannot
/// drift from what the server has.
///
/// It replaced a title row plus five separate statistic cards. Those cards spent
/// a third of a phone screen repeating numbers that are already on the rows
/// below, and their labels truncated to "Sectio…" and "Availa…" on a narrow
/// device.
class MenuHeaderCard extends StatelessWidget {
  const MenuHeaderCard({
    super.key,
    required this.venue,
    required this.name,
    required this.identity,
    required this.sections,
    required this.state,
    required this.statusDetail,
    required this.availability,
    required this.onFilter,
  });

  final Venue? venue;

  /// The venue name, already resolved to the record the session is editing.
  final String name;

  /// "Seafood · Karachi", whichever of those the venue actually has.
  final String identity;

  final List<MenuSection> sections;
  final MenuPublishState state;

  /// Why the pill reads this way, shown only while the menu is a draft.
  final String statusDetail;

  /// The availability filter currently narrowing the list, so the count pills
  /// can double as the control that set it.
  final MenuAvailabilityFilter availability;
  final ValueChanged<MenuAvailabilityFilter> onFilter;

  int get _items => sections.fold(0, (sum, s) => sum + s.items.length);
  int get _available => sections.fold(0, (sum, s) => sum + s.availableCount);
  int get _soldOut => _items - _available;
  int get _missingPhotos => sections.fold(
    0,
    (sum, s) => sum + s.items.where((i) => i.photoUrl.isEmpty).length,
  );

  /// A tap applies the filter the pill counts, and a second tap clears it, so
  /// "3 sold out" is both the answer and the way into it.
  void _toggle(MenuAvailabilityFilter filter) =>
      onFilter(availability == filter ? MenuAvailabilityFilter.all : filter);

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[
      MenuStatusPill(state: state),
      _CountPill(
        icon: Icons.restaurant_menu,
        label: '$_items ${_items == 1 ? 'dish' : 'dishes'}',
        color: AppColors.textSecondary,
      ),
      _CountPill(
        icon: Icons.check_circle_outline,
        label: '$_available available',
        color: AppColors.success,
        selected: availability == MenuAvailabilityFilter.available,
        onTap: () => _toggle(MenuAvailabilityFilter.available),
      ),
      if (_soldOut > 0)
        _CountPill(
          icon: Icons.cancel_outlined,
          label: '$_soldOut sold out',
          color: AppColors.warning,
          selected: availability == MenuAvailabilityFilter.soldOut,
          onTap: () => _toggle(MenuAvailabilityFilter.soldOut),
        ),
      if (_missingPhotos > 0)
        _CountPill(
          icon: Icons.image_not_supported_outlined,
          label: '$_missingPhotos no photo',
          color: AppColors.danger,
          selected: availability == MenuAvailabilityFilter.missingPhoto,
          onTap: () => _toggle(MenuAvailabilityFilter.missingPhoto),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _venueTile(),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Menu Management',
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      name,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (identity.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        identity,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: pills,
          ),
          if (state == MenuPublishState.draft) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.info_outline,
                    size: 13,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusDetail,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The venue logo, or its cover, or the storefront fallback.
  Widget _venueTile() {
    final logo = (venue?.logo ?? '').trim();
    final cover = (venue?.coverImage ?? '').trim();
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
        border: Border.all(color: AppColors.border),
      ),
      child: MediaImage(
        source: logo.isNotEmpty ? logo : cover,
        fallbackIcon: Icons.storefront,
      ),
    );
  }
}

/// A borderless count pill. Tappable pills get [onTap]; decorative ones stay
/// inert so a number can never look like a button it is not.
class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          child: content,
        ),
      ),
    );
  }
}

/// ─── Primary actions ───────────────────────────────────────────────────────

/// One prominent primary action and one quiet secondary.
///
/// *Add dish* owns the row because every other action on this screen exists to
/// look at what it produces. The category menu is an icon button rather than a
/// second filled button: two labelled buttons sharing a 360dp phone is how
/// "Preview" once rendered as "Previe/w".
///
/// There is no separate guest-menu preview here: the partner prints one QR
/// code, and scanning it opens the restaurant page with the live menu inside.
class MenuActionBar extends StatelessWidget {
  const MenuActionBar({
    super.key,
    required this.canEdit,
    required this.canReorderSections,
    required this.onAddItem,
    required this.onAddCategory,
    required this.onReorderSections,
  });

  final bool canEdit;
  final bool canReorderSections;
  final VoidCallback onAddItem;
  final VoidCallback onAddCategory;
  final VoidCallback onReorderSections;

  @override
  Widget build(BuildContext context) {
    // Past ~1.6x the label no longer fits beside the icon on a phone, and an
    // ellipsised verb ("Add i…") is worse than the short one.
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return Row(
      children: [
        Expanded(
          child: _PrimaryAction(
            actionKey: const ValueKey('menu-add'),
            icon: Icons.add,
            label: large ? 'Add' : 'Add dish',
            onPressed: canEdit ? onAddItem : null,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        PopupMenuButton<String>(
          key: const ValueKey('menu-category-actions'),
          tooltip: 'Category actions',
          icon: const Icon(Icons.more_horiz, size: 21),
          color: AppColors.surfaceElevated,
          onSelected: (value) => switch (value) {
            'reorder' => onReorderSections(),
            _ => onAddCategory(),
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'add', child: Text('New category')),
            PopupMenuItem(
              value: 'reorder',
              enabled: canEdit && canReorderSections,
              child: const Text('Reorder categories'),
            ),
          ],
        ),
      ],
    );
  }
}

/// The filled action: a rounded orange button that grows with the text scale
/// instead of clipping its own label.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: actionKey,
      constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceHigh,
          disabledForegroundColor: AppColors.textTertiary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Search and filtering ──────────────────────────────────────────────────

/// The search field and the one filter that narrows availability.
///
/// Category filtering is not here: the rail below is the category control, and
/// two ways to pick a category in the same 80dp was duplicated chrome.
class MenuSearchRow extends StatelessWidget {
  const MenuSearchRow({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.availability,
    required this.onAvailabilityChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final MenuAvailabilityFilter availability;
  final ValueChanged<MenuAvailabilityFilter> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final active = availability != MenuAvailabilityFilter.all;
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('menu-search'),
            controller: searchController,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.surface,
              hintText: 'Search dishes',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textTertiary,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 19,
                color: AppColors.textTertiary,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: AppSpacing.minTapTarget,
                minHeight: AppSpacing.minTapTarget,
              ),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 17),
                      color: AppColors.textTertiary,
                      tooltip: 'Clear search',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PopupMenuButton<MenuAvailabilityFilter>(
          key: const ValueKey('menu-filter'),
          tooltip: active ? 'Filter: ${availability.label}' : 'Filter dishes',
          initialValue: availability,
          onSelected: onAvailabilityChanged,
          offset: const Offset(0, 48),
          color: AppColors.surfaceElevated,
          itemBuilder: (context) => [
            for (final filter in MenuAvailabilityFilter.values)
              PopupMenuItem<MenuAvailabilityFilter>(
                key: ValueKey('menu-filter-${filter.name}'),
                value: filter,
                child: Row(
                  children: [
                    Icon(
                      filter == availability
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 16,
                      color: filter == availability
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(filter.label),
                  ],
                ),
              ),
          ],
          child: Container(
            width: AppSpacing.minTapTarget,
            height: AppSpacing.minTapTarget,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: active
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Icon(
              active ? Icons.filter_alt : Icons.filter_alt_outlined,
              size: 20,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// "3 sold out · 3 of 24 dishes", with the one tap that undoes the filter.
class MenuFilterSummary extends StatelessWidget {
  const MenuFilterSummary({
    super.key,
    required this.caption,
    required this.onClear,
  });

  final String caption;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            caption,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: onClear,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

/// ─── Category rail ─────────────────────────────────────────────────────────

/// The categories, as a horizontal rail of selectable chips.
///
/// Selecting one is how the screen avoids the old continuous page of every
/// category expanded at once: the list below shows that category's dishes and
/// nothing else. `All` stays first for the partner who wants the whole menu.
class MenuCategoryRail extends StatelessWidget {
  const MenuCategoryRail({
    super.key,
    required this.sections,
    required this.selectedId,
    required this.totalItems,
    required this.onSelect,
  });

  final List<MenuSection> sections;

  /// Null means the *All* chip.
  final String? selectedId;
  final int totalItems;
  final void Function(String? sectionId) onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingScreen),
      child: Row(
        children: [
          MenuCategoryChip(
            key: const ValueKey('menu-cat-all'),
            label: 'All',
            count: totalItems,
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          for (final section in sections) ...[
            const SizedBox(width: AppSpacing.sm),
            MenuCategoryChip(
              key: ValueKey('menu-cat-${section.id}'),
              label: section.name,
              count: section.items.length,
              hidden: !section.isActive,
              selected: selectedId == section.id,
              onTap: () => onSelect(section.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// One category chip: name, dish count, and a warning mark when the category is
/// hidden from guests.
class MenuCategoryChip extends StatelessWidget {
  const MenuCategoryChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.hidden = false,
  });

  final String label;
  final int count;
  final bool selected;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSpacing.radiusPill);
    return Semantics(
      button: true,
      selected: selected,
      label: hidden ? '$label, hidden from guests' : null,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.14)
                  : AppColors.surface,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hidden) ...[
                  const Icon(
                    Icons.visibility_off,
                    size: 12,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 5),
                ],
                ConstrainedBox(
                  // One very long category name must not fill the rail and
                  // push every other category out of reach.
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    label,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontSize: 12.5,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── One category, its dishes ──────────────────────────────────────────────

/// A category header and the dishes inside it.
///
/// The dishes live in one bordered card separated by hairlines rather than a
/// card each: a menu of forty dishes is one list, and forty floating boxes read
/// as forty widgets to manage.
class MenuSectionGroup extends StatelessWidget {
  const MenuSectionGroup({
    super.key,
    required this.section,
    required this.canEdit,
    required this.onAddItem,
    required this.onReorderItems,
    required this.onEditSection,
    required this.onDeleteSection,
    required this.onEditItem,
    required this.onDuplicateItem,
    required this.onMoveItem,
    required this.onDeleteItem,
    required this.onToggleItem,
  });

  final MenuSection section;
  final bool canEdit;
  final VoidCallback onAddItem;
  final VoidCallback onReorderItems;
  final VoidCallback onEditSection;
  final VoidCallback onDeleteSection;
  final void Function(MenuItem item) onEditItem;
  final void Function(MenuItem item) onDuplicateItem;
  final void Function(MenuItem item) onMoveItem;
  final void Function(MenuItem item) onDeleteItem;
  final void Function(MenuItem item, bool available) onToggleItem;

  @override
  Widget build(BuildContext context) {
    final items = section.sortedItems;
    final soldOut = items.where((item) => !item.isAvailable).length;
    final meta = '${items.length} ${items.length == 1 ? 'dish' : 'dishes'}'
        '${soldOut > 0 ? ' · $soldOut sold out' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs, right: 0),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  section.name,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!section.isActive) ...[
                const SizedBox(width: 6),
                _HiddenBadge(),
              ],
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  meta,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canEdit)
                PopupMenuButton<String>(
                  tooltip: '${section.name} actions',
                  icon: const Icon(
                    Icons.more_vert,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  padding: EdgeInsets.zero,
                  color: AppColors.surfaceElevated,
                  onSelected: (value) => switch (value) {
                    'add' => onAddItem(),
                    'reorder' => onReorderItems(),
                    'edit' => onEditSection(),
                    _ => onDeleteSection(),
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'add', child: Text('Add dish')),
                    PopupMenuItem(value: 'reorder', child: Text('Reorder dishes')),
                    PopupMenuItem(value: 'edit', child: Text('Rename category')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete category',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          _EmptyCategory(name: section.name, onAddItem: canEdit ? onAddItem : null)
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                  _DishRow(
                    item: items[i],
                    canEdit: canEdit,
                    onEdit: () => onEditItem(items[i]),
                    onDuplicate: () => onDuplicateItem(items[i]),
                    onMove: () => onMoveItem(items[i]),
                    onDelete: () => onDeleteItem(items[i]),
                    onToggle: (available) => onToggleItem(items[i], available),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _HiddenBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        'Hidden',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.warning,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
      ),
    );
  }
}

/// One compact row inside the category card: no icon wall, no empty band.
class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory({required this.name, this.onAddItem});

  final String name;
  final VoidCallback? onAddItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.restaurant_menu_outlined,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'No dishes in $name yet',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onAddItem != null)
            TextButton(
              onPressed: onAddItem,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: const Text('Add dish'),
            ),
        ],
      ),
    );
  }
}

/// One dish: photo, name, description, dietary tags, price, the everyday 86
/// switch and the actions that manage it.
///
/// The price sits in its own right-hand column so a column of prices can be
/// scanned at a glance, and the switch sits under it so the most repeated
/// action on this screen is one thumb-width from the edge. The name wraps to
/// two lines instead of ellipsising at the first one: a partner recognising a
/// dish by its first three words is how the wrong dish gets 86ed.
class _DishRow extends StatelessWidget {
  const _DishRow({
    required this.item,
    required this.canEdit,
    required this.onEdit,
    required this.onDuplicate,
    required this.onMove,
    required this.onDelete,
    required this.onToggle,
  });

  final MenuItem item;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final void Function(bool available) onToggle;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return InkWell(
      key: ValueKey('menu-item-${item.id}'),
      onTap: canEdit ? onEdit : null,
      child: Padding(
        padding: EdgeInsets.all(narrow ? 10 : AppSpacing.marginItem),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DishThumb(photoUrl: item.photoUrl, size: narrow ? 52 : 60),
            SizedBox(width: narrow ? 10 : AppSpacing.marginItem),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The name gets the full column width. A "Sold out" chip
                  // sat in this row and, on a 320dp phone at 2x text, left the
                  // name 78dp and overflowed the row by 103px; the state now
                  // lives under the price, where it also reads next to the
                  // switch that causes it.
                  Text(
                    item.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      letterSpacing: -0.1,
                      color: item.isAvailable
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.description,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item.dietaryTags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final tag in item.dietaryTags.take(4))
                          _DietaryTagChip(tag: tag),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(item.price, currency: 'PKR', decimals: 0),
                      style: AppTextStyles.numericMedium.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: item.isAvailable
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                if (!item.isAvailable) ...[
                  const SizedBox(height: 3),
                  // Scaled down rather than wrapped: the trailing column is a
                  // fixed 110dp, so the chip shrinks with the text scale
                  // instead of pushing the row past the card edge.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 110),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: _SoldOutBadge(),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 46,
                      height: 28,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Switch(
                          value: item.isAvailable,
                          onChanged: canEdit ? (v) => onToggle(v) : null,
                          activeThumbColor: AppColors.success,
                          inactiveThumbColor: AppColors.textTertiary,
                          activeTrackColor: AppColors.success.withValues(
                            alpha: 0.3,
                          ),
                          inactiveTrackColor: AppColors.surfaceHigh,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    if (canEdit)
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: PopupMenuButton<String>(
                          tooltip: '${item.name} actions',
                          icon: const Icon(
                            Icons.more_vert,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                          padding: EdgeInsets.zero,
                          color: AppColors.surfaceElevated,
                          onSelected: (value) => switch (value) {
                            'duplicate' => onDuplicate(),
                            'move' => onMove(),
                            'delete' => onDelete(),
                            _ => onEdit(),
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'duplicate',
                              child: Text('Duplicate'),
                            ),
                            PopupMenuItem(
                              value: 'move',
                              child: Text('Move to category'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoldOutBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        'Sold out',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.danger,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
      ),
    );
  }
}

/// Dish thumbnail, with a placeholder when no photo exists yet.
class _DishThumb extends StatelessWidget {
  const _DishThumb({required this.photoUrl, required this.size});

  final String photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        width: size,
        height: size,
        color: AppColors.surfaceElevated,
        child: photoUrl.isEmpty
            ? Center(
                child: Icon(
                  Icons.restaurant_menu,
                  size: size * 0.4,
                  color: AppColors.textTertiary,
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

/// Canonical key for a dietary tag, matching the Customer App's tag styling and
/// filter chips (`vegetarian`, `gluten-free`, `contains-nuts`, …).
///
/// Tags are free text on the server, so a partner typing `Contains Nuts` and a
/// seeded `contains-nuts` have to resolve to one key or the same dish shows a
/// styled chip in one app and a neutral one in the other.
String dietaryTagKey(String tag) =>
    tag.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '-');

/// Reader-facing label for a stored tag, `contains-nuts` becomes `Contains nuts`.
String dietaryTagLabel(String tag) {
  final key = dietaryTagKey(tag);
  if (key.isEmpty) return tag;
  return key
      .split('-')
      .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

/// Dietary tag chip, colour and icon keyed to the canonical tag.
class _DietaryTagChip extends StatelessWidget {
  const _DietaryTagChip({required this.tag});

  final String tag;

  static const Map<String, (IconData, Color)> _styles = {
    'vegetarian': (Icons.eco, AppColors.success),
    'vegan': (Icons.park, AppColors.success),
    'spicy': (Icons.local_fire_department, AppColors.danger),
    'gluten-free': (Icons.grain_outlined, AppColors.warning),
    'contains-nuts': (Icons.warning_amber_rounded, AppColors.warning),
    'dairy-free': (Icons.water_drop_outlined, AppColors.info),
    'halal': (Icons.verified_outlined, AppColors.gold),
    'seafood': (Icons.set_meal, AppColors.info),
  };

  @override
  Widget build(BuildContext context) {
    final style = _styles[dietaryTagKey(tag)];
    final color = style?.$2 ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs + 2),
      ),
      // Flexible, because a Wrap hands the chip a loose max width and an
      // unflexible label was measured at its intrinsic width: "Contains nuts"
      // at 2x text overflowed by 89px inside a 68dp column.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style?.$1 ?? Icons.label_outline, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              dietaryTagLabel(tag),
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Loading ───────────────────────────────────────────────────────────────

/// The first-load skeleton: the same block heights the real screen uses, so the
/// content does not jump when the menu arrives.
class MenuSkeleton extends StatelessWidget {
  const MenuSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingScreen,
        AppSpacing.md,
        AppSpacing.paddingScreen,
        AppSpacing.xl,
      ),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _block(112),
        const SizedBox(height: AppSpacing.sm + 4),
        _block(AppSpacing.minTapTarget),
        const SizedBox(height: AppSpacing.sm + 4),
        _block(AppSpacing.minTapTarget),
        const SizedBox(height: AppSpacing.sm + 4),
        Row(
          children: const [
            Expanded(child: SizedBox(height: 34, child: _PillBlock())),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SizedBox(height: 34, child: _PillBlock())),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SizedBox(height: 34, child: _PillBlock())),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _block(18, width: 120),
        const SizedBox(height: 6),
        _block(88),
        const SizedBox(height: AppSpacing.md),
        _block(18, width: 96),
        const SizedBox(height: 6),
        _block(88),
      ],
    );
  }

  Widget _block(double height, {double? width}) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      border: Border.all(color: AppColors.border),
    ),
  );
}

class _PillBlock extends StatelessWidget {
  const _PillBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

/// Which dishes the list is narrowed to, by availability.
enum MenuAvailabilityFilter {
  all('All dishes'),
  available('Available'),
  soldOut('Sold out'),
  missingPhoto('Missing photo');

  const MenuAvailabilityFilter(this.label);
  final String label;
}
