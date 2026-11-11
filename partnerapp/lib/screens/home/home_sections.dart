import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/collab.dart';
import '../../models/experience.dart';
import '../../navigation/app_routes.dart';
import '../../providers/module_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../widgets/status_chip.dart';

/// ─── Section header ────────────────────────────────────────────────────────

/// The title that opens every Home section, with an optional trailing action.
///
/// The label is set at reading size rather than as a letter-spaced overline:
/// a dashboard is scanned for its section names first, and an 11 sp capitalised
/// eyebrow was both harder to read and visually louder than the numbers under
/// it. One widget keeps the vertical rhythm identical in every section.
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

/// The compact "View all" style used beside a [SectionLabel].
class SectionLink extends StatelessWidget {
  const SectionLink({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: const Size(0, AppSpacing.minTapTarget),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: AppTextStyles.labelSmall.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      child: Text(label),
    );
  }
}

/// ─── Experiences ───────────────────────────────────────────────────────────

/// The venue's evening book in one card: the dinners it is hosting and the
/// host proposals still waiting on an answer.
///
/// Three independent reads feed it (the event feed, the host requests this
/// venue received and the invitations it sent), because the product keeps them
/// as three separate surfaces. Each half renders from whichever read actually
/// answered, and an unanswered half shows `-` rather than a confident zero, so
/// "nothing to do" can never be confused with "we could not look".
///
/// Rows are ordered by what the desk owes: a host request needs a decision, an
/// upcoming dinner is context, and an invitation waiting on a host is passive.
/// The card shows at most [maxRows] rows, so Home stays a summary and the full
/// lists live in the Experiences section.
class ExperiencesSection extends ConsumerWidget {
  const ExperiencesSection({super.key, required this.venueId});

  final String venueId;

  /// Home is a dashboard, not an inbox.
  static const int maxRows = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsKey = (venue: venueId, status: 'requested');
    final proposalsKey = (venue: venueId, direction: 'outgoing' as String?);

    final experiences = ref.watch(experiencesProvider(null));
    final incoming = ref.watch(eventRequestsProvider(requestsKey));
    final outgoing = ref.watch(collabProposalsProvider(proposalsKey));

    void retry() {
      ref.invalidate(experiencesProvider(null));
      ref.invalidate(eventRequestsProvider(requestsKey));
      ref.invalidate(collabProposalsProvider(proposalsKey));
    }

    void open(String route) =>
        Navigator.of(context).pushReplacementNamed(route);

    final upcoming = _upcomingFor(experiences.valueOrNull);
    final requests = incoming.valueOrNull;
    final awaiting = outgoing.valueOrNull
        ?.where((proposal) => proposal.awaitsHost)
        .toList();

    final answered = upcoming != null && requests != null && awaiting != null;
    final failed = experiences.hasError || incoming.hasError || outgoing.hasError;
    final loading =
        experiences.isLoading || incoming.isLoading || outgoing.isLoading;

    final candidates = <Widget>[
      for (final request in (requests ?? const <ExperienceRequest>[]).take(1))
        _SummaryRow(
          rowKey: ValueKey('home-exp-request-${request.id}'),
          icon: Icons.pending_actions,
          color: AppColors.warning,
          title: request.title,
          subtitle:
              '${request.hostName} · ${DisplayDate.dayLong(request.startAt)} '
              '${DisplayDate.time(request.startAt)}',
          chip: StatusChip(
            status: request.status.wire,
            label: 'Your decision',
            dense: true,
          ),
          onTap: () => open('${AppRoute.experiences}?tab=requests'),
        ),
      for (final event in (upcoming ?? const <PartnerExperience>[]).take(1))
        _SummaryRow(
          rowKey: ValueKey('home-exp-upcoming-${event.id}'),
          icon: Icons.auto_awesome,
          color: AppColors.primary,
          title: event.title,
          subtitle:
              '${DisplayDate.dateTime(event.startAt)} · '
              '${event.seatsBooked}/${event.seatsTotal} seats',
          chip: StatusChip(
            status: event.status.wire,
            label: event.status.label,
            dense: true,
          ),
          onTap: () => open('${AppRoute.experiences}?tab=experiences'),
        ),
      for (final proposal in (awaiting ?? const <CollabProposal>[]).take(1))
        _SummaryRow(
          rowKey: ValueKey('home-exp-awaiting-${proposal.id}'),
          icon: Icons.outbound,
          color: AppColors.info,
          title: proposal.title,
          subtitle: 'Waiting on ${proposal.counterpartLabel}',
          chip: StatusChip(
            status: proposal.statusTone,
            label: proposal.status.label,
            dense: true,
          ),
          onTap: () => open('${AppRoute.experiences}?tab=proposals'),
        ),
    ];
    final rows = candidates.take(maxRows).toList();

