import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/deals.dart';
import '../../models/venue.dart';
import '../../navigation/app_routes.dart';
import '../../providers/app_providers.dart';
import '../../providers/module_providers.dart';
import '../../providers/venue_scope_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../utils/validators.dart';
import '../../widgets/async_views.dart';
import '../../widgets/image_upload_field.dart';
import '../../widgets/premium_feedback.dart';
import '../../widgets/role_gate_builder.dart';
import '../../widgets/status_chip.dart';
import 'deals_widgets.dart';

/// Phrases that answer "which days and hours?" without inventing a column for
/// them. The platform has no structured window on a deal, and the Customer App
/// renders `terms` verbatim under Conditions, so these compose into that text.
const List<String> _conditionPresets = [
  'Mon–Fri',
  'Weekends only',
  '19:00–23:00',
  'Dine-in only',
  'One offer per table',
  'Excludes public holidays',
];

/// Venue promotions (`…/deals`), driven entirely by the transition map.
///
/// Create is disabled with a reason while the venue is unverified: the server
/// answers `403` for any deal write, including a draft, whoever asks, so that
/// gate is the `verified` flag rather than [Capability.manageDeals] alone.
/// Lifecycle buttons come from [Deal.allowedTransitions], so the desk never taps
/// a move that would return `409`; delete means "drop the draft", anything that
/// has been live is retired to `expired`.
///
/// Status filtering happens here rather than through the endpoint because the
/// figures above the list must describe the whole venue, and a partner tapping
/// between chips should not wait on four reads to see the same rows.
class DealsTab extends ConsumerStatefulWidget {
  const DealsTab({super.key});

  @override
  ConsumerState<DealsTab> createState() => _DealsTabState();
}

class _DealsTabState extends ConsumerState<DealsTab> {
  /// The one list that scrolls. Header, action, filters and status rail stay
  /// pinned, and this controller is what lets a filter reset the view to the
  /// top without rebuilding the whole screen.
  final ScrollController _listScroll = ScrollController();

  DealStatus? _status;
  bool _expiringOnly = false;
  bool _byPopularity = false;

  /// Deal ids with a write in flight, so one card cannot fire twice while its
  /// first answer is still travelling.
  final Set<String> _busyDeals = {};

  bool _autoCreateHandled = false;

  @override
  void dispose() {
    _listScroll.dispose();
    super.dispose();
  }

  ({String venue, String? status}) _key(String venueId) =>
      (venue: venueId, status: null);

  @override
  void initState() {
    super.initState();
    // `/business?tab=deals&create=1` (the Home "Add Deal" tile) opens straight
    // into the creation form. The rules stay here: an unverified venue or a
    // role that may not manage deals keeps the disabled "New Deal" button.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenCreateForm());
  }

  Future<void> _maybeOpenCreateForm() async {
    if (_autoCreateHandled || !mounted) return;
    if (routeQuery(context)['create'] != '1') return;
    _autoCreateHandled = true;
    final venue = ref.read(selectedVenueProvider);
    if (venue == null || !venue.verified) return;
    if (!ref.read(roleGateProvider).can(Capability.manageDeals)) return;
    await _openForm(venue.id);
  }

  bool get _filtering => _status != null || _expiringOnly || _byPopularity;

  void _clearFilters() {
    setState(() {
      _status = null;
      _expiringOnly = false;
      _byPopularity = false;
    });
    _scrollToTop();
  }

  /// One status at a time, the way the chips read. A second tap on the chip
  /// that is already lit clears it, so the way back to the whole list is always
  /// the chip the partner just pressed.
  void _selectStatus(DealStatus? status) {
    setState(() {
      final same = _status == status && !_expiringOnly;
      _status = same ? null : status;
      _expiringOnly = false;
    });
    _scrollToTop();
  }

  void _selectExpiring() {
    setState(() {
      _status = null;
      _expiringOnly = !_expiringOnly;
    });
    _scrollToTop();
  }

  /// Redemptions is a figure to order by, not a state to filter on: an expired
  /// deal can hold the highest count, and hiding it would answer a different
  /// question than the one the tap asked.
  void _togglePopularity() {
    setState(() => _byPopularity = !_byPopularity);
    _scrollToTop();
  }

  void _scrollToTop() {
    if (_listScroll.hasClients) _listScroll.jumpTo(0);
  }

