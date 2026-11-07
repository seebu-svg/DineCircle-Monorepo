import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/venue.dart';
import '../../providers/app_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/async_views.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';

/// Where a venue stands with verification, and the one way out of a rejection.
///
/// There is no per-field verification read on the API, so the timeline is built
/// from the venue's own `partnershipStatus` / `verified` / `profileCompletion`
/// — the same three flags every selling gate on the server depends on. A
/// rejected venue re-opens a request through the owner-only verification route.
class VerificationStatusScreen extends ConsumerWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(selectedVenueProvider);
    if (venue == null) {
      return const Scaffold(
        body: EmptyState(
          title: 'No venue selected',
          message: 'Register a restaurant to see its verification status.',
          icon: Icons.storefront,
        ),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(venue.name, style: AppTextStyles.headlineMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _StatusCard(venue: venue),
                  const SizedBox(height: AppSpacing.lg),
                  _Timeline(venue: venue),
                  if (venue.isRejected && venue.rejectionNote.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    StatusBanner(
                      title: 'Reviewer note',
                      message: venue.rejectionNote,
                      tone: BannerTone.warning,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (venue.profileCompletion < 100)
                    StatusBanner(
                      title: 'Profile ${venue.profileCompletion}% complete',
                      message:
                          'Add your description, hours, photos and menu so '
                          'guests can find and trust ${venue.name}.',
                      tone: BannerTone.info,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  _ResubmitButton(venueId: venue.id, status: venue.partnershipStatus),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final tone = venue.verified
        ? BannerTone.success
        : venue.isRejected
            ? BannerTone.danger
            : venue.isPendingReview
                ? BannerTone.info
                : BannerTone.warning;
    return StatusBanner(
      title: venue.statusLabel,
      message: switch (venue.partnershipStatus) {
        'verified' =>
          'Your venue is verified and can publish deals and sell experiences.',
        'pending_review' =>
          'Verification is with the DineCircle team. You can set up everything '
          'else meanwhile.',
        'rejected' =>
          'Verification was rejected. Fix the issues below and re-submit.',
        _ => 'Verification not started. Submit your venue for review to start '
            'selling.',
      },
      tone: tone,
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final steps = <(String, String, bool)>[
      ('Registered', 'Venue created and linked to you', true),
        (
          'Profile',
          'Description, location, hours and photos',
          venue.profileCompletion >= 60
        ),
        (
          'Submitted',
          'Verification request opened',
          venue.partnershipStatus != 'unverified'
        ),
        ('Verified', 'Approved by DineCircle', venue.verified),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Progress', style: AppTextStyles.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        for (final step in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  step.$3 ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22,
                  color: step.$3 ? AppColors.success : AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.$1, style: AppTextStyles.titleSmall),
                      Text(step.$2, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResubmitButton extends ConsumerWidget {
  const _ResubmitButton({required this.venueId, required this.status});

  final String venueId;
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(roleGateProvider);
    final canSubmit = status != 'verified';
    if (!canSubmit) return const SizedBox.shrink();
    return RoleGateBuilder(
      capability: Capability.registerVenue,
      builder: (context, allowed, denial) => FilledButton.icon(
        onPressed: allowed
            ? () async {
                final ok = await confirmAction(
                  context,
                  title: 'Submit for verification',
                  message: 'Ask the DineCircle team to review ${gate.role.label} '
                      'access and re-open verification for this venue?',
                  confirmLabel: 'Submit',
                );
                if (!ok || !context.mounted) return;
                try {
                  await ref
                      .read(venueRepositoryProvider)
                      .requestVerification(venueId);
                  await ref.read(venueScopeProvider.notifier).refresh();
                  if (context.mounted) {
                    showToast(context, 'Verification request submitted.');
                  }
                } catch (error) {
                  if (context.mounted) {
                    reportError(context, error, prefix: 'Could not submit:');
                  }
                }
              }
            : null,
        icon: const Icon(Icons.verified_outlined),
        label: Text(status == 'rejected' ? 'Re-submit for review' : 'Submit for review'),
      ),
    );
  }
}
