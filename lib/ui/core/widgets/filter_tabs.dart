import 'package:cupertino_ui/cupertino_ui.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

class PdFilterTabs extends StatelessWidget {
  const PdFilterTabs({required this.children, super.key});

  final List<PdFilterTab> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Pd.hairline)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
      child: Row(spacing: Pd.s5, children: children),
    ),
  );
}

class PdFilterTab extends StatelessWidget {
  const PdFilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = PdType.monoButton.copyWith(
      color: selected ? Pd.text : Pd.textSubtle,
      fontWeight: FontWeight.w400,
      fontVariations: const [FontVariation.weight(400)],
    );
    return Semantics(
      selected: selected,
      button: true,
      label: '$label, $count',
      onTap: onTap,
      excludeSemantics: true,
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        pressedOpacity: 0.7,
        focusColor: Pd.lime,
        minimumSize: const Size.square(Pd.tapMin),
        child: Container(
          constraints: const BoxConstraints(minHeight: Pd.tapMin),
          padding: const EdgeInsets.symmetric(vertical: Pd.s2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Pd.lime.withValues(alpha: selected ? 1 : 0),
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(
              text: label,
              children: [
                TextSpan(
                  text: ' $count',
                  style: TextStyle(color: selected ? Pd.lime : Pd.textSubtle),
                ),
              ],
            ),
            style: style,
          ),
        ),
      ),
    );
  }
}