  /// Narrows the loaded set, then orders it the way the endpoint does: live
  /// offers first, soonest to end next.
  List<Deal> _visible(List<Deal> all) {
    final rows = all
        .where(
          (deal) =>
              (_status == null || deal.status == _status) &&
              (!_expiringOnly || deal.isExpiringSoon),
        )
        .toList();
    if (_byPopularity) {
      rows.sort((a, b) => b.redemptions.compareTo(a.redemptions));
      return rows;
    }
    int rank(Deal deal) => switch (deal.status) {
      DealStatus.active => 0,
      DealStatus.draft => 1,
      DealStatus.paused => 2,
      DealStatus.expired => 3,
    };
    rows.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.endsAt.compareTo(b.endsAt);
    });
    return rows;
  }

  Future<void> _refresh(String venueId) async {
    try {
      ref.invalidate(dealsProvider(_key(venueId)));
      await ref.read(dealsProvider(_key(venueId)).future);
    } catch (error) {
      if (mounted) {
        reportError(context, error, prefix: 'Could not refresh deals:');
      }
    }
  }

  /// Runs one write against one deal, holding the card busy while it travels.
  ///
  /// Every mutation funnels through here so the three things a write always
  /// needs, the busy flag, the reload and the error sentence, cannot be
  /// half-implemented by a new button added later.
  Future<void> _write(
    String venueId,
    Deal deal,
    Future<void> Function() action, {
    String? success,
    required String failure,
  }) async {
    if (!_busyDeals.add(deal.id)) return;
    // Say it now rather than when the answer lands: the card is the only place
    // a double tap could happen, and it has to close for business first.
    if (mounted) setState(() {});
    try {
      await action();
      ref.invalidate(dealsProvider(_key(venueId)));
      if (mounted && success != null) showToast(context, success);
    } catch (error) {
      if (mounted) reportError(context, error, prefix: failure);
    } finally {
      _busyDeals.remove(deal.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _setStatus(String venueId, Deal deal, DealStatus next) async {
    if (!deal.allowedTransitions.contains(next)) return;
    final verified = ref.read(selectedVenueProvider)?.verified ?? false;
    if (next == DealStatus.active) {
      // The publish route repeats both checks server-side; refusing here keeps
      // the partner out of a 403 or 409 they cannot act on.
      if (!verified) {
        showToast(
          context,
          'Verify this venue before publishing deals.',
          isError: true,
        );
        return;
      }
      if (deal.hasPassed) {
        showToast(
          context,
          'This deal has already ended. Edit its dates first.',
          isError: true,
        );
        return;
      }
      // Resuming is not publishing: the offer already ran, so the sentence has
      // to describe putting it back rather than launching it for the first time.
      final resuming = deal.status == DealStatus.paused;
      final ok = await confirmAction(
        context,
        title: resuming
            ? 'Show this deal to guests again?'
            : 'Publish to guests?',
        message: resuming
            ? '“${deal.title}” goes live again with the same dates and the '
                  'same redemption count.'
            : '“${deal.title}” appears in the DineCircle Customer App as soon '
                  'as you publish it.',
        confirmLabel: resuming ? 'Resume' : 'Publish',
      );
      if (!ok || !mounted) return;
    }
    if (next == DealStatus.expired) {
      final ok = await confirmAction(
        context,
        title: 'Retire this deal?',
        message:
            '“${deal.title}” stops showing to guests and cannot be brought '
            'back. Its redemption count is kept.',
        confirmLabel: 'Retire',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    final label = switch (next) {
      DealStatus.active =>
        deal.status == DealStatus.paused
        ? 'Deal resumed.'
        : 'Deal published · live in the Customer App.',
      DealStatus.paused => 'Deal paused · hidden from guests.',
      DealStatus.expired => 'Deal retired.',
      DealStatus.draft => 'Deal moved to draft.',
    };
    await _write(
      venueId,
      deal,
      () => ref
          .read(businessRepositoryProvider)
          .updateDeal(venueId, deal.id, status: next),
      success: label,
      failure: 'Could not update deal:',
    );
  }

  Future<void> _delete(String venueId, Deal deal) async {
    if (!deal.isDeleteable) return;
    final ok = await confirmAction(
      context,
      title: 'Delete draft?',
      message: '“${deal.title}” will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _write(
      venueId,
      deal,
      () => ref
          .read(businessRepositoryProvider)
          .deleteDeal(venueId, deal.id)
          .then((_) {}),
      success: 'Draft deleted.',
      failure: 'Could not delete deal:',
    );
  }

  /// Counts one guest use, after a confirmation that states the new figure.
  ///
  /// The tap has no undo and the count is what the venue reports to DineCircle,
  /// so the dialog quotes the numbers: confirming "12 of 200 → 13 of 200" is
  /// what stops a mis-tap from silently eating another table's discount.
  Future<void> _redeem(String venueId, Deal deal) async {
    if (!deal.isRedeemable) return;
    final cap = deal.maxRedemptions;
    final ok = await confirmAction(
      context,
      title: 'Count one redemption?',
      message: cap == null
          ? '${deal.title} · ${deal.redemptions} recorded so far. This adds '
                'one more.'
          : '${deal.title} · ${deal.redemptions} of $cap uses recorded. This '
                'adds one, leaving ${deal.redemptionsLeft}.',
      confirmLabel: 'Record',
    );
    if (!ok || !mounted) return;
    String? success;
    await _write(
      venueId,
      deal,
      () async {
        final updated = await ref
            .read(businessRepositoryProvider)
            .redeemDeal(venueId, deal.id);
        final left = updated.redemptionsLeft;
        success = left == null
            ? 'Redemption recorded · ${updated.redemptions} used.'
            : 'Redemption recorded · $left of ${updated.maxRedemptions} left.';
      },
      // The server refuses with the exact guard that tripped (paused, ended,
      // limit reached), and `reportError` surfaces that sentence verbatim.
      failure: 'Could not record redemption:',
    );
    if (mounted && success != null) showToast(context, success!);
  }

  Future<void> _openForm(String venueId, {Deal? deal, DealDraftInput? preset}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) =>
          _DealFormSheet(venueId: venueId, draft: deal, preset: preset),
    );
    if (saved != true || !mounted) return;
    showToast(
      context,
      switch ((deal, preset)) {
        (_, _) when preset != null => 'Copy created as a draft.',
        (null, _) => 'Deal created as draft.',
        (final Deal row, _) => row.isDraft
            ? 'Draft updated.'
            : 'Deal updated · guests see the change immediately.',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final venue = ref.watch(selectedVenueProvider);
    final venueId = venue?.id ?? '';
    final deals = ref.watch(dealsProvider(_key(venueId)));
    final gate = ref.watch(roleGateProvider);
    // Verification, not only the role: the server refuses any deal write for an
    // unverified venue, so a manager there can read but not act.
    final verified = venue?.verified ?? false;
    final canManage = gate.can(Capability.manageDeals) && verified;
    final canRecord = gate.can(Capability.recordRedemptions);

    // One read drives the whole surface, so loading, error and data are the
    // same three branches the Menu screen uses. A header confidently reporting
    // "0 active" while the first read is still travelling is a figure a partner
    // would act on, which is why the skeleton owns the frame instead.
    return deals.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const DealsSkeleton(),
      error: (error, _) => _readError(
        venueId,
        error,
        canManage: canManage && venueId.isNotEmpty,
        reason: _addReason(venue, verified),
      ),
      data: (all) => _buildDeals(
        context,
        venue: venue,
        venueId: venueId,
        all: all,
        canManage: canManage,
        canRecord: canRecord,
        verified: verified,
      ),
    );
  }

  /// One scroll view for the whole screen.
  ///
  /// The header, the action and the rail used to sit in a fixed column above
  /// the list. That held until the text scale grew: at 2x on a short phone, or
  /// with the keyboard open, the chrome alone was taller than the viewport and
  /// the cards were pushed out of it. Now the header scrolls away and the rail
  /// sticks to the top, so the control that narrows the list stays in reach
  /// without the column ever holding more than it can.
  Widget _buildDeals(
    BuildContext context, {
    required Venue? venue,
    required String venueId,
    required List<Deal> all,
    required bool canManage,
    required bool canRecord,
    required bool verified,
  }) {
    final summary = DealSummary.of(all);
    // Narrow phones get tighter chrome so the card content keeps its room.
    final horizontal = MediaQuery.sizeOf(context).width < 360
        ? AppSpacing.md
        : AppSpacing.paddingScreen;
    final visible = _visible(all);
    final truncated = all.length >= kDealPageLimit;

    return RefreshIndicator(
      onRefresh: () => _refresh(venueId),
      child: CustomScrollView(
        controller: _listScroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              AppSpacing.md,
              horizontal,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: DealsHeaderCard(
                venue: venue,
                description: _description(venue, all),
                summary: summary,
                selectedStatus: _status,
                byPopularity: _byPopularity,
                onSelectStatus: _selectStatus,
                onTogglePopularity: _togglePopularity,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            sliver: SliverToBoxAdapter(
              child: DealsActionBar(
                canManage: canManage && venueId.isNotEmpty,
                onAdd: () => _openForm(venueId),
                reason: _addReason(venue, verified),
              ),
            ),
          ),
          if (all.isNotEmpty)
            SliverPersistentHeader(
              pinned: true,
              delegate: _StatusRailBand(
                inset: horizontal,
                selected: _status,
                expiringOnly: _expiringOnly,
                onSelect: _selectStatus,
                onExpiring: _selectExpiring,
              ),
            ),
          if (!verified)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.md,
                horizontal,
                0,
              ),
              sliver: const SliverToBoxAdapter(child: _VerificationNotice()),
            ),
          if (all.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.lg,
                horizontal,
                AppSpacing.xl,
              ),
              sliver: SliverToBoxAdapter(
                child: _emptyBody(venueId, canManage),
              ),
            )
          else ...[
            if (_filtering)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.md,
                  horizontal,
                  AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: DealsFilterSummary(
                    caption: _filterCaption(visible.length),
                    onClear: _clearFilters,
                  ),
                ),
              ),
            if (visible.isEmpty)
              // A filter that matches nothing needs its own exit, or the
              // partner is left on a blank list with no way back.
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.lg,
                  horizontal,
                  AppSpacing.xl,
                ),
                sliver: SliverToBoxAdapter(child: _noMatches()),
              )
            else
              // One lazy sliver, so a two-hundred-deal venue does not build two
              // hundred cards to show the first three.
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  _filtering ? 0 : AppSpacing.md,
                  horizontal,
                  AppSpacing.xl,
                ),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.marginItem),
                  itemBuilder: (context, index) => _card(
                    context,
                    venue: venue,
                    venueId: venueId,
                    deal: visible[index],
                    canManage: canManage,
                    canRecord: canRecord,
                  ),
                ),
              ),
            if (truncated)
              // Past the last card: the read hit the page ceiling, so the
              // figures describe this page, not the whole venue.
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.marginItem,
                  horizontal,
                  AppSpacing.xl,
                ),
                sliver: const SliverToBoxAdapter(
                  child: InlineNotice(
                    message:
                        'This venue has more than 200 deals. The figures above '
                        'cover the most recent 200.',
                    kind: InlineNoticeKind.warning,
                    icon: Icons.info_outline_rounded,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Why New deal is disabled, in the order the checks run.
  String _addReason(Venue? venue, bool verified) {
    if (venue == null) return 'Choose a venue first';
    if (!verified) return 'Verify this venue before creating deals';
    return 'Deal management is not available for this account';
  }

  /// What the screen is for, in the venue's own terms.
  String _description(Venue? venue, List<Deal> all) {
    if (venue == null) return 'Choose a venue to manage its offers.';
    if (all.isEmpty) {
      return 'Create an offer, then publish it to the Customer App.';
    }
    return 'Offers guests see in the Customer App at ${venue.name}.';
  }

  Widget _emptyBody(String venueId, bool canManage) {
    return EmptyState(
      title: 'No deals yet',
      message:
          'Create a promotion with New deal. It stays a draft until you '
          'publish it, so nothing reaches guests by accident.',
      icon: Icons.local_offer_outlined,
      compact: true,
      action: canManage
          ? FilledButton.icon(
              onPressed: () => _openForm(venueId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New deal'),
            )
          : null,
    );
  }

  Widget _card(
    BuildContext context, {
    required Venue? venue,
    required String venueId,
    required Deal deal,
    required bool canManage,
    required bool canRecord,
  }) {
    final venueName = venue?.name ?? 'This venue';
    return DealCard(
      key: ValueKey(deal.id),
      deal: deal,
      busy: _busyDeals.contains(deal.id),
      canManage: canManage,
      // The card decides for itself whether the offer can be redeemed right
      // now; the screen only says whether this account may count a use.
      canRedeem: canRecord,
      onOpen: () => _openDetails(
        context,
        venue: venue,
        deal: deal,
        canManage: canManage,
        canRecord: canRecord,
      ),
      onEdit: () => _openForm(venueId, deal: deal),
      onDuplicate: () => _openForm(venueId, preset: deal.copyToDraft()),
      onPreview: () => showDealPreview(
        context,
        deal: deal,
        venueName: venueName,
      ),
      onStatus: (next) => _setStatus(venueId, deal, next),
      onDelete: () => _delete(venueId, deal),
      onRedeem: () => _redeem(venueId, deal),
    );
  }

  Future<void> _openDetails(
    BuildContext context, {
    required Venue? venue,
    required Deal deal,
    required bool canManage,
    required bool canRecord,
  }) {
    final venueId = venue?.id ?? '';
    final venueName = venue?.name ?? 'This venue';
    return showDealDetails(
      context,
      deal: deal,
      venueName: venueName,
      canManage: canManage,
      canRedeem: canRecord,
      busy: _busyDeals.contains(deal.id),
      onEdit: () => _openForm(venueId, deal: deal),
      onDuplicate: () => _openForm(venueId, preset: deal.copyToDraft()),
      onPreview: () => showDealPreview(
        context,
        deal: deal,
        venueName: venueName,
      ),
      onDelete: () => _delete(venueId, deal),
      onStatus: (next) => _setStatus(venueId, deal, next),
      onRedeem: () => _redeem(venueId, deal),
    );
  }

  Widget _noMatches() {
    return EmptyState(
      title: 'No deals match this filter',
      message: _expiringOnly
          ? 'Nothing is ending within the next 7 days.'
          : 'Nothing is in this state right now.',
      icon: Icons.filter_alt_off_outlined,
      compact: true,
      action: OutlinedButton.icon(
        onPressed: _clearFilters,
        icon: const Icon(Icons.clear_all),
        label: const Text('Clear filters'),
      ),
    );
  }

  /// One sentence naming what the list is showing and how it is ordered.
  String _filterCaption(int count) {
    final scope = _expiringOnly
        ? 'Ending within 7 days'
        : switch (_status) {
            null => 'All deals',
            DealStatus.draft => 'Drafts',
            final status => '${status.label} deals',
          };
    final sort = _byPopularity ? ' · most redeemed first' : '';
    return '$scope · $count ${count == 1 ? 'deal' : 'deals'}$sort';
  }

  /// A failed read says so, but keeps the one action the partner may still
  /// take: a list nobody can read does not stop a new draft from being written.
  Widget _readError(
    String venueId,
    Object error, {
    required bool canManage,
    required String reason,
  }) {
    return RefreshIndicator(
      onRefresh: () => _refresh(venueId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.paddingScreen),
        children: [
          DealsActionBar(
            canManage: canManage,
            onAdd: () => _openForm(venueId),
            reason: reason,
          ),
          const SizedBox(height: AppSpacing.xl),
          ErrorView(
            error: error,
            onRetry: () => ref.invalidate(dealsProvider(_key(venueId))),
          ),
        ],
      ),
    );
  }
}

/// The status rail, pinned while the cards scroll.
///
/// Only the rail sticks: the header and the action above it are taller than a
/// phone keyboard leaves room for at 2x text, so they travel with the list
/// while the control that narrows it stays put. The band paints the page
/// colour, or the cards would slide visibly through the gaps between chips.
class _StatusRailBand extends SliverPersistentHeaderDelegate {
  const _StatusRailBand({
    required this.inset,
    required this.selected,
    required this.expiringOnly,
    required this.onSelect,
    required this.onExpiring,
  });

  final double inset;
  final DealStatus? selected;
  final bool expiringOnly;
  final void Function(DealStatus? status) onSelect;
  final VoidCallback onExpiring;

  static const double _extent = AppSpacing.minTapTarget - 8;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppColors.bg,
      child: DealStatusRail(
        selected: selected,
        expiringOnly: expiringOnly,
        onSelect: onSelect,
        onExpiring: onExpiring,
        horizontalInset: inset,
      ),
    );
  }

  @override
  bool shouldRebuild(_StatusRailBand old) =>
      old.inset != inset ||
      old.selected != selected ||
      old.expiringOnly != expiringOnly;
}

