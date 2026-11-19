import 'package:cupertino_ui/cupertino_ui.dart';
// The native plugin reads Flutter's original Material Theme.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy show Theme, ThemeData;
import 'package:native_liquid_glass/native_liquid_glass.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';
import 'glass.dart';
import 'icons.dart';

class PdTabBar extends StatelessWidget {
  const PdTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.onScan,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onScan;

  static const _radius = PdGlassSurface.radius;
  static const _tabs = [
    ('Home', PdGlyph.home),
    ('Drawer', PdGlyph.vault),
    ('Settings', PdGlyph.settings),
  ];

  static const _nativeTabs = [
    LiquidGlassTabItem(
      label: 'Home',
      icon: NativeLiquidGlassIcon.sfSymbol('house'),
    ),
    LiquidGlassTabItem(
      label: 'Drawer',
      icon: NativeLiquidGlassIcon.sfSymbol('archivebox'),
    ),
    LiquidGlassTabItem(
      label: 'Settings',
      icon: NativeLiquidGlassIcon.sfSymbol('slider.horizontal.3'),
    ),
  ];

  static const _nativeAdd = LiquidGlassTabItem(
    label: 'Add',
    icon: NativeLiquidGlassIcon.sfSymbol('plus'),
  );
  static final _nativeTheme = legacy.ThemeData.dark();

  int get _selectedSlot => currentIndex == 2 ? 3 : currentIndex;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: MediaQuery.viewInsetsOf(context).bottom == 0,
      maintainState: true,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.symmetric(horizontal: Pd.s4),
        child: Padding(
          padding: const EdgeInsets.only(bottom: Pd.s2),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Pd.dockMaxWidth),
              child: NativeLiquidGlassUtils.supportsLiquidGlass
                  ? _nativeDock(context)
                  : _flutterDock(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nativeDock(BuildContext context) => SizedBox(
    // Keep the scroll inset steady, including the plugin's glass overflow.
    height: Pd.dockControlHeight + Pd.s5,
    child: Visibility(
      // Keep the same UIKit view ready for the return from a covered route.
      // Offstage keeps it out of Flutter's moving render surface.
      visible: pdNativeGlassVisible(context),
      maintainState: true,
      child: legacy.Theme(
        data: _nativeTheme,
        child: LiquidGlassTabBar(
          items: _nativeTabs,
          iosActionButton: onScan == null ? null : _nativeAdd,
          currentIndex: currentIndex,
          onTabSelected: onTap,
          onActionButtonPressed: onScan,
          height: Pd.dockControlHeight,
          selectedItemColor: Pd.lime,
        ),
      ),
    ),
  );

  Widget _flutterDock(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      borderRadius: _radius,
      boxShadow: Pd.shadowFab,
    ),
    child: PdGlassSurface(
      child: Padding(
        padding: const EdgeInsets.all(Pd.s1),
        child: Stack(
          children: [
            Positioned.fill(child: _selection(context)),
            _controls(),
          ],
        ),
      ),
    ),
  );

  Widget _selection(BuildContext context) => AnimatedAlign(
    alignment: AlignmentDirectional(-1 + 2 * _selectedSlot / _tabs.length, 0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Pd.dockSelectionDuration,
    curve: Curves.easeOutCubic,
    child: FractionallySizedBox(
      widthFactor: 1 / (_tabs.length + 1),
      heightFactor: 1,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Pd.dockSelection,
          borderRadius: _radius,
        ),
      ),
    ),
  );

  Widget _controls() => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, (title, glyph)) in _tabs.indexed) ...[
          if (index == 2) _add(),
          Expanded(
            child: _DockButton(
              key: ValueKey(
                glyph == PdGlyph.vault
                    ? 'vault-tab'
                    : '${title.toLowerCase()}-tab',
              ),
              title: title,
              glyph: glyph,
              selected: index == currentIndex,
              onTap: () => onTap(index),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _add() => Expanded(
    child: _DockButton(
      key: const ValueKey('scan-or-add'),
      title: 'Add',
      glyph: PdGlyph.add,
      onTap: onScan,
    ),
  );
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.title,
    required this.glyph,
    required this.onTap,
    this.selected,
    super.key,
  });

  final String title;
  final PdGlyph glyph;
  final bool? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final add = glyph == PdGlyph.add && onTap != null;
    final accent = selected == true || add;
    return Semantics(
      label: title,
      selected: selected,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: CupertinoButton(
        minimumSize: const Size(Pd.tapMin, Pd.dockControlHeight),
        padding: const EdgeInsets.all(Pd.s1),
        borderRadius: PdTabBar._radius,
        pressedOpacity: 0.7,
        focusColor: Pd.lime,
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Pd.s1,
          children: [
            if (add)
              const SizedBox(
                width: Pd.dockAddWidth,
                height: Pd.dockAddHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Pd.lime,
                    borderRadius: PdTabBar._radius,
                    boxShadow: Pd.dockAddGlow,
                  ),
                  child: Center(
                    child: PdIcon(
                      PdGlyph.add,
                      size: Pd.iconSm,
                      color: Pd.onLime,
                    ),
                  ),
                ),
              )
            else
              PdIcon(glyph, color: accent ? Pd.lime : Pd.text2),
            Text(
              title.toUpperCase(),
              textAlign: TextAlign.center,
              style: PdType.tabLabel.copyWith(
                color: add
                    ? Pd.lime
                    : onTap == null
                    ? Pd.textSubtle
                    : Pd.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
