import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalog.dart';
import '../../models/venue.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/image_upload_field.dart';
import '../../widgets/role_gate_builder.dart';
import 'menu_reorder_sheet.dart';
import 'menu_widgets.dart';

/// Preset dietary tags, offered as chips in the dish sheet.
///
/// The value stored is the canonical key the Customer App styles and filters
/// on (`contains-nuts`, `gluten-free`); the label is what a partner reads.
/// Storing the label instead leaves guests with a neutral chip for the same
/// dish, because `contains nuts` is not `contains-nuts`.
const List<(String key, String label)> kPresetDietaryTags = [
  ('vegetarian', 'Vegetarian'),
  ('vegan', 'Vegan'),
  ('spicy', 'Spicy'),
  ('seafood', 'Seafood'),
  ('gluten-free', 'Gluten free'),
  ('contains-nuts', 'Contains nuts'),
  ('dairy-free', 'Dairy free'),
  ('halal', 'Halal'),
];

/// The keys of [kPresetDietaryTags], for deciding whether a stored tag is one
/// of the presets or genuine free text that belongs in the custom field.
final Set<String> kPresetDietaryTagKeys = {
  for (final (key, _) in kPresetDietaryTags) key,
};

/// The venue menu: categories, dishes and the 86 availability switch.
///
/// Every menu write on the server needs the manager role, including the
/// availability route, so the whole editing surface is gated on
/// [Capability.manageMenu] rather than only the toolbar. A staff member gets
/// the same list read-only, with no control that would come back forbidden.
class MenuTab extends ConsumerStatefulWidget {
  const MenuTab({super.key});

  @override
  ConsumerState<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<MenuTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _search = TextEditingController();

  String _query = '';
  MenuAvailabilityFilter _availability = MenuAvailabilityFilter.all;

  /// The category chip that reads as selected. Null means the *All* chip.
  String? _categoryId;

  /// Until the partner taps a chip, the menu opens on the first category. A
  /// screen that starts as every dish of every category in one scroll is the
  /// page this design set out to replace.
  bool _categoryPicked = false;

  /// Item ids with a write in flight. The switch repaints only after the
  /// provider refresh, so without this a double tap fires two PATCHes.
  final Set<String> _pendingWrites = {};