/// Why an unverified venue can only read this screen.
///
/// The server refuses every deal write for an unverified venue, so this says so
/// once, in the same words the disabled action uses, rather than letting the
/// partner discover it from a `403`.
class _VerificationNotice extends StatelessWidget {
  const _VerificationNotice();

  @override
  Widget build(BuildContext context) {
    return const StatusBanner(
      title: 'Verification required',
      message:
          'Deals are read-only until this venue is verified. Existing offers '
          'keep running; new ones cannot be created.',
      tone: BannerTone.warning,
      icon: Icons.verified_user_outlined,
    );
  }
}

/// Create, edit and duplicate one offer on top of the existing draft contract.
///
/// A new deal is inserted as `draft` whatever the body says, so publishing
/// stays a separate, deliberate tap on the card. Editing a deal that has
/// already been published is allowed and the sheet says so at the top: a wrong
/// price that guests are already quoting at the table is the worse failure.
class _DealFormSheet extends ConsumerStatefulWidget {
  const _DealFormSheet({required this.venueId, this.draft, this.preset});

  final String venueId;

  /// The row being edited; null when creating or duplicating.
  final Deal? draft;

  /// Values copied off another deal. Kept separate from [draft] so a duplicate
  /// can never PATCH the row it was only shown as a template for.
  final DealDraftInput? preset;

