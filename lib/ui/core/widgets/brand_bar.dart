import 'package:cupertino_ui/cupertino_ui.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';
import 'icons.dart';

/// The top bar from the iOS designs: the PaperDrawer mark and wordmark on the
/// left, an optional [trailing] action on the right. It sits below the status
/// bar (it adds the top safe-area inset itself) and is [Pd.appbarIos] tall.
///
/// Use [PdBrandAction] for the lime "Scan or add" style trailing button.
class PdBrandBar extends StatelessWidget {
  const PdBrandBar({this.trailing, this.onMarkTap, super.key});

  final Widget? trailing;

  /// Optional tap on the mark + wordmark (for example "go to the vault").
  final VoidCallback? onMarkTap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    Widget brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PaperDrawerMark(size: 21),
        const SizedBox(width: Pd.s2),
        Flexible(
          child: Text(
            'Paper Drawer',
            style: PdType.wordmark,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    brand = Semantics(
      label: 'Paper Drawer',
      header: onMarkTap == null,
      button: onMarkTap != null,
      excludeSemantics: true,
      child: brand,
    );
    if (onMarkTap != null) {
      brand = GestureDetector(
        key: const ValueKey('brand-mark'),
        behavior: HitTestBehavior.opaque,
        onTap: onMarkTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Pd.tapMin),
          child: Align(widthFactor: 1, child: brand),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(Pd.margin, top, Pd.margin, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Pd.appbarIos),
        // The action keeps up to 60% of the width; the wordmark truncates
        // first at large text sizes.
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: brand),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Pd.s3),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.6,
                  ),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact lime action for [PdBrandBar.trailing]: 44pt tall, radius-sm,
/// 14pt side padding, 18pt icon, callout-weight label (15/600).
class PdBrandAction extends StatefulWidget {
  const PdBrandAction({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<PdBrandAction> createState() => _PdBrandActionState();
}

class _PdBrandActionState extends State<PdBrandAction> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final style = PdType.callout.copyWith(
      fontWeight: FontWeight.w600,
      fontVariations: const [FontVariation.weight(600)],
      color: Pd.onLime,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Pd.appbarIos),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: enabled ? (_down ? Pd.limePressed : Pd.lime) : Pd.surface3,
              borderRadius: BorderRadius.circular(Pd.rSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: Pd.iconSm,
                    color: enabled ? Pd.onLime : Pd.textSubtle,
                  ),
                  const SizedBox(width: Pd.s2),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: enabled
                        ? style
                        : style.copyWith(color: Pd.textSubtle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
