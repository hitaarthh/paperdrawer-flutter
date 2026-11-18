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
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Pd.lime.withValues(alpha: selected ? 1 : 0),
              width: 2,
            ),
          ),
        ),
        child: CupertinoButton(
          key: ValueKey('${title.toLowerCase()}-tab'),
          minimumSize: const Size(0, Pd.tabbarIos),
          padding: const EdgeInsets.fromLTRB(Pd.s1, Pd.s2, Pd.s1, Pd.s1),
          pressedOpacity: 0.7,
          focusColor: Pd.lime,
          onPressed: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: Pd.s1,
            children: [
              PdIcon(glyph, color: color),
              Text.rich(
                TextSpan(
                  text: title.toUpperCase(),
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
                  color: selected ? Pd.text : Pd.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
