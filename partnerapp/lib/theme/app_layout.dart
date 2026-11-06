import 'package:flutter/widgets.dart';

import 'app_spacing.dart';

/// The three layout classes the Partner App renders against.
///
/// One codebase, three shapes: phone (`compact`) gets a bottom navigation bar,
/// tablet/small window (`medium`) a navigation rail, and desktop web
/// (`expanded`) a persistent sidebar with two-pane master/detail content.
enum WindowSize { compact, medium, expanded }

class AppLayout {
  AppLayout._();

  /// Below this width the shell uses a bottom navigation bar.
  static const double compactMaxWidth = 600;

  /// At or above this width the shell uses the persistent sidebar.
  static const double expandedMinWidth = 1024;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static WindowSize windowSize(BuildContext context) {
    final width = widthOf(context);
    if (width < compactMaxWidth) return WindowSize.compact;
    if (width < expandedMinWidth) return WindowSize.medium;
    return WindowSize.expanded;
  }

  static bool isCompact(BuildContext context) =>
      windowSize(context) == WindowSize.compact;

  static bool isMedium(BuildContext context) =>
      windowSize(context) == WindowSize.medium;

  static bool isExpanded(BuildContext context) =>
      windowSize(context) == WindowSize.expanded;

  /// Whether the shell should park navigation in a sidebar instead of a rail or
  /// a bottom bar.
  static bool useSidebar(BuildContext context) => isExpanded(context);

  /// Whether a screen may show its detail pane beside a list. Compact layouts
  /// push the detail as a route instead.
  static bool useTwoPane(BuildContext context) => isExpanded(context);

  /// Screen padding: comfortable on a phone, roomier as the window grows, and
  /// capped so a 4K browser window never stretches a form edge to edge.
  static EdgeInsets screenPadding(BuildContext context) {
    final width = widthOf(context);
    final horizontal = width < 380
        ? 12.0
        : width < compactMaxWidth
        ? AppSpacing.paddingScreen
        : AppSpacing.lg;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: AppSpacing.md);
  }

  /// Centers content and stops it reading as an endless line on desktop web.
  static double contentMaxWidth(BuildContext context) => AppSpacing.maxContentWidth;

  /// Column count for a KPI / card grid at the current width.
  static int gridColumns(BuildContext context, {double minCardWidth = 240}) {
    final available =
        widthOf(context) - (isCompact(context) ? 24 : 2 * AppSpacing.lg);
    final columns = (available / minCardWidth).floor().clamp(1, 6);
    return columns;
  }

  /// Wraps [child] so wide layouts keep a readable measure.
  static Widget constrain(BuildContext context, Widget child) =>
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: child,
        ),
      );
}