  @override
  ConsumerState<_DealFormSheet> createState() => _DealFormSheetState();
}

class _DealFormSheetState extends ConsumerState<_DealFormSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _maxRedemptions = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _terms = TextEditingController();

  DealKind _kind = DealKind.percent;
  DateTime? _startsAt;
  DateTime? _endsAt;
  String _imageUrl = '';
  bool _busy = false;

  bool get _isEdit => widget.draft != null;

  @override
  void initState() {
    super.initState();
    final row = widget.draft;
    final copy = widget.preset;
    if (row != null) {
      _title.text = row.title;
      _value.text = _number(row.value);
      _code.text = row.code ?? '';
      _maxRedemptions.text = row.maxRedemptions?.toString() ?? '';
      _description.text = row.description;
      _terms.text = row.terms;
      _imageUrl = row.imageUrl;
      _kind = row.kind;
      _startsAt = row.startsAt.toLocal();
      _endsAt = row.endsAt.toLocal();
    } else if (copy != null) {
      _title.text = copy.title;
      _value.text = _number(copy.value);
      // No code: the copy is a new offer, and reusing the original's code would
      // be refused as a clash the partner has no way to see coming.
      _maxRedemptions.text = copy.maxRedemptions?.toString() ?? '';
      _description.text = copy.description;
      _terms.text = copy.terms;
      _imageUrl = copy.imageUrl;
      _kind = copy.kind;
      _startsAt = copy.startsAt.toLocal();
      _endsAt = copy.endsAt.toLocal();
    } else {
      final now = DateTime.now();
      _startsAt = DateTime(now.year, now.month, now.day);
      _endsAt = DateTime(now.year, now.month, now.day + 7, 23, 59, 59, 999);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _value, _code, _maxRedemptions, _description, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  /// 20.0 has to read as `20` in a number field, not `20.0`.
  static String _number(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  String get _sheetTitle {
    final row = widget.draft;
    if (row != null) return row.isDraft ? 'Edit draft' : 'Edit deal';
    return widget.preset == null ? 'New deal' : 'Duplicate deal';
  }

  String get _saveLabel {
    if (_busy) return 'Saving…';
    final row = widget.draft;
    if (row == null) return 'Create draft';
    return row.isDraft ? 'Save draft' : 'Save changes';
  }

  /// What the guest will be shown, read back while the partner types.
  ///
  /// The three mechanics are easy to confuse from a bare number field, and a
  /// `Rs. 5,999` package saved as a percent deal is a discount nobody can honour.
  String get _valuePreview {
    final parsed = double.tryParse(_value.text.trim().replaceAll(',', ''));
    if (parsed == null) {
      return _kind.isPercent ? 'Between 1 and 100' : 'Up to Rs. 100,000';
    }
    return switch (_kind) {
      DealKind.percent => 'Guests see ${_number(parsed)}% off',
      DealKind.fixed => 'Guests save ${dealMoney(parsed)}',
      DealKind.package => 'Guests pay ${dealMoney(parsed)}',
    };
  }

  /// Length of the validity window, so a two-day offer and a two-year one do
  /// not look the same once both dates are collapsed into two buttons.
  String? get _windowLine {
    final start = _startsAt;
    final end = _endsAt;
    if (start == null || end == null) return null;
    if (!end.isAfter(start)) return 'The end date is before the start';
    final days = end.difference(start).inDays;
    if (days < 1) return 'Runs for less than a day';
    return 'Runs for $days day${days == 1 ? '' : 's'}';
  }

  Future<void> _pickDate(bool start) async {
    if (_busy) return;
    final now = DateUtils.dateOnly(DateTime.now());
    final current = DateUtils.dateOnly((start ? _startsAt : _endsAt) ?? now);
    final first = current.isBefore(now) ? current : now;
    final last = DateTime(now.year + 5, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: current.isAfter(last) ? current : last,
      initialDate: current,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startsAt = picked;
        if (_endsAt == null || !_endsAt!.isAfter(picked)) {
          _endsAt = DateTime(
            picked.year,
            picked.month,
            picked.day + 7,
            23,
            59,
            59,
            999,
          );
        }
      } else {
        // One deal ends at 23:59 so the last day of the window is a full day
        // of service rather than midnight on it.
        _endsAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
          999,
        );
      }
    });
  }

  /// Adds a ready-made condition without wrecking what the partner wrote.
  ///
  /// Tapping a phrase twice does nothing: these chips are a shortcut for the
  /// common cases, not a set of checkboxes, and the text is what the guest reads.
  void _appendCondition(String phrase) {
    if (_busy) return;
    final current = _terms.text.trim();
    if (current.contains(phrase)) return;
    setState(() {
      _terms.text = current.isEmpty ? phrase : '$current, $phrase';
    });
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final gate = ref.read(roleGateProvider);
    if (!gate.can(Capability.manageDeals)) {
      showToast(
        context,
        'Deal management is not available for this account.',
        isError: true,
      );
      return;
    }
    if (!(ref.read(selectedVenueProvider)?.verified ?? false)) {
      showToast(context, 'Verify this venue before saving deals.', isError: true);
      return;
    }
    final rangeError = Validators.orderedRange(_startsAt, _endsAt);
    if (rangeError != null) {
      showToast(context, rangeError, isError: true);
      return;
    }
    // Only on a create: `POST …/deals` rejects an end date in the past, and a
    // deal nobody can use is not worth a round trip to find that out.
    if (!_isEdit && !_endsAt!.isAfter(DateTime.now())) {
      showToast(
        context,
        'Pick an end date in the future.',
        isError: true,
      );
      return;
    }
    final max = _maxRedemptions.text.trim();
    final input = DealDraftInput(
      title: _title.text,
      kind: _kind,
      value: double.parse(_value.text.trim().replaceAll(',', '')),
      startsAt: _startsAt!,
      endsAt: _endsAt!,
      description: _description.text,
      code: _code.text,
      maxRedemptions: max.isEmpty ? null : int.parse(max),
      terms: _terms.text,
      imageUrl: _imageUrl,
    );
    setState(() => _busy = true);
    try {
      FocusScope.of(context).unfocus();
      final repository = ref.read(businessRepositoryProvider);
      if (widget.draft == null) {
        await repository.createDeal(widget.venueId, input);
      } else {
        await repository.updateDeal(
          widget.venueId,
          widget.draft!.id,
          title: input.title,
          description: input.description,
          value: input.value,
          code: input.code,
          startsAt: input.startsAt,
          endsAt: input.endsAt,
          maxRedemptions: input.maxRedemptions,
          terms: input.terms,
          imageUrl: input.imageUrl,
        );
      }
      ref.invalidate(dealsProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        reportError(context, error, prefix: 'Could not save deal:');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final edge = width < 360 ? AppSpacing.md : AppSpacing.lg;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92 - inset;
    final row = widget.draft;

    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        // The keyboard pushes the sheet up; the fields scroll inside it and the
        // save button stays pinned above the keyboard.
        child: Padding(
          padding: EdgeInsets.only(bottom: inset),
          child: ConstrainedBox(
            // Never below the header plus the save bar, or the keyboard would
            // squeeze the sheet into a strip with nowhere to scroll.
            constraints: BoxConstraints(maxHeight: maxHeight < 260 ? 260 : maxHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(edge, AppSpacing.md, edge, AppSpacing.md),
              child: Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _sheetTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    if (row != null && !row.isDraft) ...[
                      const SizedBox(height: AppSpacing.sm),
                      InlineNotice(
                        kind: InlineNoticeKind.warning,
                        icon: Icons.campaign_outlined,
                        message: row.isLive
                            ? 'This deal is live · guests see saved changes at once.'
                            : 'This deal is published. Saving changes what guests see.',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionLabel(label: 'Photo'),
                            ImageUploadField(
                              venueId: widget.venueId,
                              kind: 'deal',
                              label: '',
                              value: _imageUrl,
                              onChanged: (v) => setState(() => _imageUrl = v),
                              aspectRatio: 16 / 9,
                              helperText:
                                  'Optional. Guests see your venue cover until '
                                  'you add one.',
                              enabled: !_busy,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _title,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Title *',
                                helperText: 'What the offer is, in a few words.',
                              ),
                              // 3, not 2: `dealBaseSchema` requires min 3, so a
                              // two-character title would have been a 422 the
                              // partner could not predict from the message.
                              validator: (v) => Validators.text(
                                v,
                                field: 'Title',
                                min: 3,
                                max: 120,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<DealKind>(
                              initialValue: _kind,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Discount type',
                                helperText: _isEdit
                                    ? 'Set when the deal was created. Changing '
                                          'the mechanic means making a copy.'
                                    : null,
                              ),
                              items: [
                                for (final kind in DealKind.values)
                                  DropdownMenuItem(
                                    value: kind,
                                    child: Text(kind.label),
                                  ),
                              ],
                              // The server refuses a kind change on a money
                              // value it has already priced, so the choice is
                              // closed once the row exists.
                              onChanged: _busy || _isEdit
                                  ? null
                                  : (v) => setState(() => _kind = v ?? _kind),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _value,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: switch (_kind) {
                                  DealKind.percent => 'Percentage off *',
                                  DealKind.fixed => 'Amount off *',
                                  DealKind.package => 'Package price *',
                                },
                                prefixText: _kind.isPercent ? null : 'Rs. ',
                                suffixText: _kind.isPercent ? '%' : null,
                                helperText: _valuePreview,
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) => _kind.isPercent
                                  ? Validators.percent(v, field: 'Discount')
                                  : Validators.money(
                                      v,
                                      field: switch (_kind) {
                                        DealKind.package => 'Package price',
                                        _ => 'Amount off',
                                      },
                                      max: 100000,
                                    ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _SectionLabel(label: 'Validity'),
                            // Stacked, not side by side: two labelled date
                            // buttons cannot share a 320 px row without one of
                            // them clipping its own date.
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : () => _pickDate(true),
                                icon: const Icon(Icons.event, size: 18),
                                label: Text(_dateLabel('Starts', _startsAt)),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : () => _pickDate(false),
                                icon: const Icon(Icons.event_busy, size: 18),
                                label: Text(_dateLabel('Ends', _endsAt)),
                              ),
                            ),
                            if (_windowLine != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                _windowLine!,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: _windowLine ==
                                          'The end date is before the start'
                                      ? AppColors.danger
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            _SectionLabel(label: 'Guests quote this code'),
                            TextFormField(
                              controller: _code,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText: 'Promo code',
                                helperText: _isEdit
                                    ? 'Optional. Blank clears it on save; a code '
                                          'already used at another table must be '
                                          'left alone.'
                                    : 'Optional. Guests quote this at the table. '
                                          'The venue keeps it unique.',
                              ),
                              validator: (v) => Validators.text(
                                v,
                                field: 'Code',
                                max: 24,
                                required: false,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _maxRedemptions,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Usage limit',
                                helperText: widget.draft?.maxRedemptions == null
                                    ? 'Optional; blank means unlimited.'
                                    : 'Existing limit can be changed, but not '
                                          'removed.',
                              ),
                              validator: (v) => Validators.integer(
                                v,
                                field: 'Usage limit',
                                min: 1,
                                max: 100000,
                                required: widget.draft?.maxRedemptions != null,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _description,
                              maxLines: 2,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Short description',
                                helperText:
                                    'One or two lines under the title, in the '
                                    'Customer App.',
                              ),
                              validator: (v) => Validators.text(
                                v,
                                field: 'Description',
                                max: 2000,
                                required: false,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _SectionLabel(label: 'Conditions'),
                            TextFormField(
                              controller: _terms,
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Conditions and how to redeem',
                                alignLabelWithHint: true,
                                helperText:
                                    'Days, hours and rules go here. Start a '
                                    'line with “How to redeem:” to split it in '
                                    'the Customer App.',
                              ),
                              validator: (v) => Validators.text(
                                v,
                                field: 'Conditions',
                                max: 2000,
                                required: false,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                for (final phrase in _conditionPresets)
                                  ActionChip(
                                    label: Text(phrase),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _busy
                                        ? null
                                        : () => _appendCondition(phrase),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_saveLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(String field, DateTime? date) {
    if (date == null) return field;
    final local = date.toLocal();
    return '$field ${DisplayDate.monthDay(local)}, ${local.year}';
  }
}

/// A heading between field groups, so a long form reads in blocks.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
