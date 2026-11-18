import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../domain/models/item.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/paper.dart';

/// The first-run vault: a welcome receipt that leads to the camera, then
/// three other kinds of paper to start with.
class VaultEmpty extends StatelessWidget {
  const VaultEmpty({required this.onScan, required this.onStart, super.key});

  final VoidCallback onScan;
  final ValueChanged<ItemKind> onStart;

  static const _starts = [
    (
      ItemKind.policy,
      'POLICY',
      'An insurance policy',
      'Health, motor or gadget.',
    ),
    (
      ItemKind.vehicle,
      'VEHICLE',
      'Vehicle papers',
      'PUC, insurance and service dates.',
    ),
    (
      ItemKind.agreement,
      'AGREEMENT',
      'A rent agreement',
      'Renewal date and deposit.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: Pd.s6,
    children: [
      _WelcomeReceipt(onScan: onScan),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Pd.s2),
            child: Semantics(
              header: true,
              child: Text(
                'OR START WITH',
                style: PdType.label.copyWith(color: Pd.textMuted),
              ),
            ),
          ),
          for (final (kind, tag, title, body) in _starts)
            _StartRow(
              key: ValueKey('vault-start-${kind.name}'),
              tag: tag,
              title: title,
              body: body,
              onTap: () => onStart(kind),
            ),
        ],
      ),
    ],
  );
}

class _WelcomeReceipt extends StatelessWidget {
  const _WelcomeReceipt({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final caption = PdType.label.copyWith(color: Pd.inkMuted);
    return ReceiptPaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s3,
        children: [
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              spacing: Pd.s2,
              children: [
                Text('NO. 000000', style: caption),
                Flexible(
                  child: Text(
                    'WELCOME TO PAPERDRAWER',
                    textAlign: TextAlign.end,
                    style: caption.copyWith(
                      fontWeight: FontWeight.w400,
                      fontVariations: const [FontVariation.weight(400)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const DashedRule(),
          Semantics(
            header: true,
            child: Text(
              'Add the last thing you bought.',
              style: PdType.title1.copyWith(color: Pd.ink),
            ),
          ),
          Text(
            'Snap its bill. We’ll read it, set the return and warranty '
            'dates, and remind you before they pass. Takes under a minute.',
            style: PdType.callout.copyWith(color: Pd.ink2),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Pd.s1),
            child: _InkButton(
              key: const ValueKey('scan-first-bill'),
              label: 'Scan your first bill',
              onPressed: onScan,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dark ink button printed on the receipt, with a lime label.
class _InkButton extends StatelessWidget {
  const _InkButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: CupertinoButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      pressedOpacity: 0.7,
      focusColor: Pd.lime,
      minimumSize: const Size.square(Pd.tapMin),
      borderRadius: BorderRadius.circular(Pd.rSm),
      child: Container(
        constraints: const BoxConstraints(minHeight: Pd.controlH),
        padding: const EdgeInsets.symmetric(horizontal: Pd.s4, vertical: Pd.s2),
        decoration: BoxDecoration(
          color: Pd.ink,
          borderRadius: BorderRadius.circular(Pd.rSm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: Pd.s2,
          children: [
            const PdIcon(PdGlyph.scan, size: Pd.iconSm, color: Pd.lime),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: PdType.bodyStrong.copyWith(color: Pd.lime),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StartRow extends StatelessWidget {
  const _StartRow({
    required this.tag,
    required this.title,
    required this.body,
    required this.onTap,
    super.key,
  });

  final String tag;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wide = !isLargeText(context);
    return Semantics(
      button: true,
      label: 'Add ${title[0].toLowerCase()}${title.substring(1)}. $body',
      excludeSemantics: true,
      child: CupertinoButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        pressedOpacity: 0.7,
        focusColor: Pd.lime,
        minimumSize: Size.zero,
        child: Container(
          constraints: const BoxConstraints(minHeight: Pd.s12 + Pd.s4),
          padding: const EdgeInsets.symmetric(vertical: Pd.s2),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Pd.hairline)),
          ),
          child: Row(
            spacing: Pd.s3,
            children: [
              if (wide)
                SizedBox(
                  width: Pd.s12 + Pd.s8,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      tag,
                      maxLines: 1,
                      style: PdType.label.copyWith(color: Pd.textMuted),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!wide)
                      Text(
                        tag,
                        style: PdType.label.copyWith(color: Pd.textMuted),
                      ),
                    Text(title, style: PdType.bodyStrong),
                    Text(
                      body,
                      style: PdType.footnote.copyWith(color: Pd.textMuted),
                    ),
                  ],
                ),
              ),
              Text('ADD →', style: PdType.label.copyWith(color: Pd.lime)),
            ],
          ),
        ),
      ),
    );
  }
}
