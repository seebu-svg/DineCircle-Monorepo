import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/comms.dart';
import '../../providers/module_providers.dart';
import '../../repositories/business_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_time.dart';
import '../../widgets/async_views.dart';
import '../../widgets/data_widgets.dart';
import '../../widgets/premium_cards.dart';

/// The notification inbox (`GET /partner/notifications`).
///
/// There is no push channel, so the list polls and refreshes on pull; the same
/// read drives the shell badge. Tapping an item marks it read and jumps to the
/// surface that category points at, so the inbox is a dispatcher, not a dead end.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(notificationsProvider(_unreadOnly));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.paddingScreen,
            AppSpacing.md,
            AppSpacing.paddingScreen,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Polls every minute; pull to refresh sooner.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              FilterChip(
                label: const Text('Unread only'),
                selected: _unreadOnly,
                onSelected: (v) => setState(() => _unreadOnly = v),
              ),
              IconButton(
                tooltip: 'Mark all read',
                onPressed: () =>
                    ref.read(notificationBadgeProvider.notifier).markAll(),
                icon: const Icon(Icons.done_all),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<NotificationPage>(
            value: page,
            onRetry: () => ref.invalidate(notificationsProvider(_unreadOnly)),
            emptyState: EmptyState(
              title: _unreadOnly ? 'Nothing unread' : 'Inbox zero',
              message: 'Reservation, request, deal and payout alerts land here '
                  'as they happen.',
              icon: Icons.notifications_none,
            ),
            loading: const LoadingSkeleton(count: 4),
            builder: (context, data) => RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationBadgeProvider.notifier).refresh(),
              child: TileList(
                children: [
                  for (final n in data.items)
                    _NotificationTile(
                      notification: n,
                      onTap: () => _open(n),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(PartnerNotification n) async {
    if (!n.read) {
      await ref.read(notificationBadgeProvider.notifier).markOne(n.id);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(n.deepLink);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final PartnerNotification notification;
  final VoidCallback onTap;

  IconData get _icon => switch (notification.category) {
    'reservation' || 'booking' => Icons.event_available,
    'event_request' || 'request' => Icons.pending_actions,
    'deal' => Icons.local_offer,
    'payout' || 'earnings' => Icons.payments,
    'review' => Icons.star,
    _ => Icons.notifications,
  };

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return PremiumCard(
      padding: 0,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          _icon,
          color: n.read ? AppColors.textTertiary : AppColors.primary,
        ),
        title: Text(
          n.title,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: n.read ? FontWeight.w400 : FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${n.body}\n${DisplayDate.relative(n.notificationTime)}',
          style: AppTextStyles.bodySmall,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: n.read
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
