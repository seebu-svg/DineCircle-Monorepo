import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/venue.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/data_widgets.dart';
import '../../widgets/role_gate_builder.dart';

/// Venue profile: identity, contact, location, photos and policies.
///
/// Writes are limited to `patchVenueSchema` and only the keys the operator
/// touched are sent. Photos are URL fields with a live preview because the
/// platform exposes no partner media upload. Editing is manager-gated.
class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);

    if (venueId.isEmpty) {
      return const EmptyState(
        title: 'No venue selected',
        message: 'Choose a venue to manage its public profile.',
        icon: Icons.storefront_outlined,
      );
    }

    final detail = ref.watch(venueDetailProvider(venueId));

    return detail.when(
      loading: () => const LoadingSkeleton(count: 5, showHeader: true),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(venueDetailProvider(venueId)),
      ),
      data: (data) => _editing
          ? _ProfileEditor(
              venue: data.venue,
              done: () => setState(() => _editing = false),
            )
          : _ProfileView(
              venue: data.venue,
              counts: data.counts,
              onEdit: () => setState(() => _editing = true),
            ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({
    required this.venue,
    required this.counts,
    required this.onEdit,
  });

  final Venue venue;
  final VenueCounts counts;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final v = venue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final padding = compact ? 14.0 : 20.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            padding, 16, padding, 36,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Restaurant Profile',
                                style: AppTextStyles.headlineSmall,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Manage your public restaurant identity.',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        RoleGateBuilder(
                          capability: Capability.manageProfile,
                          builder: (context, allowed, _) {
                            return OutlinedButton.icon(
                              onPressed: allowed ? onEdit : null,
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 17,
                              ),
                              label: const Text('Edit'),
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    _RestaurantHero(venue: v),

                    const SizedBox(height: 24),

                    const _ProfileSectionTitle(
                      title: 'About Restaurant',
                      icon: Icons.storefront_outlined,
                    ),
                    const SizedBox(height: 12),

                    _ProfileSurface(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          if (v.tagline.isNotEmpty)
                            _ProfileDetail(
                              label: 'Tagline',
                              value: v.tagline,
                            ),
                          if (v.about.isNotEmpty)
                            _ProfileDetail(
                              label: 'Description',
                              value: v.about,
                            ),
                          _ProfileDetail(
                            label: 'Cuisine',
                            value: v.cuisines.join(', '),
                          ),
                          _ProfileDetail(
                            label: 'Price Range',
                            value: v.priceRange,
                          ),
                          _ProfileDetail(
                            label: 'Seating Capacity',
                            value: '${v.seats} seats',
                          ),
                          _ProfileDetail(
                            label: 'Amenities',
                            value: v.amenities.join(', '),
                            last: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const _ProfileSectionTitle(
                      title: 'Location & Contact',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 12),

                    _ProfileSurface(
                      child: Column(
                        children: [
                          _ProfileDetail(
                            label: 'Address',
                            value: v.address,
                          ),
                          _ProfileDetail(
                            label: 'Neighbourhood',
                            value: v.neighborhood,
                          ),
                          _ProfileDetail(
                            label: 'City',
                            value: v.city,
                          ),
                          _ProfileDetail(
                            label: 'Phone',
                            value: v.phone,
                          ),
                          _ProfileDetail(
                            label: 'Email',
                            value: v.email,
                          ),
                          _ProfileDetail(
                            label: 'Website',
                            value: v.website,
                          ),
                          _ProfileDetail(
                            label: 'Instagram',
                            value: v.instagram,
                            last: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const _ProfileSectionTitle(
                      title: 'Business Snapshot',
                      icon: Icons.insights_outlined,
                    ),
                    const SizedBox(height: 12),

                    DataGrid(
                      minTileWidth: 140,
                      children: [
                        KpiCard(
                          label: 'Rating',
                          value: v.rating.toStringAsFixed(1),
                          caption: '${v.reviewCount} reviews',
                          icon: Icons.star_outline_rounded,
                        ),
                        KpiCard(
                          label: 'Tables',
                          value: '${counts.tables}',
                          icon: Icons.table_restaurant_outlined,
                        ),
                        KpiCard(
                          label: 'Menu Items',
                          value: '${counts.menuItems}',
                          icon: Icons.restaurant_menu_outlined,
                        ),
                        KpiCard(
                          label: 'Branches',
                          value: '${counts.branches}',
                          icon: Icons.location_city_outlined,
                        ),
                        KpiCard(
                          label: 'Upcoming',
                          value: '${counts.upcomingEvents}',
                          icon: Icons.event_outlined,
                        ),
                        KpiCard(
                          label: 'Pending',
                          value: '${counts.pendingReservations}',
                          icon: Icons.pending_actions_outlined,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const _ProfileSectionTitle(
                      title: 'Booking Policies',
                      icon: Icons.policy_outlined,
                    ),
                    const SizedBox(height: 12),

                    _Policies(venue: v),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RestaurantHero extends StatelessWidget {
  const _RestaurantHero({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: venue.coverImage.isEmpty
                ? Container(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: 52,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                  )
                : Image.network(
                    venue.coverImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venue.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${venue.priceRange} · ${venue.statusLabel}',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProfilePill(
                      label: venue.verified
                          ? 'Verified'
                          : 'Unverified',
                      icon: venue.verified
                          ? Icons.verified_rounded
                          : Icons.info_outline,
                    ),
                    _ProfilePill(
                      label: venue.acceptingBookings
                          ? 'Accepting Bookings'
                          : 'Bookings Paused',
                      icon: Icons.event_available_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          // Flexible, not a bare Text: inside the hero's Wrap a long label at
          // 2.0 text scale is wider than the tile itself, and an unshrinkable
          // Text overflows the row instead of wrapping inside the pill.
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: child,
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.label,
    required this.value,
    this.last = false,
  });

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty
        ? 'Not provided'
        : value;

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            display,
            softWrap: true,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!last) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
          ],
        ],
      ),
    );
  }
}

/// Booking policy state, exactly as the diner experience reads it.
class _Policies extends StatelessWidget {
  const _Policies({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    return _ProfileSurface(
      child: Column(
        children: [
          _PolicyRow(
            icon: Icons.event_available_outlined,
            label: 'Accepting Bookings',
            value: venue.acceptingBookings ? 'Open' : 'Paused',
            positive: venue.acceptingBookings,
          ),
          _PolicyRow(
            icon: Icons.person_off_outlined,
            label: 'Host Approval',
            value: venue.requiresHostApproval ? 'Required' : 'Automatic',
            positive: !venue.requiresHostApproval,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.positive,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool positive;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = positive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              // Both texts take flex, so neither can claim the row's full width
              // and push the other off the edge on a 320px phone at large text.
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!last) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: Theme.of(context).dividerColor,
            ),
          ],
        ],
      ),
    );
  }
}

/// In-place profile editor.
///
/// Every field starts from the live venue and only the values the operator
/// actually touched are sent, so an untouched `email` can never blank a real
/// address. Photos stay URL fields: the platform has no partner upload route.
class _ProfileEditor extends ConsumerStatefulWidget {
  const _ProfileEditor({required this.venue, required this.done});

  final Venue venue;
  final VoidCallback done;

  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _tagline;
  late final TextEditingController _about;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _instagram;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _neighborhood;
  late final TextEditingController _cover;
  late final TextEditingController _gallery;
  late bool _accepting;
  late bool _hostApproval;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final v = widget.venue;
    _name = TextEditingController(text: v.name);
    _tagline = TextEditingController(text: v.tagline);
    _about = TextEditingController(text: v.about);
    _phone = TextEditingController(text: v.phone);
    _email = TextEditingController(text: v.email);
    _website = TextEditingController(text: v.website);
    _instagram = TextEditingController(text: v.instagram);
    _address = TextEditingController(text: v.address);
    _city = TextEditingController(text: v.city);
    _neighborhood = TextEditingController(text: v.neighborhood);
    _cover = TextEditingController(text: v.coverImage);
    _gallery = TextEditingController(text: v.gallery.join('\n'));
    _accepting = v.acceptingBookings;
    _hostApproval = v.requiresHostApproval;
  }

  @override
  void dispose() {
    for (final c in [
      _name, _tagline, _about, _phone, _email, _website, _instagram,
      _address, _city, _neighborhood, _cover, _gallery,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Diffs the form against the venue, so `toBody()` carries only real edits.
  VenueProfileEdit _dirty() {
    final v = widget.venue;
    String? ifChanged(TextEditingController c, String original) {
      final value = c.text.trim();
      return value == original.trim() ? null : value;
    }

    final galleryLines = _gallery.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final galleryChanged =
        galleryLines.length != v.gallery.length ||
            galleryLines.asMap().entries.any((e) => e.value != v.gallery[e.key]);

    return VenueProfileEdit(
      name: ifChanged(_name, v.name),
      tagline: ifChanged(_tagline, v.tagline),
      about: ifChanged(_about, v.about),
      phone: ifChanged(_phone, v.phone),
      email: ifChanged(_email, v.email),
      website: ifChanged(_website, v.website),
      instagram: ifChanged(_instagram, v.instagram),
      address: ifChanged(_address, v.address),
      city: ifChanged(_city, v.city),
      neighborhood: ifChanged(_neighborhood, v.neighborhood),
      coverImage: ifChanged(_cover, v.coverImage),
      gallery: galleryChanged ? galleryLines : null,
      acceptingBookings: _accepting == v.acceptingBookings ? null : _accepting,
      requiresHostApproval:
          _hostApproval == v.requiresHostApproval ? null : _hostApproval,
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final edit = _dirty();
    if (edit.isEmpty) {
      widget.done();
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(venueRepositoryProvider)
          .updateProfile(widget.venue.id, edit);
      ref.invalidate(venueDetailProvider(widget.venue.id));
      await ref.read(venueScopeProvider.notifier).refresh();
      if (mounted) widget.done();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not save profile:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final padding = compact ? 14.0 : 20.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              padding, 16, padding, 36,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Profile',
                                  style: AppTextStyles.headlineSmall,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Only the fields you change are saved.',
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _busy ? null : widget.done,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      const _ProfileSectionTitle(
                        title: 'Identity',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),

                      _ProfileSurface(
                        child: Column(
                          children: [
                            _field(
                              _name,
                              'Name *',
                              validator: (v) => Validators.text(
                                  v,
                                  field: 'Name',
                                  min: 2,
                                  max: Validators.venueNameMax),
                            ),
                            _field(
                              _tagline,
                              'Tagline',
                              validator: (v) => Validators.text(
                                  v,
                                  field: 'Tagline',
                                  max: Validators.taglineMax,
                                  required: false),
                            ),
                            _field(
                              _about,
                              'Description',
                              maxLines: 4,
                              validator: (v) => Validators.text(
                                  v,
                                  field: 'Description',
                                  max: Validators.aboutMax,
                                  required: false),
                              last: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const _ProfileSectionTitle(
                        title: 'Location & Contact',
                        icon: Icons.location_on_outlined,
                      ),
                      const SizedBox(height: 12),

                      _ProfileSurface(
                        child: Column(
                          children: [
                            _field(
                              _phone,
                              'Phone',
                              keyboardType: TextInputType.phone,
                              validator: Validators.phone,
                            ),
                            _field(
                              _email,
                              'Email',
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                            _field(
                              _website,
                              'Website',
                              keyboardType: TextInputType.url,
                              validator: (v) =>
                                  Validators.url(v, field: 'Website'),
                            ),
                            _field(_instagram, 'Instagram'),
                            _field(_address, 'Address'),
                            _field(_city, 'City'),
                            _field(_neighborhood, 'Neighbourhood', last: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const _ProfileSectionTitle(
                        title: 'Photos',
                        icon: Icons.photo_library_outlined,
                      ),
                      const SizedBox(height: 12),

                      _ProfileSurface(
                        child: Column(
                          children: [
                            _field(
                              _cover,
                              'Cover image URL',
                              keyboardType: TextInputType.url,
                              validator: (v) =>
                                  Validators.url(v, field: 'Cover image'),
                            ),
                            _field(
                              _gallery,
                              'Gallery URLs (one per line)',
                              maxLines: 4,
                              helper:
                                  'Uploads are unsupported - paste hosted image links.',
                              last: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      const _ProfileSectionTitle(
                        title: 'Booking Policies',
                        icon: Icons.policy_outlined,
                      ),
                      const SizedBox(height: 12),

                      _ProfileSurface(
                        child: Column(
                          children: [
                            _ToggleRow(
                              label: 'Accepting bookings',
                              value: _accepting,
                              onChanged: (v) =>
                                  setState(() => _accepting = v),
                            ),
                            _ToggleRow(
                              label: 'Require host approval',
                              value: _hostApproval,
                              onChanged: (v) =>
                                  setState(() => _hostApproval = v),
                              last: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 20),
                        label: Text(_busy ? 'Saving' : 'Save Changes'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? helper,
    String? Function(String?)? validator,
    bool last = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, helperText: helper),
        validator: validator,
      ),
    );
  }
}

/// A policy switch inside a bordered surface.
///
/// A plain Row rather than a ListTile: `ListTile` paints its ink on the nearest
/// `Material`, and the surface's coloured `DecoratedBox` sits in between, which
/// the framework asserts on.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
