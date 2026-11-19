import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/paper.dart';

class VaultEmpty extends StatelessWidget {
  const VaultEmpty({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ReceiptPaper(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Pd.s3,
      children: [
        Text('WELCOME TO PAPER DRAWER',
            style: PdType.label.copyWith(color: Pd.inkMuted)),
        const DashedRule(),
        Semantics(
          header: true,
          child: Text('Add your first file.',
              style: PdType.title1.copyWith(color: Pd.ink)),
        ),
        Text(
          'Pick a bill, policy, vehicle document or agreement from Files. '
          'Add the dates you want to remember.',
          style: PdType.callout.copyWith(color: Pd.ink2),
        ),
        _InkButton(
          key: const ValueKey('drawer-add-first-file'),
          label: 'Add a file',
          onPressed: onAdd,
        ),
      ],
    ),
  );
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
            const Icon(LucideIcons.plus, size: Pd.iconSm, color: Pd.lime),
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

