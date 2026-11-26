import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/widgets.dart';

import '../glass/glass_scope.dart';
import '../glass/pd_destination.dart';
import '../glass/pd_glass_dock.dart';
import '../glass/pd_toast.dart';
import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';
import 'pd_breakpoints.dart';
import 'pd_sidebar.dart';

/// The app frame, switched on available width (no routing knowledge: the
/// shell passes destinations and callbacks).
///
/// **Compact (< 600 pt):** [body] fills the screen and scrolls under a
/// floating dock: the glass tab bar plus the lime Scan circle, 16 pt from
/// the sides and 8 pt above the home indicator, max 440 wide. Above it sits
/// the [accessory] (DeadlineAccessory) or, while one shows, the toast from
/// [toasts]. Scrolling down minimises the bar (accessory inline); scrolling
/// up or tapping the tab restores it. The dock hides while the keyboard is
/// up and when [showDock] is false (camera, reading).
///
/// **Regular (≥ 600 pt):** a 320 pt glass sidebar inset 12 pt with the
/// destinations, optional [sidebarFilters] and "Scan or add"; [body] fills
/// the rest. The accessory/toast float at the bottom of the content area.
///
/// [body] gets `MediaQuery.paddingOf(context).bottom` raised by the dock, so
/// a list ends with `padding.bottom + PdSpace.s12` and its last row clears
/// the glass.
final class PdAdaptiveScaffold extends StatefulWidget {
  const PdAdaptiveScaffold({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onScan,
    required this.body,
    this.onScanLongPress,
    this.accessory,
    this.toasts,
    this.sidebarFilters,
    this.brand,
    this.scanLabel = 'Scan or add',
    this.showDock = true,
    super.key,
  });

  final List<PdDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onScan;
  final VoidCallback? onScanLongPress;
  final Widget body;

  /// The DeadlineAccessory, or null (Home, nothing due).
  final Widget? accessory;
  final PdToastController? toasts;
  final PdSidebarFilters? sidebarFilters;

  /// Mark and wordmark at the top of the sidebar.
  final Widget? brand;
  final String scanLabel;
  final bool showDock;

  /// Height the compact dock adds above the safe area (bar, its 8 pt gap
  /// to the home indicator, and the accessory row when [withAccessory]).
  static double compactDockInset({required bool withAccessory}) =>
      PdSpace.s2 +
      PdSize.tabBarHeight +
      (withAccessory ? PdSize.accessoryHeight + PdSpace.s2 : 0);

  @override
  State<PdAdaptiveScaffold> createState() => _PdAdaptiveScaffoldState();
}

final class _PdAdaptiveScaffoldState extends State<PdAdaptiveScaffold> {
  bool _minimised = false;

  @override
  void initState() {
    super.initState();
    widget.toasts?.addListener(_onToast);
  }

  @override
  void didUpdateWidget(PdAdaptiveScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.toasts != widget.toasts) {
      oldWidget.toasts?.removeListener(_onToast);
      widget.toasts?.addListener(_onToast);
    }
  }

  @override
  void dispose() {
    widget.toasts?.removeListener(_onToast);
    super.dispose();
  }

  void _onToast() {
    if (mounted) setState(() {});
  }

  void _setMinimised(bool value) {
    if (value != _minimised) setState(() => _minimised = value);
  }

  bool _onScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _setMinimised(true);
      case ScrollDirection.forward:
        _setMinimised(false);
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  /// The toast while one shows, else the accessory.
  Widget? _slot() {
    final toasts = widget.toasts;
    final message = toasts?.current;
    if (toasts != null && message != null) {
      return PdToast(
        message: message,
        onUndo: toasts.dismiss,
        onAccessibilityFocus: toasts.holdForAccessibility,
      );
    }
    return widget.accessory;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pd.colors;
    final content = switch (PdBreakpoints.of(context)) {
      PdWidthClass.compact => _compact(context),
      PdWidthClass.regular => _regular(context),
    };
    return ColoredBox(color: colors.bg, child: content);
  }

  Widget _crossFade(Widget? child) => AnimatedSwitcher(
    duration: PdMotion.crossFade,
    child: child ?? const SizedBox.shrink(),
  );

  Widget _compact(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardUp = media.viewInsets.bottom > 0;
    final dockVisible = widget.showDock && !keyboardUp;
    final slot = _slot();
    final inset = dockVisible
        ? PdAdaptiveScaffold.compactDockInset(withAccessory: slot != null)
        : 0.0;
    final body = MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(bottom: media.padding.bottom + inset),
      ),
      child: NotificationListener<UserScrollNotification>(
        onNotification: _onScroll,
        child: widget.body,
      ),
    );
    // The iOS 26 tab bar minimises itself; the kit only minimises its own.
    final native = PdGlassScope.modeOf(context) == PdGlassMode.native;
    final minimised = _minimised && !native && slot is! PdToast;
    return Stack(
      children: [
        Positioned.fill(child: body),
        if (dockVisible)
          Positioned(
            left: PdSpace.s4 + media.padding.left,
            right: PdSpace.s4 + media.padding.right,
            bottom: PdSpace.s2 + media.padding.bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PdSize.tabBarMaxWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!minimised && slot != null) ...[
                      _crossFade(slot),
                      const SizedBox(height: PdSpace.s2),
                    ],
                    _crossFade(
                      PdGlassDock(
                        key: ValueKey(
                          minimised ? 'glass-dock-min' : 'glass-dock',
                        ),
                        destinations: widget.destinations,
                        selectedIndex: widget.selectedIndex,
                        onDestinationSelected: widget.onDestinationSelected,
                        onScan: widget.onScan,
                        onScanLongPress: widget.onScanLongPress,
                        scanLabel: widget.scanLabel,
                        minimised: minimised,
                        accessory: minimised ? widget.accessory : null,
                        onRestore: () => _setMinimised(false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _regular(BuildContext context) {
    final media = MediaQuery.of(context);
    final start = PdSize.sidebarInset * 2 + PdSize.sidebarWidth;
    final slot = _slot();
    final body = MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          left: 0,
          bottom:
              media.padding.bottom +
              (slot == null ? 0 : PdSize.accessoryHeight + PdSpace.s4),
        ),
      ),
      child: widget.body,
    );
    return Stack(
      children: [
        PositionedDirectional(
          start: start + media.padding.left,
          top: 0,
          end: 0,
          bottom: 0,
          child: body,
        ),
        PositionedDirectional(
          start: PdSize.sidebarInset + media.padding.left,
          top: PdSize.sidebarInset + media.padding.top,
          bottom: PdSize.sidebarInset + media.padding.bottom,
          width: PdSize.sidebarWidth,
          child: PdSidebar(
            destinations: widget.destinations,
            selectedIndex: widget.selectedIndex,
            onDestinationSelected: widget.onDestinationSelected,
            onScan: widget.onScan,
            filters: widget.sidebarFilters,
            brand: widget.brand,
            scanLabel: widget.scanLabel,
          ),
        ),
        if (slot != null)
          PositionedDirectional(
            start: start + media.padding.left,
            end: PdSpace.s8 + media.padding.right,
            bottom: PdSpace.s4 + media.padding.bottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PdSize.tabBarMaxWidth,
                ),
                child: _crossFade(slot),
              ),
            ),
          ),
      ],
    );
  }
}
