import 'package:cupertino_ui/cupertino_ui.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

class PdFilterChip extends StatelessWidget {
  const PdFilterChip({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Pd.onLime : Pd.text;
    return _Chip(
      selected: selected,
      onTap: onTap,
      color: selected ? Pd.lime : Pd.line,
      child: Text.rich(
        TextSpan(
          text: label.toUpperCase(),
          children: [
            if (count != null)
              TextSpan(
                text: ' $count',
                style: TextStyle(color: color.withValues(alpha: 0.7)),
              ),
          ],
        ),
        textAlign: TextAlign.center,
        style: PdType.monoButton.copyWith(color: color),
      ),
    );
  }
}

class PdChoiceChip extends StatelessWidget {
  const PdChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onPaper = true,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool onPaper;

  @override
  Widget build(BuildContext context) {
    final color = onPaper
        ? (selected ? Pd.paper : Pd.ink2)
        : (selected ? Pd.onLime : Pd.text);
    return _Chip(
      selected: selected,
      onTap: onTap,
      color: onPaper ? Pd.ink2 : (selected ? Pd.lime : Pd.line),
      child: Text(
        label.toUpperCase(),
        textAlign: TextAlign.center,
        style: PdType.monoButton.copyWith(color: color),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.selected,
    required this.onTap,
    required this.color,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      pressedOpacity: 0.7,
      minimumSize: const Size.square(Pd.tapMin),
      focusColor: Pd.lime,
      onPressed: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Pd.s8 + Pd.s1),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Pd.s3, vertical: Pd.s1),
        decoration: BoxDecoration(
          color: selected ? color : null,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(Pd.rSm),
        ),
        child: child,
      ),
    ),
  );
}

class PdChipRow extends StatelessWidget {
  const PdChipRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
    child: Row(
      spacing: Pd.s2,
      children: children,
    ),
  );
}
