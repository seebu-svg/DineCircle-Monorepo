import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'status_chip.dart';

/// Nothing here yet, plus the one action that would change that.
///
/// An empty state is never just a message in this app: the desk needs to know
/// what to do next, which is why [action] is part of the widget rather than
/// something each screen improvises.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 28 : 40, color: AppColors.textTertiary),
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact
                    ? AppTextStyles.titleMedium
                    : AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall,
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.md),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A failed request, said in the desk's language.
///
/// The kind of failure matters: a `403` is a role problem, a `409` means the
/// row moved under the operator, and no connection at all should not look like
/// an empty venue. Each gets its own copy and its own retry affordance.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  String get _title {
    if (error is ApiException) {
      final api = error as ApiException;
      if (api.isForbidden) return 'Not allowed here';
      if (api.isNotFound) return 'Not found';
      if (api.isConflict) return 'That has already changed';
      if (api.statusCode == 0) return 'Cannot reach the server';
      if (api.isValidation) return 'Check the details';
      return 'Something went wrong';
    }
    return 'Something went wrong';
  }

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : error.toString();
    if (compact) {
      return StatusBanner(
        title: _title,
        message: message,
        tone: BannerTone.danger,
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 36,
                color: AppColors.danger,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(_title, style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The loading shape for lists and cards.
///
/// Skeletons rather than a spinner so the desk sees the layout it is about to
/// get, and a slow paired device does not read as an empty day.
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    this.count = 4,
    this.itemHeight = 72,
    this.showHeader = false,
  });

  final int count;
  final double itemHeight;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final bars = <Widget>[
      if (showHeader) ...[
        _Bar(height: 22, width: 180),
        const SizedBox(height: AppSpacing.md),
      ],
      for (var i = 0; i < count; i++) ...[
        _Bar(height: itemHeight),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: bars,
          );
          // Inside a list the height is unbounded and the bars are the content.
          if (!constraints.hasBoundedHeight) return column;
          // In a short pane — a phone whose photo header took the top half, or
          // 2x text on a 320dp screen — the bars are taller than the space
          // they stand in. They scroll instead of overflowing: a skeleton that
          // trips a layout error is worse than no skeleton at all.
          return SingleChildScrollView(child: column);
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
    );
  }
}

/// Renders an [AsyncValue] with the three shared states in one place.
///
/// Every module screen goes through this, so "loading", "empty" and "error" are
/// genuinely identical across the app instead of re-invented per feature.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    required this.emptyState,
    this.loading,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final Widget emptyState;
  final Widget? loading;

  /// Invalidates the provider behind [value]. Screens pass
  /// `() => ref.invalidate(someProvider)` so a retry re-reads exactly one
  /// surface rather than every live provider in the app.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => loading ?? const LoadingSkeleton(),
      error: (error, _) =>
          ErrorView(error: error, onRetry: onRetry, compact: false),
      data: (data) {
        if (data is Iterable && data.isEmpty) return emptyState;
        if (data is Map && data.isEmpty) return emptyState;
        return builder(context, data);
      },
    );
  }
}

/// One-line notice while the device has no route to the API.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key, required this.offline});

  final bool offline;

  @override
  Widget build(BuildContext context) {
    if (!offline) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: StatusBanner(
        title: 'Offline',
        message:
            'No connection to the DineCircle API. Lists show the last data '
            'read; actions are disabled until you are back online.',
        tone: BannerTone.warning,
        icon: Icons.wifi_off,
      ),
    );
  }
}

/// A titled block of content with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.topSpacing = AppSpacing.lg,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
