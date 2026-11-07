import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_routes.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/brand.dart';

/// First-launch onboarding carousel.
///
/// Four slides introduce the partner app's value proposition. The carousel
/// only appears when `dinecircle.onboardingSeen` has not yet been written to
/// [SharedPreferences], so returning users skip straight to [AuthGate].
///
/// The final slide offers *Get Started* (navigate to registration) and *Log in*
/// (navigate to the existing login screen). Every earlier slide shows *Skip*
/// and *Next* so the desk can move at their own pace.
class OnboardingCarousel extends ConsumerStatefulWidget {
  const OnboardingCarousel({super.key});

  @override
  ConsumerState<OnboardingCarousel> createState() =>
      _OnboardingCarouselState();
}

class _OnboardingCarouselState extends ConsumerState<OnboardingCarousel> {
  final _controller = PageController();
  int _page = 0;

  static const _totalSlides = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _totalSlides - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skip() {
    _controller.animateToPage(
      _totalSlides - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Mark onboarding as seen so it never shows again on this device.
  Future<void> _markSeen() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool('dinecircle.onboardingSeen', true);
  }

  Future<void> _getStarted() async {
    await _markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoute.registration);
  }

  Future<void> _logIn() async {
    await _markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoute.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip button ───────────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _page < _totalSlides - 1
                    ? TextButton(
                        onPressed: _skip,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : const SizedBox(
                        height: AppSpacing.minTapTarget,
                        width: AppSpacing.minTapTarget,
                      ),
              ),
            ),

            // ── Slides ──────────────────────────────────────────────────
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    final page = (_controller.page ?? 0).round();
                    if (page != _page) {
                      setState(() => _page = page);
                    }
                  }
                  return false;
                },
                child: PageView(
                  controller: _controller,
                  children: const [
                    _Slide(
                      icon: Icons.explore_rounded,
                      title: 'Your restaurant, discovered',
                      description:
                          'Help diners explore your restaurant, menu and '
                          'location.',
                    ),
                    _Slide(
                      icon: Icons.local_offer_rounded,
                      title: 'Turn offers into visits',
                      description:
                          'Share deals that give diners a reason to visit.',
                    ),
                    _Slide(
                      icon: Icons.groups_rounded,
                      title: 'Bring people together',
                      description:
                          'Welcome guests through reservations and dining '
                          'experiences.',
                    ),
                    _Slide(
                      icon: Icons.dashboard_rounded,
                      title: 'Manage it all in one place',
                      description:
                          'Update your menu and track your restaurant\'s '
                          'performance.',
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer: dots + action buttons ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  _ProgressDots(current: _page, total: _totalSlides),
                  const SizedBox(height: AppSpacing.lg),
                  if (_page < _totalSlides - 1)
                    // Next button on slides 0-2
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  else
                    // Final slide: Get Started + Log in
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _getStarted,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _logIn,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                color: AppColors.border,
                              ),
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Log in',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One onboarding slide: brand lockup, icon illustration, title and description.
class _Slide extends StatelessWidget {
  const _Slide({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.paddingScreen,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BrandLockup(
            badgeHeight: 56,
            wordmarkHeight: 30,
            showEyebrow: true,
          ),
          const SizedBox(height: AppSpacing.xxl),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSheet),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.displaySmall.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated progress dots indicating the current slide.
class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.borderLight,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
        );
      }),
    );
  }
}