  @override
  void dispose() {
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _filtering =>
      _query.trim().isNotEmpty ||
      _availability != MenuAvailabilityFilter.all;

  /// The category the list is showing, resolved against what still exists, so
  /// deleting the selected category falls back to the first one rather than to
  /// a blank screen.
  String? _selectedCategoryId(List<MenuSection> sections) {
    if (sections.isEmpty) return null;
    if (!_categoryPicked) return sections.first.id;
    if (_categoryId == null) return null;
    return sections.any((section) => section.id == _categoryId)
        ? _categoryId
        : sections.first.id;
  }

  void _selectCategory(String? sectionId) {
    setState(() {
      _categoryPicked = true;
      _categoryId = sectionId;
    });
    _scrollToTop();
  }

  void _setAvailability(MenuAvailabilityFilter filter) {
    if (filter == _availability) return;
    setState(() => _availability = filter);
    _scrollToTop();
  }

  void _onQueryChanged(String value) => setState(() => _query = value);

  void _clearFilters() {
    setState(() {
      _search.clear();
      _query = '';
      _availability = MenuAvailabilityFilter.all;
    });
  }

  /// A dish that lives in another category is one tap away instead of a dead
  /// "no results" under whichever category the partner happened to be on.
  void _searchAllCategories() {
    setState(() {
      _categoryPicked = true;
      _categoryId = null;
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  bool _matchesQuery(MenuItem item, String query) =>
      query.isEmpty ||
      item.name.toLowerCase().contains(query) ||
      item.description.toLowerCase().contains(query);

  bool _matchesAvailability(MenuItem item) => switch (_availability) {
    MenuAvailabilityFilter.all => true,
    MenuAvailabilityFilter.available => item.isAvailable,
    MenuAvailabilityFilter.soldOut => !item.isAvailable,
    MenuAvailabilityFilter.missingPhoto => item.photoUrl.isEmpty,
  };

  /// The categories the list renders, with their dishes narrowed by the search
  /// and the availability filter.
  ///
  /// A filtered list drops the categories it has nothing left for; an
  /// unfiltered one keeps every category, including a new empty one, so a
  /// partner can see where the next dish has to go.
  List<MenuSection> _visibleSections(
    List<MenuSection> all,
    String? selectedId,
  ) {
    final query = _query.trim().toLowerCase();
    final scope = selectedId == null
        ? all
        : all.where((section) => section.id == selectedId);
    final view = <MenuSection>[];
    for (final section in scope) {
      final items = section.sortedItems
          .where(
            (item) =>
                _matchesQuery(item, query) && _matchesAvailability(item),
          )
          .toList();
      if (items.isEmpty && _filtering) continue;
      view.add(
        items.length == section.items.length
            ? section
            : section.copyWith(items: items),
      );
    }
    return view;
  }

  /// How many dishes the query would find if the category chip were ignored.
  int _matchesOutside(List<MenuSection> all, String selectedId) {
    final query = _query.trim().toLowerCase();
    var count = 0;
    for (final section in all) {
      if (section.id == selectedId) continue;
      count += section.items
          .where(
            (item) =>
                _matchesQuery(item, query) && _matchesAvailability(item),
          )
          .length;
    }
    return count;
  }

  /// Derives the header status from what the public route can actually serve.
  ///
  /// A menu is live for a guest when the venue is verified and at least one
  /// active category holds an available dish. Anything else is a draft, and
  /// the reason is shown on the pill so the partner knows what to fix.
  (MenuPublishState, String) _publishStatus(
    List<MenuSection> sections, {
    required bool venueVerified,
  }) {
    final totalItems = sections.fold<int>(
      0,
      (sum, section) => sum + section.items.length,
    );
    if (totalItems == 0) {
      return (MenuPublishState.draft, 'Draft: no dishes on the menu yet');
    }
    if (!venueVerified) {
      return (
        MenuPublishState.draft,
        'Draft: the venue is not verified, so guests see no menu',
      );
    }
    final visibleDishes = sections
        .where((section) => section.isActive)
        .fold<int>(0, (sum, section) => sum + section.availableCount);
    if (visibleDishes == 0) {
      return (
        MenuPublishState.draft,
        'Draft: every dish is sold out or in a hidden category',
      );
    }
    final hiddenCategories = sections.where((s) => !s.isActive).length;
    return (
      MenuPublishState.live,
      'Live: $visibleDishes dishes visible to guests'
      '${hiddenCategories == 0 ? '' : ' · $hiddenCategories hidden'}',
    );
  }

  void _showPublishConfirm() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menu updated. Live in the Customer App'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    final venue = ref.watch(selectedVenueProvider);
    final menu = ref.watch(menuProvider(venueId));
    // The server requires the manager role on every menu write, the
    // availability PATCH included, so one flag decides the whole editing
    // surface. Staff get the same list read-only rather than a switch that
    // would come back 403 and roll itself straight back again.
    final canEdit = ref.watch(roleGateProvider).can(Capability.manageMenu);
    return menu.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const MenuSkeleton(),
      error: (error, _) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.paddingScreen),
          children: [
            const SizedBox(height: AppSpacing.xl),
            ErrorView(
              error: error,
              onRetry: () => ref.invalidate(menuProvider(venueId)),
            ),
          ],
        ),
      ),
      data: (all) => _buildMenu(context, venueId, venue, all, canEdit),
    );
  }

  Future<void> _refresh() async {
    final venueId = ref.read(selectedVenueIdProvider);
    ref.invalidate(menuProvider(venueId));
    await ref
        .read(menuProvider(venueId).future)
        .catchError((_) => const <MenuSection>[]);
  }

  /// Header, actions, search and categories stay put; only the dishes scroll.
  ///
  /// That is what keeps a category with forty dishes browsable on a phone: the
  /// rail that switches categories never scrolls out of reach, and the search
  /// field is always one tap away from a waiter holding the device.
  Widget _buildMenu(
    BuildContext context,
    String venueId,
    Venue? venue,
    List<MenuSection> all,
    bool canEdit,
  ) {
    final (publishState, publishDetail) = _publishStatus(
      all,
      venueVerified: venue?.verified ?? false,
    );
    final selectedId = _selectedCategoryId(all);
    final view = _visibleSections(all, selectedId);
    final venueName = (venue?.name ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.md,
            AppSpacing.paddingScreen,
            AppSpacing.sm,
          ),
          child: MenuHeaderCard(
            venue: venue,
            name: venueName.isEmpty ? 'Your restaurant' : venueName,
            identity: _identityLine(venue),
            sections: all,
            state: publishState,
            statusDetail: publishDetail,
            availability: _availability,
            onFilter: _setAvailability,
          ),
        ),
        Padding(
          // The icon buttons carry their own 8dp of padding, so the row lines
          // up with the cards above it at a slightly tighter inset.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingScreen - 8,
          ),
          child: MenuActionBar(
            canEdit: canEdit,
            canReorderSections: all.length > 1,
            onAddItem: () => _addItem(context, ref, venueId, all),
            onAddCategory: () => _editSection(context, ref, venueId, null),
            onReorderSections: () => _reorderSections(context, ref, venueId),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.sm,
            AppSpacing.paddingScreen,
            0,
          ),
          child: MenuSearchRow(
            searchController: _search,
            onSearchChanged: _onQueryChanged,
            availability: _availability,
            onAvailabilityChanged: _setAvailability,
          ),
        ),
        if (all.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm + 2),
          MenuCategoryRail(
            sections: all,
            selectedId: selectedId,
            totalItems: all.fold(0, (sum, s) => sum + s.items.length),
            onSelect: _selectCategory,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: all.isEmpty
                ? _emptyMenu(context, venueId)
                : _menuList(context, venueId, all, view, selectedId, canEdit),
          ),
        ),
      ],
    );
  }

  Widget _emptyMenu(BuildContext context, String venueId) {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingScreen,
        AppSpacing.lg,
        AppSpacing.paddingScreen,
        AppSpacing.xl,
      ),
      children: [
        EmptyState(
          title: 'No menu yet',
          message: 'Add a category, then dishes to it. Guests see this menu in '
              'the order you build it.',
          icon: Icons.restaurant_menu_outlined,
          compact: true,
          action: RoleGateBuilder(
            capability: Capability.manageMenu,
            builder: (context, allowed, _) => FilledButton.icon(
              onPressed: allowed
                  ? () => _editSection(context, ref, venueId, null)
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New category'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuList(
    BuildContext context,
    String venueId,
    List<MenuSection> all,
    List<MenuSection> view,
    String? selectedId,
    bool canEdit,
  ) {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingScreen,
        AppSpacing.xs,
        AppSpacing.paddingScreen,
        AppSpacing.xl,
      ),
      children: [
        if (_filtering) ...[
          MenuFilterSummary(
            caption: _filterCaption(all, view, selectedId),
            onClear: _clearFilters,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (view.isEmpty)
          _noMatches(all, selectedId)
        else
          for (var i = 0; i < view.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            MenuSectionGroup(
              section: view[i],
              canEdit: canEdit,
              onAddItem: () => _editItem(
                context,
                ref,
                venueId,
                _canonical(venueId, view[i]),
                null,
              ),
              onReorderItems: () => _reorderItems(
                context,
                ref,
                venueId,
                _canonical(venueId, view[i]),
              ),
              onEditSection: () =>
                  _editSection(context, ref, venueId, view[i]),
              onDeleteSection: () =>
                  _deleteSection(context, ref, venueId, view[i]),
              onEditItem: (item) =>
                  _editItem(context, ref, venueId, view[i], item),
              onDuplicateItem: (item) =>
                  _duplicateItem(context, ref, venueId, view[i], item),
              onMoveItem: (item) =>
                  _moveItem(context, ref, venueId, view[i], item),
              onDeleteItem: (item) =>
                  _deleteItem(context, ref, venueId, item),
              onToggleItem: (item, available) => _toggleAvailability(
                context,
                ref,
                venueId,
                item,
                available,
              ),
            ),
          ],
      ],
    );
  }

  Widget _noMatches(List<MenuSection> all, String? selectedId) {
    final query = _query.trim();
    final elsewhere =
        selectedId != null && _matchesOutside(all, selectedId) > 0;
    return EmptyState(
      title: 'No dishes match',
      message: query.isEmpty
          ? 'Nothing in this menu is ${_availability.label.toLowerCase()} '
                'right now.'
          : 'No dish in this menu matches "$query".',
      icon: Icons.search_off,
      compact: true,
      action: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.center,
        children: [
          if (elsewhere)
            OutlinedButton(
              onPressed: _searchAllCategories,
              child: const Text('Search all dishes'),
            ),
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }

  /// "Sold out · 3 of 24 dishes" while a filter is on, and nothing when it is
  /// not, so an unfiltered list never reads as a subset of itself.
  String _filterCaption(
    List<MenuSection> all,
    List<MenuSection> view,
    String? selectedId,
  ) {
    int dishes(List<MenuSection> sections) =>
        sections.fold(0, (sum, section) => sum + section.items.length);
    final scope = selectedId == null
        ? all
        : all.where((section) => section.id == selectedId).toList();
    final shown = dishes(view);
    final total = dishes(scope);
    final query = _query.trim();
    return <String>[
      if (query.isNotEmpty) 'Searching "$query"',
      if (_availability != MenuAvailabilityFilter.all) _availability.label,
      '$shown of $total ${total == 1 ? 'dish' : 'dishes'}',
    ].join(' · ');
  }

  /// "Seafood · Karachi", whichever of those the venue actually has.
  String _identityLine(Venue? venue) {
    if (venue == null) return '';
    return <String>[
      ...venue.cuisines.take(2),
      if (venue.city.trim().isNotEmpty) venue.city.trim(),
    ].join(' · ');
  }

  /// The live, unfiltered copy of a category.
  ///
  /// Filtering narrows the items for display, but any write that counts or
  /// renumbers dishes has to run against the full list: reordering the three
  /// visible dishes of a hidden-photo filter would otherwise renumber the
  /// dishes that are not on screen.
  MenuSection _canonical(String venueId, MenuSection section) {
    final all =
        ref.read(menuProvider(venueId)).valueOrNull ?? const <MenuSection>[];
    return all.firstWhere(
      (s) => s.id == section.id,
      orElse: () => section,
    );
  }

  /// Primary action. A dish cannot exist without a category, and the server
  /// rejects an item posted without a `sectionId` this restaurant owns, so an
  /// empty menu is sent to the category form instead of a sheet that could
  /// never save.
  void _addItem(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    List<MenuSection> sections,
  ) {
    if (sections.isEmpty) {
      showToast(context, 'Add a category first, then dishes to it');
      _editSection(context, ref, venueId, null);
      return;
    }
    // A dish is added to the category the partner is looking at, not to
    // whichever category happens to sort first, and never to a category that
    // has just been deleted from under the chip.
    final selectedId = _selectedCategoryId(sections);
    final target = selectedId == null
        ? sections.first
        : sections.firstWhere(
            (section) => section.id == selectedId,
            orElse: () => sections.first,
          );
    _editItem(context, ref, venueId, target, null);
  }

  Future<void> _reorderSections(
    BuildContext context,
    WidgetRef ref,
    String venueId,
  ) async {
    final sections = await ref
        .read(menuProvider(venueId).future)
        .catchError((_) => <MenuSection>[]);
    if (!context.mounted) return;
    if (sections.length < 2) {
      showToast(context, 'There is only one category to order');
      return;
    }
    await showReorderSheet(
      context,
      venueId: venueId,
      mode: ReorderMode.sections,
      sections: sections,
    );
    _showPublishConfirm();
  }

  Future<void> _reorderItems(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    MenuSection section,
  ) async {
    if (section.items.length < 2) {
      showToast(context, '${section.name} has one dish to order');
      return;
    }
    await showReorderSheet(
      context,
      venueId: venueId,
      mode: ReorderMode.items,
      section: section,
    );
    _showPublishConfirm();
  }

  /// Copies a dish into the same category at the end of its list.
  ///
  /// Price, description, photo and dietary tags all come across, because a
  /// partner duplicating a dish is almost always cloning the whole record and
  /// changing one field. The server caps a name at 120 characters, so the
  /// suffix is taken off the name rather than cutting "copy" short.
  Future<void> _duplicateItem(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    MenuSection section,
    MenuItem item,
  ) async {
    if (!_pendingWrites.add(item.id)) return;
    try {
      final target = _canonical(venueId, section);
      await ref.read(menuRepositoryProvider).createItem(
        venueId,
        sectionId: target.id,
        name: _copyName(item.name),
        price: item.price,
        description: item.description,
        position: target.items.length,
        isAvailable: item.isAvailable,
        dietaryTags: item.dietaryTags,
        photoUrl: item.photoUrl,
      );
      _showPublishConfirm();
    } catch (error) {
      if (context.mounted) {
        reportError(context, error, prefix: 'Could not duplicate dish:');
      }
    } finally {
      ref.invalidate(menuProvider(venueId));
      _pendingWrites.remove(item.id);
    }
  }

  static String _copyName(String name) {
    const suffix = ' copy';
    // `itemSchema.name` is `z.string().min(1).max(120)` on the server; past
    // that the create would come back 422 after the sheet had closed.
    const limit = 120;
    if (name.length + suffix.length <= limit) return '$name$suffix';
    return '${name.substring(0, limit - suffix.length)}$suffix';
  }

  /// Moves a dish to another category.
  ///
  /// The server only accepts a `sectionId` belonging to the same restaurant
  /// (422 otherwise), and the position the dish held in its old group means
  /// nothing in the new one, so it lands at the end and is reordered from
  /// there.
  Future<void> _moveItem(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    MenuSection section,
    MenuItem item,
  ) async {
    final all =
        ref.read(menuProvider(venueId)).valueOrNull ?? const <MenuSection>[];
    final options = all.where((s) => s.id != section.id).toList();
    if (options.isEmpty) {
      showToast(context, 'This menu has no other category to move to');
      return;
    }
    final destination = await showModalBottomSheet<MenuSection>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text('Move to category'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                '${item.name} · currently in ${section.name}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final option in options)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(
                  option.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${option.items.length} dishes'),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (destination == null) return;
    try {
      await ref.read(menuRepositoryProvider).updateItem(
        venueId,
        item.id,
        sectionId: destination.id,
        position: _canonical(venueId, destination).items.length,
      );
      _showPublishConfirm();
    } catch (error) {
      if (context.mounted) {
        reportError(context, error, prefix: 'Could not move dish:');
      }
    } finally {
      ref.invalidate(menuProvider(venueId));
    }
  }

  Future<void> _editSection(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    MenuSection? section,
  ) async {
    int nextPosition = 0;
    if (section == null) {
      final sections = await ref
          .read(menuProvider(venueId).future)
          .catchError((_) => <MenuSection>[]);
      nextPosition = sections.length;
    }
    if (!context.mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SectionSheet(
        venueId: venueId,
        section: section,
        nextPosition: nextPosition,
      ),
    );
    if (saved == true) {
      ref.invalidate(menuProvider(venueId));
      _showPublishConfirm();
    }
  }

  Future<void> _deleteSection(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    MenuSection section,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${section.name}?',
      message: 'This removes the section and its ${section.items.length} '
          'items. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(menuRepositoryProvider).deleteSection(venueId, section.id);
      ref.invalidate(menuProvider(venueId));
      _showPublishConfirm();
    } catch (error) {
      if (context.mounted) {
        reportError(context, error, prefix: 'Could not delete section:');
      }
    }
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    MenuSection section,
    MenuItem? item,
  ) async {
    final allSections =
        await ref.read(menuProvider(venueId).future).catchError(
              (_) => <MenuSection>[],
            );
    if (!context.mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ItemSheet(
        venueId: venueId,
        section: section,
        item: item,
        allSections: allSections,
        nextPosition: item == null ? section.items.length : 0,
      ),
    );
    if (saved == true) {
      ref.invalidate(menuProvider(venueId));
      _showPublishConfirm();
    }
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    MenuItem item,
  ) async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${item.name}?',
      message: 'The dish is removed from the menu. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(menuRepositoryProvider).deleteItem(venueId, item.id);
      ref.invalidate(menuProvider(venueId));
      _showPublishConfirm();
    } catch (error) {
      if (context.mounted) {
        reportError(context, error, prefix: 'Could not delete item:');
      }
    }
  }

  /// 86 / un-86 a dish.
  ///
  /// A rejected PATCH is reported and the list reloaded, so the switch always
  /// ends on what the server holds. Swallowing the error used to leave the
  /// toggle painted sold-out while the row stayed available, which is exactly
  /// how a kitchen that is out of a dish keeps taking orders for it.
  Future<void> _toggleAvailability(
    BuildContext context,
    WidgetRef ref,
    String venueId,
    MenuItem item,
    bool available,
  ) async {
    if (!_pendingWrites.add(item.id)) return;
    try {
      final updated = await ref
          .read(menuRepositoryProvider)
          .setAvailability(venueId, [item.id], isAvailable: available);
      if (updated.isEmpty) {
        debugPrint('Availability unchanged for ${item.id}');
      }
    } catch (error) {
      if (context.mounted) {
        reportError(context, error, prefix: 'Could not update availability:');
      }
    } finally {
      ref.invalidate(menuProvider(venueId));
      _pendingWrites.remove(item.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Section sheet
// ---------------------------------------------------------------------------

class _SectionSheet extends ConsumerStatefulWidget {
  const _SectionSheet({
    required this.venueId,
    this.section,
    this.nextPosition = 0,
  });

  final String venueId;
  final MenuSection? section;
  final int nextPosition;

  @override
  ConsumerState<_SectionSheet> createState() => _SectionSheetState();
}

class _SectionSheetState extends ConsumerState<_SectionSheet> {
  final _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  late bool _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = widget.section?.name ?? '';
    _active = widget.section?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(menuRepositoryProvider);
    try {
      final section = widget.section;
      if (section == null) {
        await repo.createSection(
          widget.venueId,
          name: _name.text,
          position: widget.nextPosition,
          isActive: _active,
        );
      } else {
        await repo.updateSection(
          widget.venueId,
          section.id,
          name: _name.text,
          isActive: _active,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not save section:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.section == null ? 'New section' : 'Rename section',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Section name *'),
              validator: (v) =>
                  Validators.text(v, field: 'Name', min: 1, max: 80),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to guests'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item sheet
// ---------------------------------------------------------------------------

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet({
    required this.venueId,
    required this.section,
    this.item,
    required this.allSections,
    this.nextPosition = 0,
  });

  final String venueId;
  final MenuSection section;
  final MenuItem? item;
  final List<MenuSection> allSections;
  final int nextPosition;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  final _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _customTags = TextEditingController();
  String _photoUrl = '';
  String _selectedSectionId = '';
  late bool _available;
  bool _busy = false;
  final Set<String> _selectedPresetTags = {};

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _name.text = i?.name ?? '';
    _description.text = i?.description ?? '';
    _price.text = i == null ? '' : i.price.toStringAsFixed(0);
    _photoUrl = i?.photoUrl ?? '';
    _selectedSectionId = i?.sectionId ?? widget.section.id;
    _available = i?.isAvailable ?? true;

    // Seed preset chips and custom text from existing tags.
    final existing = i?.dietaryTags ?? const <String>[];
    for (final tag in existing) {
      final key = dietaryTagKey(tag);
      if (kPresetDietaryTagKeys.contains(key)) {
        _selectedPresetTags.add(key);
      } else {
        // A stored key is shown as a label in the free-text field; the key
        // form is what goes back out, so nobody has to read `contains-nuts`.
        final label = dietaryTagLabel(tag);
        _customTags.text = _customTags.text.isEmpty
            ? label
            : '${_customTags.text}, $label';
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _price, _customTags]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Tags to send: the selected presets, already canonical keys, plus whatever
  /// the partner typed, normalised into the same key space.
  ///
  /// The Customer App styles and filters dishes on `contains-nuts`, so saving
  /// the label `Contains nuts` instead leaves a guest with a neutral chip on
  /// the very same dish. One key space is what keeps the two apps agreeing.
  List<String> get _mergedTags {
    final custom = _customTags.text
        .split(',')
        .map(dietaryTagKey)
        .where((e) => e.isNotEmpty);
    final merged = <String>{..._selectedPresetTags, ...custom};
    return merged.take(Validators.dietaryTagsMax).toList();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = ref.read(menuRepositoryProvider);
    final tags = _mergedTags;
    try {
      final item = widget.item;
      if (item == null) {
        await repo.createItem(
          widget.venueId,
          sectionId: _selectedSectionId,
          name: _name.text,
          price: double.parse(_price.text.trim()),
          description: _description.text,
          position: widget.nextPosition,
          isAvailable: _available,
          dietaryTags: tags,
          photoUrl: _photoUrl,
        );
      } else {
        await repo.updateItem(
          widget.venueId,
          item.id,
          sectionId: _selectedSectionId,
          name: _name.text,
          description: _description.text,
          price: double.parse(_price.text.trim()),
          isAvailable: _available,
          dietaryTags: tags,
          photoUrl: _photoUrl,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not save item:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle and header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // Header row with title and close button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit Menu Item' : 'Add Menu Item',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Scrollable form content ─────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg + bottomInset + 72, // Space for sticky save
              ),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Photo upload (compact 16:9 preview) ─────────────
                    Text(
                      'Dish Photo',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ImageUploadField(
                      venueId: widget.venueId,
                      kind: 'menu_item',
                      label: '',
                      value: _photoUrl,
                      onChanged: (v) => setState(() => _photoUrl = v),
                      enabled: !_busy,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    
                    // ── Basic information ─────────────────────────────────
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Dish Name *',
                        hintText: 'e.g. Chicken Biryani',
                      ),
                      validator: (v) =>
                          Validators.text(v, field: 'Name', min: 1, max: 120),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    
                    // Price and section in a row for compact layout
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price field
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Price *',
                              prefixText: 'Rs. ',
                              hintText: '1450',
                            ),
                            validator: (v) =>
                                Validators.money(v, field: 'Price'),
                          ),
                        ),
                        if (widget.allSections.length > 1) ...[
                          const SizedBox(width: AppSpacing.sm),
                          // Section dropdown
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedSectionId,
                              decoration: const InputDecoration(
                                labelText: 'Section',
                              ),
                              items: [
                                for (final s in widget.allSections)
                                  DropdownMenuItem(
                                    value: s.id,
                                    child: Text(
                                      s.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedSectionId = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Short description of the dish...',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => Validators.text(
                        v,
                        field: 'Description',
                        max: 500,
                        required: false,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    
                    // ── Dietary tags ──────────────────────────────────────
                    Text(
                      'Dietary Tags',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final (key, label) in kPresetDietaryTags)
                          _CompactTagChip(
                            label: label,
                            selected: _selectedPresetTags.contains(key),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedPresetTags.add(key);
                                } else {
                                  _selectedPresetTags.remove(key);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    
                    TextFormField(
                      controller: _customTags,
                      decoration: const InputDecoration(
                        labelText: 'Custom Tags',
                        helperText: 'Comma-separated (e.g. organic, local)',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    
                    // ── Availability toggle ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Available',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _available
                                      ? 'Visible to guests'
                                      : 'Hidden from menu',
                                  style: AppTextStyles.caption.copyWith(
                                    color: _available
                                        ? AppColors.success
                                        : AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _available,
                            onChanged: (v) => setState(() => _available = v),
                            activeThumbColor: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Sticky save button ──────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md + bottomInset,
            ),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEditing ? 'Save Changes' : 'Add Menu Item',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact dietary tag chip with improved styling.
class _CompactTagChip extends StatelessWidget {
  const _CompactTagChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onSelected(!selected),
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
