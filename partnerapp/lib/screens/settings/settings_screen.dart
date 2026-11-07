import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../models/account.dart';
import '../../navigation/app_routes.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../repositories/auth_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/brand.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

/// Settings & security, the account surface (`/users/me`, `/auth/*`).
///
/// Only the server allowlist on `PATCH /users/me` is written (name, phone, bio,
/// city, dietary, allergies). Notification cadence is a *device* preference,
/// labelled as such, because the partner API has no server-side prefs. Payout
/// details are read-only with a support link, since there is no partner bank
/// route. Every credential change routes through the auth endpoints and drops
/// the local session when all devices are revoked.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return AppShell(
      active: PrimaryDestination.home,
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          _AccountSection(user: user),
          const _NotificationsSection(),
          const _SecuritySection(),
          const _PayoutSection(),
          const _AboutSection(),
          const _SignOutSection(),
        ],
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection({required this.user});

  final PartnerUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = user;
    return SettingsSection(
      title: 'Account',
      children: [
        SettingsTile(
          label: u?.name ?? 'Signed in',
          description: u?.email ?? '',
          icon: Icons.person_outline,
          showChevron: false,
        ),
        SettingsTile(
          label: 'Edit profile & dietary preferences',
          description: 'Name, phone, city, bio, allergies',
          icon: Icons.edit_outlined,
          onTap: () => _edit(context, ref, u),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PartnerUser? u) async {
    if (u == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountSheet(user: u),
    );
    if (saved == true) await ref.read(sessionProvider.notifier).reload();
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({required this.user});

  final PartnerUser user;

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _city = TextEditingController(text: widget.user.city);
  late final _bio = TextEditingController(text: widget.user.bio);
  late final _dietary = TextEditingController(text: widget.user.dietary.join(', '));
  late final _allergies = TextEditingController(text: widget.user.allergies.join(', '));
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _city, _bio, _dietary, _allergies]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _list(TextEditingController c) => c.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'city': _city.text.trim(),
        'bio': _bio.text.trim(),
        'dietary': _list(_dietary),
        'allergies': _list(_allergies),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not save:');
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
              Text('Your profile', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name *'),
                validator: (v) =>
                    Validators.text(v, field: 'Name', min: 2, max: 120),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: Validators.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _bio,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio'),
                validator: (v) =>
                    Validators.text(v, field: 'Bio', max: 500, required: false),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _dietary,
                decoration: const InputDecoration(
                  labelText: 'Dietary preferences',
                  helperText: 'Comma-separated',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _allergies,
                decoration: const InputDecoration(
                  labelText: 'Allergies',
                  helperText: 'Comma-separated',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationsSection extends ConsumerWidget {
  const _NotificationsSection();

  static const _options = <int, String>{
    0: 'Off (manual refresh only)',
    30: 'Every 30 seconds',
    60: 'Every minute',
    120: 'Every 2 minutes',
    300: 'Every 5 minutes',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(notificationPollSecondsProvider);
    return SettingsSection(
      title: 'Notifications',
      footer: 'These are stored on this device only. The partner API has no '
          'server-side notification preferences, and there is no push channel, '
          'so the inbox refreshes on this timer while the app is open.',
      children: [
        SettingsTile(
          label: 'Inbox polling cadence',
          description: _options[seconds] ?? 'Custom',
          icon: Icons.refresh,
          onTap: () => _pick(context, ref),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final current = ref.read(notificationPollSecondsProvider);
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Poll every'),
        children: [
          for (final entry in _options.entries)
            RadioMenuButton<int>(
              value: entry.key,
              groupValue: current,
              onChanged: (v) => Navigator.of(context).pop(v),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    ref.read(notificationPollSecondsProvider.notifier).state = chosen;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setInt('partner.pollSeconds', chosen);
    await ref.read(notificationBadgeProvider.notifier).refresh();
  }
}

class _SecuritySection extends ConsumerWidget {
  const _SecuritySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: 'Security',
      children: [
        SettingsTile(
          label: 'Change password',
          icon: Icons.lock_outline,
          onTap: () => _changePassword(context, ref),
        ),
        SettingsTile(
          label: 'Change email',
          description: 'Confirm with a code the platform sends',
          icon: Icons.alternate_email,
          onTap: () => _changeEmail(context, ref),
        ),
        SettingsTile(
          label: 'Sign out everywhere',
          description: 'Revokes every session including this device',
          icon: Icons.logout,
          destructive: true,
          onTap: () => _logoutAll(context, ref),
        ),
      ],
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PasswordSheet(),
    );
    if (done == true && context.mounted) {
      showToast(context, 'Password updated');
    }
  }

  Future<void> _changeEmail(BuildContext context, WidgetRef ref) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _EmailSheet(),
    );
    if (done == true && context.mounted) {
      showToast(context, 'Email updated');
      await ref.read(sessionProvider.notifier).reload();
    }
  }

  Future<void> _logoutAll(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Sign out everywhere?',
      message: 'Every device will be signed out and you will need to sign in '
          'again here.',
      confirmLabel: 'Sign out all',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(authRepositoryProvider).logOutEveryDevice();
    } catch (_) {
      // The credential is gone server-side whatever the call returns; the local
      // token must be dropped regardless.
    }
    await ref.read(sessionProvider.notifier).signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoute.login,
        (route) => false,
      );
    }
  }
}

class _PasswordSheet extends ConsumerStatefulWidget {
  const _PasswordSheet();

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not change password:');
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
            Text('Change password', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (v) =>
                  Validators.text(v, field: 'Current password', min: 1),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (v) =>
                  Validators.text(v, field: 'New password', min: 8, max: 200),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailSheet extends ConsumerStatefulWidget {
  const _EmailSheet();

  @override
  ConsumerState<_EmailSheet> createState() => _EmailSheetState();
}

class _EmailSheetState extends ConsumerState<_EmailSheet> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  EmailChallenge? _challenge;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final challenge = await ref.read(authRepositoryProvider).requestEmailChange(
        email: _email.text,
        password: _password.text,
      );
      if (mounted) {
        setState(() {
          _challenge = challenge;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not start change:');
      }
    }
  }

  Future<void> _confirm() async {
    if ((_code.text.trim()).isEmpty) {
      showToast(context, 'Enter the code', isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).confirmEmailChange(
        email: _email.text,
        code: _code.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not confirm:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devCode = _challenge?.devCode;
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
            Text('Change email', style: AppTextStyles.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'New email'),
              validator: (v) => Validators.email(v, required: true),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: _challenge == null
                  ? (v) => Validators.text(v, field: 'Password', min: 1)
                  : null,
            ),
            if (_challenge != null) ...[
              const SizedBox(height: AppSpacing.md),
              if (devCode != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: StatusBanner(
                    title: 'Development code',
                    message: 'No mailbox in dev; your code is $devCode.',
                    tone: BannerTone.info,
                    icon: Icons.key_outlined,
                  ),
                ),
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Confirmation code'),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : (_challenge == null ? _request : _confirm),
              child: Text(_challenge == null ? 'Send code' : 'Confirm change'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutSection extends StatelessWidget {
  const _PayoutSection();

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Payouts',
      footer: 'The partner API exposes no route to read or edit a bank account. '
        'Payout settings are managed by the platform. Open a support ticket '
        'to change them.',
      children: [
        SettingsTile(
          label: 'Payout account',
          description: 'Managed by the platform (read-only)',
          icon: Icons.account_balance_outlined,
          showChevron: false,
        ),
        SettingsTile(
          label: 'Contact support about payouts',
          icon: Icons.support_agent_outlined,
          onTap: () =>
              Navigator.of(context).pushReplacementNamed('${AppRoute.inbox}?tab=support'),
        ),
      ],
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: 'About',
      children: [
        const Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: BrandLockup(
              badgeHeight: 48,
              wordmarkHeight: 24,
              showEyebrow: true,
            ),
          ),
        ),
        SettingsTile(
          label: 'DineCircle Partner ${AppConfig.appVersion}',
          description: '${AppConfig.environment} · ${AppConfig.apiUrl}',
          icon: Icons.info_outline,
          showChevron: false,
        ),
        if (AppConfig.isDevelopment)
          SettingsTile(
            label: 'Configuration (debug)',
            description: 'Build-time dart-define values',
            icon: Icons.bug_report_outlined,
            onTap: () => _debug(context),
          ),
      ],
    );
  }

  void _debug(BuildContext context) {
    final map = AppConfig.toDebugMap();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in map.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SignOutSection extends ConsumerWidget {
  const _SignOutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingScreen,
        AppSpacing.lg,
        AppSpacing.paddingScreen,
        AppSpacing.md,
      ),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
        onPressed: () async {
          await ref.read(sessionProvider.notifier).signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoute.login,
              (route) => false,
            );
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign out of this device'),
      ),
    );
  }
}
