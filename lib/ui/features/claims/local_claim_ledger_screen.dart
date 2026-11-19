import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/capture_service.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../data/services/today.dart';
import '../../../domain/models/claim.dart';
import '../../../routing/router.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import 'claim_ledger_screen.dart';

enum _LedgerAction { guidance, reopen, delete }

class LocalClaimLedgerScreen extends StatelessWidget {
  const LocalClaimLedgerScreen({required this.id, super.key});
  final String id;

  Future<bool> _enableNotifications(BuildContext context) async {
    final settings = context.read<SettingsRepository>();
    if (settings.remindersOn) return true;
    final scheduler = context.read<ReminderScheduler?>();
    if (scheduler == null) return false;
    try {
      if (!await scheduler.requestPermission()) return false;
      await settings.setRemindersOn(true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showActions(BuildContext context, Claim claim, ClaimRepository claims, Today today) async {
    final action = await showPdActions<_LedgerAction>(
      context,
      title: 'Claim actions',
      actions: [
        if (claim.nudgeDays > 0)
          const PdAction(label: 'Claim guidance', value: _LedgerAction.guidance),
        if (!claim.isOpen)
          const PdAction(label: 'Reopen claim', value: _LedgerAction.reopen),
        const PdAction(label: 'Delete claim', value: _LedgerAction.delete, destructive: true),
      ],
    );
    if (!context.mounted || action == null) return;
    try {
      switch (action) {
        case _LedgerAction.guidance:
          context.push(Routes.claimGuidance(claim.id));
        case _LedgerAction.reopen:
          await claims.reopen(claim.id, today.value);
        case _LedgerAction.delete:
          final confirmed = await showPdConfirm(
            context,
            title: 'Delete this claim?',
            message: 'This removes the ledger and its photos. Your item stays in the vault.',
            confirmLabel: 'Delete claim',
            destructive: true,
          );
          if (!context.mounted || !confirmed) return;
          await claims.delete(claim.id);
          if (context.mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.claims);
            }
          }
      }
    } on FormatException catch (error) {
      if (context.mounted) showPdSnackbar(context, error.message);
    } catch (_) {
      if (context.mounted) showPdSnackbar(context, 'The claim couldn’t be updated. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final claims = context.watch<ClaimRepository>();
    final claim = claims.byId(id);
    if (claim == null) return const MissingLedger();
    final clock = context.watch<Today>();
    final items = context.watch<ItemRepository>();
    final item = items.byId(claim.itemId ?? '');
    final actions = context.read<DrawerActions>();
    final capture = context.read<CaptureService>();
    final files = [
      ...?item?.attachments,
      for (final event in claim.events)
        if (event.photo case final photo?) photo,
    ];
    return ClaimLedgerScreen(
      title: claim.title,
      itemLabel: claim.itemLabel,
      opened: claim.openedOn,
      settled: claim.settledOn,
      followUp: claim.followUp,
      entries: claim.ledger,
      clock: clock,
      files: [for (final file in files) (name: file.name, open: () => actions.openAttachment(file))],
      serial: item?.draft.serialNumber ?? '',
      pickPhoto: capture.pickLedgerPhoto,
      addEntry: (entry) => claims.addEntry(id, entry, clock.instant),
      setFollowUp: (at) => claims.setFollowUp(id, at, clock.instant),
      enableNotifications: () => _enableNotifications(context),
      share: (pdf, origin) => actions.shareFiles([pdf], origin: origin),
      settle: (outcome) => claims.settle(id, clock.value, note: outcome),
      actions: [
        PdNavIcon(
          key: const ValueKey('claim-actions'),
          icon: const Icon(LucideIcons.ellipsis),
          semanticLabel: 'Claim actions',
          onTap: () => _showActions(context, claim, claims, clock),
        ),
      ],
    );
  }
}
