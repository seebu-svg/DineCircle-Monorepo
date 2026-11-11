
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/brand.dart';

/// Partner email and password sign-in.
/// The root AuthGate handles navigation after authentication.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      await ref.read(sessionProvider.notifier).signIn(
        email: _email.text.trim(),
        password: _password.text,
      );

      // No navigation here on purpose: this screen is rendered by [AuthGate],
      // which swaps itself for the workspace as soon as the session becomes
      // signed in.
      if (!mounted) return;
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_readableError(error)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _readableError(Object error) {
    final text = error.toString();

    if (text.contains('401') ||
        text.toLowerCase().contains('invalid')) {
      return 'Incorrect email or password. Please try again.';
    }

    return text.replaceFirst('ApiException', 'Sign-in failed');
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        size: 20,
        color: AppColors.textSecondary,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 650;
            final horizontalPadding =
                constraints.maxWidth < 360 ? 18.0 : 24.0;

            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isCompact ? 20 : 32,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight -
                          (isCompact ? 40 : 64))
                      .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const BrandLockup(
                            badgeHeight: 56,
                            wordmarkHeight: 32,
                            showEyebrow: true,
                          ),

                          SizedBox(height: isCompact ? 24 : 36),

                          Text(
                            'Welcome back',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Sign in to manage your restaurant.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),

                          SizedBox(height: isCompact ? 28 : 40),

                          Text(
                            'Email address',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: _inputDecoration(
                              label: 'Enter your email',
                              icon: Icons.mail_outline_rounded,
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';

                              if (email.isEmpty) {
                                return 'Email is required';
                              }

                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(email)) {
                                return 'Enter a valid email address';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          Text(
                            'Password',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: _obscure,
                            autofillHints: const [
                              AutofillHints.password,
                            ],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: _inputDecoration(
                              label: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              suffix: IconButton(
                                tooltip: _obscure
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () {
                                  setState(
                                    () => _obscure = !_obscure,
                                  );
                                },
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 28),

                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.primary.withValues(
                                alpha: 0.5,
                              ),
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 28),

                          Divider(
                            color: AppColors.border.withValues(alpha: 0.7),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            'New to DineCircle Partner?',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Contact DineCircle to get started with '
                            'your restaurant account.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 24),

                          Text(
                            'DineCircle Partner',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
