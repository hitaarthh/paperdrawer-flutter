import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart' show CircularProgressIndicator;

import '../theme/tokens.dart';
import '../theme/type.dart';

enum _Variant { primary, secondary, onPaper, text }

class PdButton extends StatelessWidget {
  const PdButton.primary({
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    super.key,
  }) : _variant = _Variant.primary;

  const PdButton.secondary({
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    super.key,
  }) : _variant = _Variant.secondary;

  const PdButton.onPaper({
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    super.key,
  }) : _variant = _Variant.onPaper;

  const PdButton.text({
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = false,
    this.busy = false,
    super.key,
  }) : _variant = _Variant.text;

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool expand;
  final bool busy;
  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    final primary = _variant == _Variant.primary;
    final mono = _variant == _Variant.secondary || _variant == _Variant.onPaper;
    final color = switch (_variant) {
      _ when onPressed == null => Pd.textSubtle,
      _Variant.primary => Pd.onLime,
      _Variant.secondary => Pd.text,
      _Variant.onPaper => Pd.ink2,
      _Variant.text => Pd.lime,
    };
    final border = switch (_variant) {
      _Variant.secondary => Pd.line,
      _Variant.onPaper => onPressed == null ? Pd.paperRule : Pd.ink2,
      _ => null,
    };
    return CupertinoButton(
      onPressed: busy ? null : onPressed,
      padding: EdgeInsets.zero,
      pressedOpacity: 0.7,
      focusColor: Pd.lime,
      minimumSize: const Size.square(Pd.tapMin),
      borderRadius: BorderRadius.circular(Pd.rSm),
      child: Container(
        width: expand ? double.infinity : null,
        constraints: BoxConstraints(
          minHeight: primary ? Pd.controlH : Pd.tapMin,
          minWidth: Pd.tapMin,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: mono ? Pd.s3 : Pd.s4,
          vertical: Pd.s2,
        ),
        decoration: BoxDecoration(
          color: primary ? (onPressed == null ? Pd.surface3 : Pd.lime) : null,
          borderRadius: BorderRadius.circular(Pd.rSm),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) ...[
              SizedBox.square(
                dimension: Pd.iconSm,
                child: CircularProgressIndicator(color: color, strokeWidth: 2),
              ),
              const SizedBox(width: Pd.s2),
            ] else if (icon != null) ...[
              IconTheme.merge(
                data: IconThemeData(color: color, size: Pd.iconSm),
                child: icon!,
              ),
              const SizedBox(width: Pd.s2),
            ],
            Flexible(
              child: Text(
                mono ? label.toUpperCase() : label,
                textAlign: TextAlign.center,
                style: (mono ? PdType.monoButton : PdType.bodyStrong).copyWith(
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
