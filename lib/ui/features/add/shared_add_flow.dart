import 'package:flutter/widgets.dart';

import '../../../domain/item_status.dart';
import '../../../domain/models/shared_vault.dart';
import '../../core/widgets/snackbar.dart';
import 'add_flow.dart';
import 'add_sheet.dart';

Future<void> showSharedAdd(
  BuildContext context,
  SharedVault vault,
) async {
  if (!_hasRoom(context, vault)) return;
  final choice = await showAddSheet(
    context,
    used: vault.items.length,
    onBasePlan: vault.onBasePlan,
  );
  if (!context.mounted || choice == null) return;
  await AddFlow.openChoice(context, choice, singleOriginal: true);
}

Future<void> openSharedAdd(
  BuildContext context,
  SharedVault vault,
  AddSheetChoice choice,
) async {
  if (!_hasRoom(context, vault)) return;
  await AddFlow.openChoice(context, choice, singleOriginal: true);
}

bool _hasRoom(BuildContext context, SharedVault vault) {
  if (!vault.onBasePlan || vault.items.length < baseItemLimit) return true;
  showPdSnackbar(
    context,
    'Your Base vault is full. Make room before adding another item.',
  );
  return false;
}