    final Widget body;
    if (answered && rows.isEmpty) {
      body = SectionEmpty(
        icon: Icons.auto_awesome_outlined,
        title: 'No experiences yet',
        message: 'Host a dinner or review a host proposal to fill this slot.',
        actionLabel: 'Create experience',
        onAction: () =>
            open('${AppRoute.experiences}?tab=experiences&create=1'),
      );
    } else if (!answered && rows.isEmpty) {
      body = loading
          ? const SectionSkeleton(rows: 2)
          : SectionError(
              message: 'Unable to load experiences',
              onRetry: retry,
            );
    } else {
      body = Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCount(
                        countKey: const ValueKey('home-exp-count-upcoming'),
                        value: upcoming?.length,
                        label: 'Upcoming',
                        onTap: () =>
                            open('${AppRoute.experiences}?tab=experiences'),
                      ),
                    ),
                    _CounterDivider(),
                    Expanded(
                      child: _SummaryCount(
                        countKey: const ValueKey('home-exp-count-to-review'),
                        value: requests?.length,
                        label: 'To review',
                        onTap: () =>
                            open('${AppRoute.experiences}?tab=requests'),
                      ),
                    ),
                    _CounterDivider(),
                    Expanded(
                      child: _SummaryCount(
                        countKey: const ValueKey('home-exp-count-awaiting'),
                        value: awaiting?.length,
                        label: 'Awaiting host',
                        onTap: () =>
                            open('${AppRoute.experiences}?tab=proposals'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: AppColors.border),
            if (rows.isEmpty)
              _UnavailableRow(onRetry: retry)
            else
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                    color: AppColors.border,
                  ),
                rows[i],
              ],
            if (failed && rows.isNotEmpty) _PartialFailure(onRetry: retry),
          ],
        ),
      );
    }

    return Column(
      key: const ValueKey('home-experiences'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(
          title: 'Experiences',
          trailing: SectionLink(
            label: 'View all',
            onPressed: () =>
                open('${AppRoute.experiences}?tab=experiences'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        body,
      ],
    );
  }

  /// This venue's dinners that are still ahead of the clock, soonest first.
  ///
  /// The partner feed is account-wide, so another venue's dinner is filtered
  /// out rather than being presented as this desk's evening.
  List<PartnerExperience>? _upcomingFor(List<PartnerExperience>? rows) {
    if (rows == null) return null;
    final now = DateTime.now();
    return rows
        .where(
          (event) =>
              event.restaurantId == venueId &&
              event.status.isUpcoming &&
              event.startAt.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }
}

/// One figure from the evening book. A `null` count means that read has not
/// answered, and it renders as `-` instead of a zero.
class _SummaryCount extends StatelessWidget {
  const _SummaryCount({
    required this.countKey,
    required this.value,
    required this.label,
    required this.onTap,
  });

  final Key countKey;
  final int? value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final measured = value != null;
    final radius = BorderRadius.circular(AppSpacing.radiusSm);
    return InkWell(
      key: countKey,
      onTap: onTap,
      borderRadius: radius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                measured ? '$value' : '-',
                style: AppTextStyles.numericMedium.copyWith(
                  fontSize: 20,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: measured
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: AppColors.border);
  }
}

/// One evening item. Taps through to the surface that owns it.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.rowKey,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.onTap,
  });

  final Key rowKey;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // At a large text scale the trailing pill steals the width the title needs,
    // so the chip steps back and the row keeps reading.
    final showChip = MediaQuery.textScalerOf(context).scale(1) < 1.6;
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (showChip) ...[
              const SizedBox(width: AppSpacing.sm),
              chip,
            ],
          ],
        ),
      ),
    );
  }
}

/// The card answered, but one of its three reads did not. The failing half
/// says so here instead of blanking the whole section.
class _PartialFailure extends StatelessWidget {
  const _PartialFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Some experiences could not load.',
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Counters answered with nothing under them: one quiet line, one retry.
class _UnavailableRow extends StatelessWidget {
  const _UnavailableRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Nothing open right now.',
              style: AppTextStyles.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: AppTextStyles.labelSmall.copyWith(fontSize: 12),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

/// ─── Section states ────────────────────────────────────────────────────────

/// Inline empty state: one line of truth plus the action that changes it.
///
/// Deliberately compact. A full-height illustration and a three-sentence
/// explanation on the busiest screen of the app pushed the real work below the
/// fold to describe the absence of work.
class SectionEmpty extends StatelessWidget {
  const SectionEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.textTertiary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTextStyles.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: AppTextStyles.labelSmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// A failed section read. Home keeps working around it: this banner replaces
/// only its own block and carries its own retry.
class SectionError extends StatelessWidget {
  const SectionError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StatusBanner(
      message: message,
      tone: BannerTone.danger,
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

/// Placeholder rows shaped like the content they replace.
class SectionSkeleton extends StatelessWidget {
  const SectionSkeleton({super.key, this.rows = 1, this.height = 56});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ],
      ],
    );
  }
}
