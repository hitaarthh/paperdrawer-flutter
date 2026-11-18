import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';

void showPdSnackbar(
  BuildContext context,
  String message, {
  bool success = false,
  String? action,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.down,
      margin: const EdgeInsets.all(Pd.s4),
      padding: const EdgeInsets.symmetric(horizontal: Pd.s4, vertical: Pd.s2),
      backgroundColor: Pd.surface2,
      elevation: Pd.s2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Pd.rMd),
        side: const BorderSide(color: Pd.hairline),
      ),
      // Action snackbars persist by default in material_ui 1.11; keep the
      // timed dismissal so an Undo never covers the next screen's button.
      persist: false,
      duration: Duration(seconds: action != null && onAction != null ? 8 : 4),
      action: action == null || onAction == null
          ? null
          : SnackBarAction(
              label: action.toUpperCase(),
              textColor: Pd.lime,
              onPressed: onAction,
            ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Pd.controlH - Pd.s4),
        child: Row(
          spacing: Pd.s2,
          children: [
            if (success)
              const Icon(LucideIcons.check, color: Pd.settled, size: Pd.iconSm),
            Expanded(child: Text(message, style: PdType.callout)),
          ],
        ),
      ),
    ),
  );
}
