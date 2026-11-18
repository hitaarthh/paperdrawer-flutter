import 'package:flutter/widgets.dart';

import '../../../domain/models/item.dart';
import '../../../domain/models/shared_vault.dart';
import '../../core/widgets/snackbar.dart';
import '../account/shared_session.dart';
import 'add_sheet.dart';

Future<void> showSharedAdd(
  BuildContext context,
  SharedSession session,
  SharedVault vault,
) async {
  final choice = await showAddSheet(
    context,
    used: vault.items.length,
    shared: true,
    onBasePlan: vault.onBasePlan,
  );
  if (!context.mounted || choice == null) return;
  await openSharedAdd(
    context,
    session,
    choice.kind,
    manual: choice.action == AddSheetAction.manual,
  );
}

Future<void> openSharedAdd(
  BuildContext context,
  SharedSession session,
  ItemKind kind, {
  bool manual = false,
}) async {
  final type = kind == ItemKind.agreement ? 'other' : kind.name;
  final path = switch ((manual, kind)) {
    (false, _) => '/add?type=$type',
    (true, ItemKind.bill) => '/bills/new',
    (true, _) => '/documents/new?type=$type',
  };
  try {
    await session.openWeb(path);
  } catch (_) {
    if (context.mounted) {
      showPdSnackbar(context, 'Couldn’t open Paper Drawer web.');
    }
  }
}
