import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/catalog.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/image_upload_field.dart';
import '../../widgets/premium_feedback.dart';
import '../../widgets/role_gate_builder.dart';
import 'guest_menu_preview.dart';
import 'menu_reorder_sheet.dart';
import 'menu_widgets.dart';

/// Preset dietary tags that match the customer app's dietary-filter chips.
/// Stored lower-case and hyphenated so the two apps always agree.
const List<String> kPresetDietaryTags = [
  'Vegetarian',
  'Vegan',
  'Spicy',
  'Gluten-free',
  'Contains nuts',
  'Dairy-free',
  'Halal',
  'Seafood',
];

/// The venue menu: sections, dishes and the 86-list availability toggle.
///
/// Editing is manager-gated ([Capability.manageMenu]); a staff member still sees
/// the full list read-only. Availability is the one everyday action staff care
/// about, so a sold-out toggle is offered inline wherever an item is shown,
/// routed through the bulk `…/menu/availability` endpoint the server exposes.
class MenuTab extends ConsumerStatefulWidget {
  const MenuTab({super.key});

  @override
  ConsumerState<MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<MenuTab> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToSection(String sectionId) {
    final key = _sectionKeys[sectionId];
    if (key == null || key.currentContext == null) return;
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.05,
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
    final menu = ref.watch(menuProvider(venueId));
    return Column(
      children: [
        // Header row: live status pill + action buttons.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.md,
            AppSpacing.paddingScreen,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Live status pill.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Live in Customer App',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.success,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              RoleGateBuilder(
                capability: Capability.manageMenu,
                builder: (context, allowed, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: allowed
                          ? () => _showGuestPreview(context, ref, venueId)
                          : null,
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text('Preview'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    TextButton.icon(
                      onPressed: allowed
                          ? () async {
                              final sections = await ref.read(
                                menuProvider(venueId).future,
                              ).catchError((_) => <MenuSection>[]);
                              if (!context.mounted) return;
                              await showReorderSheet(
                                context,
                                venueId: venueId,
                                mode: ReorderMode.sections,
                                sections: sections,
                              );
                              _showPublishConfirm();
                            }
                          : null,
                      icon: const Icon(Icons.swap_vert, size: 18),
                      label: const Text('Reorder'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    FilledButton.tonalIcon(
                      onPressed: allowed
                          ? () => _editSection(context, ref, venueId, null)
                          : null,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Section'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<MenuSection>>(
            value: menu,
            onRetry: () => ref.invalidate(menuProvider(venueId)),
            emptyState: EmptyState(
              title: 'No menu yet',
              message: 'Add a section, then dishes to it. The guest-facing menu '
                  'is built from these sections in order.',
              icon: Icons.restaurant_menu_outlined,
              action: RoleGateBuilder(
                capability: Capability.manageMenu,
                builder: (context, allowed, _) => FilledButton.icon(
                  onPressed: allowed
                      ? () => _editSection(context, ref, venueId, null)
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('New section'),
                ),
              ),
            ),
            builder: (context, sections) {
              // Ensure every section has a GlobalKey for jump-to.
              for (final s in sections) {
                _sectionKeys.putIfAbsent(s.id, () => GlobalKey());
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(menuProvider(venueId)),
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    bottom: AppSpacing.xl,
                    left: AppSpacing.paddingScreen,
                    right: AppSpacing.paddingScreen,
                  ),
                  children: [
                    MenuSummaryStrip(sections: sections),
                    const SizedBox(height: AppSpacing.md),
                    SectionJumpChips(
                      sections: sections,
                      onJump: _jumpToSection,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final section in sections) ...[
                      KeyedSubtree(
                        key: _sectionKeys[section.id],
                        child: CollapsibleSectionCard(
                          section: section,
                          onEditSection: () =>
                              _editSection(context, ref, venueId, section),
                          onDeleteSection: () =>
                              _deleteSection(context, ref, venueId, section),
                          onAddItem: () =>
                              _editItem(context, ref, venueId, section, null),
                          onReorderItems: () async {
                            await showReorderSheet(
                              context,
                              venueId: venueId,
                              mode: ReorderMode.items,
                              section: section,
                            );
                            _showPublishConfirm();
                          },
                          onEditItem: (item) =>
                              _editItem(context, ref, venueId, section, item),
                          onDeleteItem: (item) =>
                              _deleteItem(context, ref, venueId, item),
                          onToggleItem: (item, available) =>
                              _toggleAvailability(ref, venueId, item, available),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const NotTrackedTile(
                      metric: 'Modifiers and featured items',
                      reason:
                          'The DineCircle platform does not currently expose '
                          'modifiers or featured-item flags to partners. These '
                          'are managed on the guest app side.',
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showGuestPreview(
    BuildContext context,
    WidgetRef ref,
    String venueId,
  ) async {
    final menu = await ref.read(menuProvider(venueId).future);
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GuestMenuPreviewSheet(
        venueId: venueId,
        sections: menu,
      ),
    );
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

  Future<void> _toggleAvailability(
    WidgetRef ref,
    String venueId,
    MenuItem item,
    bool available,
  ) async {
    try {
      final updated = await ref
          .read(menuRepositoryProvider)
          .setAvailability(venueId, [item.id], isAvailable: available);
      ref.invalidate(menuProvider(venueId));
      if (updated.isEmpty) {
        debugPrint('Availability unchanged for ${item.id}');
      }
    } catch (_) {
      ref.invalidate(menuProvider(venueId));
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
      final match = kPresetDietaryTags.firstWhere(
        (p) => p.toLowerCase() == tag.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        _selectedPresetTags.add(match);
      } else {
        // Non-preset tag goes into the custom text field.
        if (_customTags.text.isEmpty) {
          _customTags.text = tag;
        } else {
          _customTags.text = '${_customTags.text}, $tag';
        }
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

  List<String> get _mergedTags {
    final custom = _customTags.text
        .split(',')
        .map((e) => e.trim())
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.item == null
                    ? 'New dish · ${widget.section.name}'
                    : 'Edit ${widget.item!.name}',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) =>
                    Validators.text(v, field: 'Name', min: 1, max: 120),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price *',
                  prefixText: 'Rs ',
                  hintText: '1450',
                ),
                validator: (v) => Validators.money(v, field: 'Price'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => Validators.text(
                  v,
                  field: 'Description',
                  max: 500,
                  required: false,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Photo upload.
              ImageUploadField(
                venueId: widget.venueId,
                kind: 'menu_item',
                label: 'Dish photo',
                value: _photoUrl,
                onChanged: (v) => setState(() => _photoUrl = v),
                enabled: !_busy,
              ),
              const SizedBox(height: AppSpacing.md),
              // Preset dietary tag chips.
              Text(
                'Dietary tags',
                style: AppTextStyles.labelMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final tag in kPresetDietaryTags)
                    FilterChip(
                      label: Text(tag),
                      selected: _selectedPresetTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedPresetTags.add(tag);
                          } else {
                            _selectedPresetTags.remove(tag);
                          }
                        });
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // Custom tags text field.
              TextFormField(
                controller: _customTags,
                decoration: const InputDecoration(
                  labelText: 'Custom tags',
                  helperText: 'Comma-separated (e.g. organic, local)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Section dropdown.
              if (widget.allSections.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedSectionId,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: [
                    for (final s in widget.allSections)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedSectionId = v);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available'),
                value: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(widget.item == null ? 'Add dish' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
