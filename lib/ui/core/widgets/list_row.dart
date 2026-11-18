import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

class PdListGroup extends StatelessWidget {
  const PdListGroup({this.header, required this.children, super.key});

  final String? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (header != null) ...[
        Semantics(
          header: true,
          child: Text(
            header!.toUpperCase(),
            style: PdType.label.copyWith(color: Pd.textMuted),
          ),
        ),
        const SizedBox(height: Pd.s2),
      ],
      DecoratedBox(
        decoration: BoxDecoration(
          color: Pd.surface1,
          borderRadius: BorderRadius.circular(Pd.rSm),
        ),
        child: Column(
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: Pd.s4),
                  child: SizedBox(
                    height: 1,
                    width: double.infinity,
                    child: ColoredBox(color: Pd.hairline),
                  ),
                ),
              child,
            ],
          ],
        ),
      ),
    ],
  );
}

class PdListRow extends StatelessWidget {
  const PdListRow({
    required this.title,
    this.value,
    this.trailing,
    this.chevron = false,
    this.destructive = false,
    this.actionIcon,
    this.onTap,
    this.tag,
    super.key,
  });

  final String title;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final bool destructive;
  final IconData? actionIcon;
  final VoidCallback? onTap;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final detail = value;
    final stackValue = detail != null && isLargeText(context);
    final text = Text(
      title,
      style: PdType.bodyStrong.copyWith(color: destructive ? Pd.signal : Pd.text),
    );
    final valueLabel = detail == null ? null : Text(
      detail,
      style: PdType.callout.copyWith(color: Pd.textMuted),
      textAlign: stackValue ? TextAlign.start : TextAlign.end,
    );
    final row = Container(
      constraints: const BoxConstraints(minHeight: Pd.s12 + Pd.s2),
      padding: const EdgeInsets.symmetric(horizontal: Pd.s4, vertical: Pd.s2),
      child: Row(
        spacing: Pd.s2,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: Pd.s1,
              children: [
                if (tag == null)
                  text
                else
                  Wrap(
                    spacing: Pd.s2,
                    runSpacing: Pd.s1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      text,
                      Text(
                        tag!.toUpperCase(),
                        style: PdType.label.copyWith(color: Pd.lime),
                      ),
                    ],
                  ),
                if (stackValue) valueLabel!,
              ],
            ),
          ),
          if (valueLabel != null && !stackValue) Flexible(child: valueLabel),
          ?trailing,
          if (actionIcon case final icon?) Icon(icon, size: Pd.iconSm, color: Pd.textSubtle),
          if (chevron) const Icon(LucideIcons.chevronRight, size: Pd.iconSm, color: Pd.textSubtle),
        ],
      ),
    );
    final tap = onTap;
    return tap == null
        ? row
        : CupertinoButton(
            onPressed: tap,
            pressedOpacity: 0.7,
            minimumSize: const Size.square(Pd.tapMin),
            padding: EdgeInsets.zero,
            focusColor: Pd.lime,
            child: row,
          );
  }
}

class PdSwitch extends StatelessWidget {
  const PdSwitch({required this.value, this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => CupertinoSwitch(
    value: value,
    onChanged: onChanged,
    activeTrackColor: Pd.lime,
    inactiveTrackColor: Pd.surface3,
    thumbColor: Pd.bg,
    inactiveThumbColor: Pd.textMuted,
    focusColor: Pd.lime,
  );
}
