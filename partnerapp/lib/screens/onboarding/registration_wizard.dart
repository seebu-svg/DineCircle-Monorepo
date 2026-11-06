import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/venue.dart';
import '../../providers/app_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/role_gate_builder.dart';

/// Self-service venue onboarding.
///
/// Mirrors `registerVenueSchema` field-for-field, split into four short steps so
/// a phone can complete it one hand at a time. Creating a venue also links the
/// caller as `owner` and opens a verification request on the server, so finishing
/// here simply refreshes scope + session and the root gate routes to the desk.
class RegistrationWizard extends ConsumerStatefulWidget {
  const RegistrationWizard({super.key});

  @override
  ConsumerState<RegistrationWizard> createState() => _RegistrationWizardState();
}

class _RegistrationWizardState extends ConsumerState<RegistrationWizard> {
  static const _steps = ['Identity', 'Location', 'Capacity', 'Review'];
  int _step = 0;
  bool _busy = false;

  final _form = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _tagline = TextEditingController();
  final _about = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _timezone = TextEditingController(text: 'UTC');
  final _seats = TextEditingController();
  final _tables = TextEditingController();
  final _cover = TextEditingController();

  List<String> _cuisines = [];
  List<String> _amenities = [];
  String _priceRange = r'$$';

  @override
  void dispose() {
    for (final c in [
      _name, _tagline, _about, _phone, _email, _website, _instagram,
      _city, _area, _address, _timezone, _seats, _tables, _cover,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validateStep() {
    switch (_step) {
      case 0:
        return Validators.text(_name.text, field: 'Name', min: 2, max: 120) ==
                null &&
            Validators.email(_email.text) == null &&
            Validators.phone(_phone.text) == null;
      case 1:
        return Validators.text(_city.text, field: 'City', min: 1, max: 80) ==
                null &&
            Validators.text(_timezone.text, field: 'Timezone', max: 64) == null;
      case 2:
        return Validators.integer(
              _seats.text.isEmpty ? '0' : _seats.text,
              field: 'Seats',
              max: Validators.seatsMax,
              required: false,
            ) ==
            null;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep()) {
      showToast(context, _stepHint(), isError: true);
      return;
    }
    setState(() => _step = (_step + 1).clamp(0, _steps.length - 1));
  }

  void _back() =>
      setState(() => _step = (_step - 1).clamp(0, _steps.length - 1));

  String _stepHint() {
    switch (_step) {
      case 0:
        return 'Enter a venue name of at least 2 characters, and a valid '
            'email and phone.';
      case 1:
        return 'City and timezone are required.';
      case 2:
        return 'Seats must be between 0 and ${Validators.seatsMax}.';
      default:
        return 'Please review the details.';
    }
  }

  RegisterVenueInput _input() => RegisterVenueInput(
    name: _name.text,
    city: _city.text,
    tagline: _tagline.text,
    about: _about.text,
    cuisines: _cuisines,
    timezone: _timezone.text,
    area: _area.text,
    address: _address.text,
    phone: _phone.text,
    email: _email.text,
    website: _website.text,
    instagram: _instagram.text,
    priceRange: _priceRange,
    seats: int.tryParse(_seats.text.trim()) ?? 0,
    tablesCount: int.tryParse(_tables.text.trim()) ?? 0,
    amenities: _amenities,
    coverImage: _cover.text,
  );

  Future<void> _submit() async {
    if (!_validateStep()) {
      showToast(context, _stepHint(), isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(venueRepositoryProvider).register(_input());
      await ref.read(sessionProvider.notifier).reload();
      await ref.read(venueScopeProvider.notifier).refresh();
      if (!mounted) return;
      showToast(context, 'Restaurant registered. Awaiting verification.');
    } catch (error) {
      if (mounted) reportError(context, error, prefix: 'Registration failed:');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register your restaurant'),
        leading: _step > 0
            ? IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back))
            : null,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              _StepBar(step: _step, labels: _steps),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _buildStep(),
                    ),
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_name, 'Venue name *', hint: 'e.g. Saffron House'),
            _field(_tagline, 'Tagline', hint: 'One line guests will see'),
            _field(
              _about,
              'About',
              hint: 'Your story, cuisine and atmosphere',
              maxLines: 4,
            ),
            _ChipEntry(
              label: 'Cuisines',
              values: _cuisines,
              max: Validators.cuisinesMax,
              onChanged: (v) => setState(() => _cuisines = v),
            ),
            _field(_phone, 'Phone', keyboardType: TextInputType.phone),
            _field(_email, 'Email', keyboardType: TextInputType.emailAddress),
            _field(_website, 'Website', keyboardType: TextInputType.url),
            _field(_instagram, 'Instagram'),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_city, 'City *', hint: 'e.g. Karachi'),
            _field(_area, 'Area / neighborhood'),
            _field(_address, 'Street address'),
            _field(
              _timezone,
              'Timezone *',
              helper: 'IANA name, e.g. Asia/Karachi. Availability is computed '
                  'in this zone.',
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Price range', style: AppTextStyles.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final range in RegisterVenueInput.priceRanges)
                  ChoiceChip(
                    label: Text(range),
                    selected: _priceRange == range,
                    onSelected: (_) => setState(() => _priceRange = range),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              _seats,
              'Total seats',
              keyboardType: TextInputType.number,
              helper: 'Max ${Validators.seatsMax}.',
            ),
            _field(
              _tables,
              'Table count',
              keyboardType: TextInputType.number,
            ),
            _ChipEntry(
              label: 'Amenities',
              values: _amenities,
              max: Validators.amenitiesMax,
              suggestions: const [
                'Wheelchair access',
                'Outdoor seating',
                'Private dining',
                'Parking',
                'Free Wi-Fi',
              ],
              onChanged: (v) => setState(() => _amenities = v),
            ),
          ],
        );
      default:
        return _Review(input: _input());
    }
  }

  Widget _buildFooter() {
    final last = _step == _steps.length - 1;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (!last) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _next,
                child: const Text('Continue'),
              ),
            ),
          ] else ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Submit for verification'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    String? helper,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: i <= step
                        ? AppColors.primary
                        : AppColors.surfaceHigh,
                    child: Text(
                      '${i + 1}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: i <= step ? Colors.black : AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: AppTextStyles.labelSmall.copyWith(
                      color: i == step
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A chip-based list editor for string arrays (cuisines, amenities).
class _ChipEntry extends StatefulWidget {
  const _ChipEntry({
    required this.label,
    required this.values,
    required this.max,
    required this.onChanged,
    this.suggestions = const [],
  });

  final String label;
  final List<String> values;
  final int max;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;

  @override
  State<_ChipEntry> createState() => _ChipEntryState();
}

class _ChipEntryState extends State<_ChipEntry> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add(String value) {
    final v = value.trim();
    if (v.isEmpty ||
        widget.values.contains(v) ||
        widget.values.length >= widget.max) {
      return;
    }
    widget.onChanged([...widget.values, v]);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.label} (max ${widget.max})',
              style: AppTextStyles.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final value in widget.values)
                InputChip(
                  label: Text(value),
                  onDeleted: () => widget.onChanged(
                    widget.values.where((v) => v != value).toList(),
                  ),
                ),
              for (final suggestion in widget.suggestions)
                if (!widget.values.contains(suggestion))
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () => _add(suggestion),
                  ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  onSubmitted: _add,
                  decoration: InputDecoration(
                    hintText: 'Add ${widget.label.toLowerCase()}…',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _add(_input.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({required this.input});

  final RegisterVenueInput input;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & submit', style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Creating a venue links you as its owner and opens a verification '
          'request. You can keep using the desk, but you cannot publish deals '
          'or accept paid experiences until DineCircle verifies it.',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.paddingCard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Name', input.name),
                _row('Tagline', input.tagline),
                _row('Cuisines', input.cuisines.join(', ')),
                _row('Location', [input.area, input.city].join(', ')),
                _row('Timezone', input.timezone),
                _row('Price range', input.priceRange),
                _row('Seats', '${input.seats}'),
                _row('Tables', '${input.tablesCount}'),
                _row('Amenities', input.amenities.join(', ')),
                _row('Contact', [input.phone, input.email].join(' · ')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      );
}

