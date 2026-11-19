import 'package:cupertino_ui/cupertino_ui.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';
import 'glass.dart';
import 'icons.dart';

class PdTabBar extends StatelessWidget {
  const PdTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.onScan,
    this.onScanLongPress,
    this.claimsBadge = 0,
    this.homeFirst = false,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onScan;
  final VoidCallback? onScanLongPress;
  final int claimsBadge;
  final bool homeFirst;

  static const _radius = PdGlassSurface.radius;
  static const _originalTabs = [
    ('Vault', PdGlyph.vault),
    ('Claims', PdGlyph.claims),
    ('Settings', PdGlyph.settings),
  ];
  static const _homeTabs = [
    ('Home', PdGlyph.home),
    ('Drawer', PdGlyph.vault),
    ('Settings', PdGlyph.settings),
  ];

  List<(String, PdGlyph)> get _tabs => homeFirst ? _homeTabs : _originalTabs;
  int get _selectedSlot => homeFirst && currentIndex == 2 ? 3 : currentIndex;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.symmetric(horizontal: Pd.s4),
      child: Padding(
        padding: const EdgeInsets.only(bottom: Pd.s2),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Pd.dockMaxWidth),
            child: DecoratedBox(
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
            ),
          ),
        ),
      ),
    );
  }

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
          if (homeFirst && index == 2) _add(),
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
              badge: glyph == PdGlyph.claims || glyph == PdGlyph.home
                  ? claimsBadge
                  : 0,
              onTap: () => onTap(index),
            ),
          ),
        ],
        if (!homeFirst) _add(),
      ],
    ),
  );

  Widget _add() => Expanded(
    child: _DockButton(
      key: const ValueKey('scan-or-add'),
      title: homeFirst ? 'Add' : 'Scan or add',
      glyph: homeFirst ? PdGlyph.add : PdGlyph.scan,
      onTap: onScan,
      onLongPress: onScanLongPress,
    ),
  );
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.title,
    required this.glyph,
    required this.onTap,
    this.selected,
    this.badge = 0,
    this.onLongPress,
    super.key,
  });

  final String title;
  final PdGlyph glyph;
  final bool? selected;
  final int badge;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scan = glyph == PdGlyph.scan;
    final add = glyph == PdGlyph.add && onTap != null;
    final accent = selected == true || ((scan || add) && onTap != null);
    return Semantics(
      label: badge > 0 ? '$title, $badge need action' : title,
      selected: selected,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      onLongPress: onLongPress,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scan && onTap != null ? Pd.limeTint : null,
          borderRadius: PdTabBar._radius,
        ),
        child: CupertinoButton(
          minimumSize: const Size(Pd.tapMin, Pd.dockControlHeight),
          padding: const EdgeInsets.all(Pd.s1),
          borderRadius: PdTabBar._radius,
          pressedOpacity: 0.7,
          focusColor: Pd.lime,
          onPressed: onTap,
          onLongPress: onLongPress,
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
              Text.rich(
                TextSpan(
                  text: scan ? title : title.toUpperCase(),
                  children: [
                    if (badge > 0)
                      TextSpan(
                        text: ' $badge',
                        style: const TextStyle(color: Pd.signal),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: PdType.tabLabel.copyWith(
                  color: (scan || add) && accent
                      ? Pd.lime
                      : onTap == null
                      ? Pd.textSubtle
                      : Pd.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
