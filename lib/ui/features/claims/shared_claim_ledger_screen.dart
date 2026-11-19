import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../routing/router.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/snackbar.dart';
import '../account/shared_session.dart';
import 'claim_ledger_screen.dart';

class SharedClaimLedgerScreen extends StatelessWidget {
  const SharedClaimLedgerScreen(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    final vault = session.vault;
    final claim = vault?.claims.where((entry) => entry.id == id).firstOrNull;
    if (claim == null) return MissingLedger(loading: session.loading);
    final item = vault?.items.where((entry) => entry.item.id == claim.itemId).firstOrNull;
    final files = {
      for (final file in [...?item?.originals, ...claim.originals]) file.path: file,
    };
    return ClaimLedgerScreen(
      title: claim.title,
      itemLabel: claim.itemLabel,
      opened: claim.opened,
      settled: claim.settled,
      followUp: claim.followUp,
      entries: claim.ledger,
      clock: session.today,
      files: [
        for (final file in files.values)
          (name: file.name, open: () => session.openOriginal(file)),
      ],
      serial: item?.item.draft.serialNumber ?? '',
      pickPhoto: session.pickLedgerPhoto,
      addEntry: (entry) => session.addLedgerEntry(id, entry),
      setFollowUp: (at) => session.setFollowUp(id, at),
      enableNotifications: session.enableFollowUpNotifications,
      share: (pdf, origin) => session.shareFiles([pdf], origin),
      settle: (outcome) async {
        if (!await session.settleClaim(id, outcome)) {
          throw const FormatException('The claim is busy. Try again in a moment.');
        }
      },
      busy: session.claimBusy,
      settleKey: 'shared-mark-claim-settled',
      actions: [
        PdButton.text(
          label: 'Edit',
          monospaced: true,
          onPressed: () async {
            try {
              await session.openWeb(claim.webPath);
            } catch (_) {
              if (context.mounted) showPdSnackbar(context, 'Couldn’t open this claim on the web.');
            }
          },
        ),
        if (claim.draft != null || claim.nextStep != null)
          PdButton.text(
            label: 'Guidance',
            onPressed: () => context.push(Routes.claimGuidance(id)),
          ),
      ],
    );
  }
}
