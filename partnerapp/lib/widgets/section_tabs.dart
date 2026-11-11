import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// One tab descriptor for a section screen.
class SectionTab {
  const SectionTab({
    required this.key,
    required this.label,
    required this.child,
    this.icon,
  });

  /// Matches the `?tab=` query value in an [AppRoute]-style route so a shared
  /// URL opens the right tab (web back/forward and deep links).
  final String key;
  final String label;
  final IconData? icon;
  final Widget child;
}

/// A tabbed section host that opens on the tab named in the route query.
///
/// Every Operations/Experiences/Business/Inbox screen is a set of related
/// surfaces behind one navigation destination; keeping them in a single route
/// with a query tab means the mobile bar, the rail and the web sidebar all
/// point at one place instead of inventing their own navigation.
class SectionTabs extends StatefulWidget {
  const SectionTabs({
    super.key,
    required this.tabs,
    this.initialTab,
    this.actions,
    this.scrollable,
  });

  final List<SectionTab> tabs;
  final String? initialTab;

  /// Optional per-tab actions rendered in a trailing slot of the tab bar row.
  final Widget Function(BuildContext context, int index)? actions;

  /// Forces the scrollable shape regardless of tab count.
  ///
  /// Three long labels at a 2x text scale do not fit a phone width even though
  /// three tabs normally do, so a section that promises exactly three
  /// destinations asks for the rail explicitly. Null keeps the old rule.
  final bool? scrollable;

  @override
  State<SectionTabs> createState() => _SectionTabsState();
}

class _SectionTabsState extends State<SectionTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    var index = 0;
    final tab = widget.initialTab;
    if (tab != null) {
      index = widget.tabs.indexWhere((t) => t.key == tab);
      if (index < 0) index = 0;
    }
    _controller = TabController(length: widget.tabs.length, initialIndex: index, vsync: this);
  }

  @override
  void didUpdateWidget(covariant SectionTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tab = widget.initialTab;
    if (tab != null) {
      final index = widget.tabs.indexWhere((t) => t.key == tab);
      if (index >= 0 && index != _controller.index) _controller.index = index;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _controller,
                  isScrollable: widget.scrollable ?? widget.tabs.length > 4,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  labelStyle: AppTextStyles.labelLarge,
                  tabs: [
                    for (final tab in widget.tabs)
                      Tab(
                        height: 48,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tab.icon != null) ...[
                              Icon(tab.icon, size: 18),
                              const SizedBox(width: 6),
                            ],
                            Text(tab.label),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.actions != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: widget.actions!(context, _controller.index),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [for (final tab in widget.tabs) tab.child],
          ),
        ),
      ],
    );
  }
}
