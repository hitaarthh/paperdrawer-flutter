import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/pd_metrics.dart';
import '../../theme/pd_theme.dart';
import '../pd_pressable.dart';

/// An inset grouped list on the room (`surface-1`, `radius-md`) with an
/// optional `label` header and `footnote` footer. Rows are separated by
/// `hairline`s. On iOS 26 the screens may use the system list instead.
final class PdListGroup extends StatelessWidget {
  const PdListGroup({
    required this.children,
    this.header,
    this.footer,
    super.key,
  });

  final List<Widget> children;

  /// Caps section header.
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    final header = this.header;
    final footer = this.footer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PdSpace.s4,
              0,
              PdSpace.s4,
              PdSpace.s2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                header,
                style: pd.type.label.copyWith(color: pd.colors.textMuted),
              ),
            ),
          ),
        DecoratedBox(
          decoration: ShapeDecoration(
            color: pd.colors.surface1,
            shape: PdRadius.continuous(PdRadius.md),
          ),
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: PdRadius.continuous(PdRadius.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, row) in children.indexed)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: index == 0
                          ? null
                          : Border(top: BorderSide(color: pd.colors.hairline)),
                    ),
                    child: row,
                  ),
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PdSpace.s4,
              PdSpace.s2,
              PdSpace.s4,
              0,
            ),
            child: Text(
              footer,
              style: pd.type.footnote.copyWith(color: pd.colors.textSubtle),
            ),
          ),
      ],
    );
  }
}

/// One row: optional 22 pt icon (`text-2`), the title (`body` `text`), then
/// one trailing element: a [value] (`callout` `text-muted`), a chevron, a
/// custom [trailing] (a switch), or nothing. [destructive] rows are `danger`
/// with no chevron. Rows are at least 52 pt tall.
final class PdListRow extends StatelessWidget {
  const PdListRow({
    required this.title,
    this.icon,
    this.value,
    this.chevron = false,
    this.trailing,
    this.destructive = false,
    this.onPressed,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final IconData? icon;
  final String? value;
  final bool chevron;
  final Widget? trailing;
  final bool destructive;
  final VoidCallback? onPressed;

  /// Defaults to "title, value".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    final icon = this.icon;
    final value = this.value;
    final trailing = this.trailing;
    final titleColor = destructive ? pd.colors.danger : pd.colors.text;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PdSize.listRow),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PdSpace.s4,
          vertical: PdSpace.s2,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: PdSize.iconBar,
                color: destructive ? pd.colors.danger : pd.colors.text2,
              ),
              const SizedBox(width: PdSpace.s3),
            ],
            Expanded(
              child: Text(
                title,
                style: pd.type.body.copyWith(color: titleColor),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: PdSpace.s3),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: pd.type.callout.copyWith(color: pd.colors.textMuted),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: PdSpace.s3),
              trailing,
            ],
            if (chevron && !destructive) ...[
              const SizedBox(width: PdSpace.s2),
              Icon(
                LucideIcons.chevronRight,
                size: PdSize.iconButton,
                color: pd.colors.textSubtle,
              ),
            ],
          ],
        ),
      ),
    );
    if (onPressed == null) {
      return MergeSemantics(child: row);
    }
    return PdPressable(
      semanticLabel:
          semanticLabel ?? (value == null ? title : '$title, $value'),
      onPressed: onPressed,
      pressedScale: 1,
      focusRadius: PdRadius.md,
      child: row,
    );
  }
}
