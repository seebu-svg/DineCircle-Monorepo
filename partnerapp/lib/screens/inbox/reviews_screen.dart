import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comms.dart';
import '../../providers/module_providers.dart';
import '../../providers/app_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../widgets/async_views.dart';
import '../../widgets/premium_cards.dart';

/// Venue-scoped guest reviews (`GET /partner/restaurants/:id/reviews`).
///
/// The partner picks the active venue and reads all reviews for it. Aggregate
/// rating and count come from the venue detail record. Partners can reply to
/// any review via `PATCH /partner/restaurants/:id/reviews/:reviewId/reply`.
class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  @override
  Widget build(BuildContext context) {
    final venueId = ref.watch(selectedVenueIdProvider);
    final detail = ref.watch(venueDetailProvider(venueId));
    final reviewsAsync = ref.watch(venueReviewsProvider(venueId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.md,
            AppSpacing.paddingScreen,
            AppSpacing.sm,
          ),
          child: detail.maybeWhen(
            data: (d) => _AggregateHeader(
              rating: d.venue.rating,
              count: d.venue.reviewCount,
            ),
            orElse: () => Text(
              'Reviews',
              style: AppTextStyles.headlineSmall,
            ),
          ),
        ),
        Expanded(
          child: AsyncView<List<PartnerReview>>(
            value: reviewsAsync,
            onRetry: () => ref.invalidate(venueReviewsProvider(venueId)),
            emptyState: const EmptyState(
              title: 'No reviews yet',
              message: 'Guests who dine at your restaurant can leave a '
                  'rating and a note here.',
              icon: Icons.reviews_outlined,
            ),
            builder: (context, rows) => RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(venueReviewsProvider(venueId)),
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.paddingScreen),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final review = rows[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ReviewTile(
                      review: review,
                      restaurantId: venueId,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AggregateHeader extends StatelessWidget {
  const _AggregateHeader({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          rating.toStringAsFixed(1),
          style: AppTextStyles.numericLarge.copyWith(color: AppColors.warning),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(Icons.star, color: AppColors.warning, size: 18),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$count review${count == 1 ? '' : 's'} \u00b7 venue average',
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ReviewTile extends ConsumerStatefulWidget {
  const _ReviewTile({required this.review, required this.restaurantId});

  final PartnerReview review;
  final String restaurantId;

  @override
  ConsumerState<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends ConsumerState<_ReviewTile> {
  bool _showReplyBox = false;
  bool _submitting = false;
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(businessRepositoryProvider);
      await repo.replyToReview(
        restaurantId: widget.restaurantId,
        reviewId: widget.review.id,
        reply: text,
      );
      if (mounted) {
        setState(() {
          _showReplyBox = false;
          _submitting = false;
          _replyController.clear();
        });
        ref.invalidate(venueReviewsProvider(widget.restaurantId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply posted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not post reply: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    return PremiumCard(
      padding: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author + rating row
            Row(
              children: [
                Expanded(
                  child: Text(r.authorLabel, style: AppTextStyles.bodyLarge),
                ),
                _Stars(rating: r.rating),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Review text
            Text(
              r.text.isEmpty ? 'Rated without a comment.' : r.text,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Timestamp
            Text(
              DisplayDate.full(r.createdAt),
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textTertiary),
            ),
            // Existing partner reply
            if (r.hasPartnerReply) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.reply,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Your reply',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.partnerReply!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Reply composer or button
            const SizedBox(height: AppSpacing.sm),
            if (_showReplyBox) ...[
              TextField(
                controller: _replyController,
                enabled: !_submitting,
                maxLines: 3,
                maxLength: 1000,
                style: AppTextStyles.bodySmall,
                decoration: InputDecoration(
                  hintText: 'Write your reply\u2026',
                  hintStyle: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(AppSpacing.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                              _showReplyBox = false;
                              _replyController.clear();
                            }),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submitReply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Post reply'),
                  ),
                ],
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () => setState(() => _showReplyBox = true),
                icon: const Icon(Icons.reply, size: 20),
                label: Text(
                  r.hasPartnerReply ? 'Update reply' : 'Reply',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: AppTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star : Icons.star_border,
            size: 16,
            color: AppColors.warning,
          ),
      ],
    );
  }
}
