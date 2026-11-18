import 'package:cupertino_ui/cupertino_ui.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';
import 'icons.dart';

class PdTabBar extends StatelessWidget {
  const PdTabBar({
    required this.currentIndex,
    required this.onTap,
    this.claimsBadge = 0,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int claimsBadge;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('Vault', PdGlyph.vault),
      ('Claims', PdGlyph.claims),
      ('Settings', PdGlyph.settings),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Pd.bg,
        border: Border(top: BorderSide(color: Pd.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (index, (title, glyph)) in tabs.indexed)
              Expanded(
                child: _Tab(
                  title: title,
                  glyph: glyph,
                  selected: index == currentIndex,
                  badge: glyph == PdGlyph.claims ? claimsBadge : 0,
                  onTap: () => onTap(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.title,
    required this.glyph,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final PdGlyph glyph;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Pd.lime : Pd.textSubtle;
    return Semantics(
      label: badge > 0 ? '$title, $badge need action' : title,
      selected: selected,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: CupertinoButton(
        key: ValueKey('${title.toLowerCase()}-tab'),
        minimumSize: const Size(0, Pd.tabbarIos),
        padding: const EdgeInsets.symmetric(vertical: Pd.s1),
        pressedOpacity: 0.7,
        focusColor: Pd.lime,
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PdIcon(glyph, color: color),
                if (badge > 0)
                  Positioned(
                    left: Pd.iconSm,
                    top: -Pd.s1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Pd.signal,
                        borderRadius: BorderRadius.circular(Pd.rPill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Pd.s1),
                        child: Text(
                          '$badge',
                          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                          style: PdType.tabLabel.copyWith(color: Pd.onLime),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Pd.s1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Pd.s1),
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: PdType.tabLabel.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
