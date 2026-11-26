import 'package:flutter/widgets.dart';
// The native plugin reads Flutter's original Material Theme.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy show Theme, ThemeData;
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../theme/pd_dynamic_type.dart';
import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';
import '../widgets/glass.dart' show PdNativeGlassTouch;
import '../widgets/icons.dart';
import 'glass_scan_button.dart';
import 'glass_scope.dart';
import 'pd_destination.dart';
import 'pd_glass.dart';
import 'pd_pressable.dart';

/// The floating dock on compact widths: the glass tab bar with the
/// destinations, then the lime Scan circle `space-2` to its right.
///
/// - iOS 26: the system tab bar with Scan as its action button (the way
///   Apple places Search); minimising is the system's.
/// - Fallback: kit glass, a `glass-selection` capsule that slides between
///   tabs (instant with Reduce Motion). [minimised] shrinks the bar to the
///   selected tab's icon with [accessory] inline between it and Scan.
///
/// Tab text is capped at `PdDynamicType.chromeMaxScale`.
final class PdGlassDock extends StatelessWidget {
  const PdGlassDock({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onScan,
    this.onScanLongPress,
    this.scanLabel = 'Scan or add',
    this.scanSystemIcon = 'doc.viewfinder',
    this.minimised = false,
    this.accessory,
    this.onRestore,
    super.key = const ValueKey('glass-dock'),
  });

  final List<PdDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onScan;
  final VoidCallback? onScanLongPress;
  final String scanLabel;
  final String scanSystemIcon;
  final bool minimised;

  /// Shown inline when [minimised] (fallback only), built at
  /// [PdSize.tabBarMin] height.
  final Widget? accessory;

  /// Tapping the minimised tab restores the full bar.
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    if (PdGlassScope.modeOf(context) == PdGlassMode.native) {
      return _NativeDock(dock: this);
    }
    return PdDynamicType.chrome(
      child: minimised ? _minimisedRow(context) : _fullRow(context),
    );
  }

  Widget _scan(double size) => GlassScanButton(
    onPressed: onScan,
    onLongPress: onScanLongPress,
    semanticLabel: scanLabel,
    systemIcon: scanSystemIcon,
    size: size,
  );

  Widget _fullRow(BuildContext context) => Row(
    children: [
      Expanded(
        child: _TabBar(
          destinations: destinations,
          selectedIndex: selectedIndex,
          onSelected: onDestinationSelected,
        ),
      ),
      const SizedBox(width: PdSpace.s2),
      _scan(PdSize.tabBarHeight),
    ],
  );

  Widget _minimisedRow(BuildContext context) {
    final colors = context.pd.colors;
    final selected = destinations[selectedIndex];
    final accessory = this.accessory;
    return Row(
      children: [
        PdPressable(
          key: ValueKey('${selected.id}-tab'),
          semanticLabel: selected.label,
          semanticHint: 'Shows all tabs',
          selected: true,
          onPressed: onRestore,
          child: PdGlass(
            shape: PdGlassShape.circle,
            child: SizedBox.square(
              dimension: PdSize.tabBarMin,
              child: Center(
                child: PdIcon(
                  selected.glyph,
                  size: PdSize.iconBar,
                  color: colors.limeText,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: PdSpace.s2),
        Expanded(child: accessory ?? const SizedBox.shrink()),
        const SizedBox(width: PdSpace.s2),
        _scan(PdSize.tabBarMin),
      ],
    );
  }
}

final class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PdDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.pd.colors;
    final count = destinations.length;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return PdGlass(
      child: SizedBox(
        height: PdSize.tabBarHeight,
        child: Padding(
          padding: const EdgeInsets.all(PdSpace.s1),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: AlignmentDirectional(
                    count == 1 ? 0.0 : -1 + 2 * selectedIndex / (count - 1),
                    0,
                  ),
                  duration: reduceMotion ? Duration.zero : PdMotion.tabSelection,
                  curve: PdMotion.standard,
                  child: FractionallySizedBox(
                    widthFactor: 1 / count,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.glassSelection,
                        borderRadius: BorderRadius.circular(PdRadius.pill),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, destination) in destinations.indexed)
                    Expanded(
                      child: _Tab(
                        destination: destination,
                        position: index + 1,
                        count: count,
                        selected: index == selectedIndex,
                        onPressed: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Tab extends StatelessWidget {
  const _Tab({
    required this.destination,
    required this.position,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final PdDestination destination;
  final int position;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    // Canvas: the selected tab is lime (olive in light) on the selection
    // capsule; the README's `text` is superseded (AGENTS §8, canvas wins).
    final color = selected ? pd.colors.limeText : pd.colors.text;
    return PdPressable(
      key: ValueKey('${destination.id}-tab'),
      semanticLabel: destination.label,
      semanticHint: 'Tab $position of $count',
      selected: selected,
      inMutuallyExclusiveGroup: true,
      pressedScale: 1,
      onPressed: onPressed,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PdIcon(destination.glyph, size: PdSize.iconBar, color: color),
            // Canvas: 2–3 pt between a tab's icon and label.
            const SizedBox(height: PdSpace.s1 - 1),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: pd.type.tabLabel.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

final class _NativeDock extends StatelessWidget {
  const _NativeDock({required this.dock});

  final PdGlassDock dock;

  @override
  Widget build(BuildContext context) {
    final colors = context.pd.colors;
    final nativeTheme = legacy.ThemeData(
      brightness: Theme.of(context).brightness,
    );
    return SizedBox(
      // Reserve the plugin's glass overflow before UIKit lays the bar out.
      height: PdSize.tabBarHeight + PdSpace.s5,
      child: legacy.Theme(
        data: nativeTheme,
        child: PdNativeGlassTouch(
          child: LiquidGlassTabBar(
            items: [
              for (final destination in dock.destinations)
                LiquidGlassTabItem(
                  label: destination.label,
                  icon: NativeLiquidGlassIcon.sfSymbol(destination.systemIcon),
                ),
            ],
            iosActionButton: dock.onScan == null
                ? null
                : LiquidGlassTabItem(
                    label: dock.scanLabel,
                    icon: NativeLiquidGlassIcon.sfSymbol(dock.scanSystemIcon),
                    selectedItemColor: colors.onLime,
                  ),
            currentIndex: dock.selectedIndex,
            onTabSelected: dock.onDestinationSelected,
            onActionButtonPressed: dock.onScan,
            height: PdSize.tabBarHeight,
            selectedItemColor: colors.limeText,
          ),
        ),
      ),
    );
  }
}
