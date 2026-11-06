import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../providers/venue_scope_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Shows a control only if the caller's venue role allows it, and otherwise
/// shows the same control disabled with the reason attached.
///
/// Disabling rather than hiding is deliberate: a manager who cannot see that a
/// "Publish deal" button exists has no way to know to ask for an owner.
class RoleGateBuilder extends ConsumerWidget {
  const RoleGateBuilder({
    super.key,
    required this.capability,
    required this.builder,
    this.fallbackBuilder,
  });

  final Capability capability;

  /// Gets whether the action is allowed plus the denial text when it is not.
  final Widget Function(BuildContext context, bool allowed, String? denial)
  builder;

  /// Renders instead of [builder] when the control should not appear at all
  /// (used for owner-only administration, not for everyday buttons).
  final Widget Function(BuildContext context)? fallbackBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(roleGateProvider);
    final allowed = gate.can(capability);
    if (!allowed && fallbackBuilder != null) {
      return fallbackBuilder!(context);
    }
    final denial = allowed ? null : gate.denial(capability);
    final child = builder(context, allowed, denial);
    if (allowed || denial == null) return child;
    return Tooltip(message: denial, child: child);
  }
}

/// A yes/no confirmation for anything the desk cannot undo.
///
/// Returns `true` only on explicit confirm; the destructive variant labels its
/// own action so nobody taps "Cancel" meaning "cancel the booking".
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Not now',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Typed confirmation for an owner transfer, where a tap alone is not enough of
/// a signal that the operator means it.
Future<bool> confirmTyped(
  BuildContext context, {
  required String title,
  required String message,
  required String expected,
  String confirmLabel = 'Confirm',
}) async {
  final controller = TextEditingController();
  var matches = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Type $expected to confirm',
              helperText: 'Exactly: $expected',
            ),
            onChanged: (value) {
              matches = value.trim().toLowerCase() == expected.toLowerCase();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(context).pop(matches),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  return result ?? false;
}

/// A short message at the bottom of the screen.
///
/// Failures quote the server's own text: `409 This event is already confirmed`
/// is more useful to a desk than "something went wrong", and it is the reason
/// the exception keeps its status code.
void showToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.danger : AppColors.surfaceHigh,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 5 : 3),
    ),
  );
}

/// Reports an [ApiException] (or anything else) as a toast with the server's
/// message, so every screen handles a failed write the same way.
void reportError(BuildContext context, Object error, {String? prefix}) {
  final message = error is ApiException ? error.message : error.toString();
  showToast(context, prefix == null ? message : '$prefix $message', isError: true);
}

/// Copies a booking reference or ticket number, the two things a desk reads out
/// to a guest or quotes to support.
void copyToClipboard(BuildContext context, String value, String label) {
  Clipboard.setData(ClipboardData(text: value));
  showToast(context, '$label copied');
}

/// Section card used by every settings-style screen.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.paddingScreen,
            bottom: AppSpacing.sm,
            top: AppSpacing.lg,
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 1,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingScreen,
          ),
          child: Column(children: children),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.paddingScreen,
              AppSpacing.sm,
              AppSpacing.paddingScreen,
              0,
            ),
            child: Text(
              footer!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

/// A tappable settings row with a leading icon, optional trailing accessory.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.label,
    this.description,
    this.icon,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = true,
  });

  final String label;
  final String? description;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: icon == null
          ? null
          : Icon(icon, color: destructive ? AppColors.danger : AppColors.primary),
      title: Text(label, style: AppTextStyles.bodyLarge.copyWith(color: color)),
      subtitle: description == null
          ? null
          : Text(description!, style: AppTextStyles.bodySmall),
      trailing:
          trailing ??
          (onTap != null && showChevron
              ? const Icon(Icons.chevron_right, color: AppColors.textTertiary)
              : null),
    );
  }
}
