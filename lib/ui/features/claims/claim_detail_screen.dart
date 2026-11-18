import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../domain/claim_message.dart';
import '../../../domain/formats.dart';
import '../../../domain/ladders.dart';
import '../../../domain/models/claim.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/claim_ladder.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import 'claim_detail_sections.dart';
import 'claim_detail_view_model.dart';
import 'claim_status_ticket.dart';

class ClaimDetailScreen extends StatefulWidget {
  const ClaimDetailScreen({required this.id, super.key});

  final String id;

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

enum _ClaimAction { reply, note, reopen, delete }

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  late final _model = ClaimDetailViewModel(
    widget.id,
    context.read(),
    context.read(),
    context.read(),
    context.read(),
  );

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() intent, {String? success}) async {
    final done = await intent();
    if (!mounted) return;
    final message = done ? success : _model.error;
    if (message != null) showPdSnackbar(context, message, success: done);
  }

  Future<void> _showActions(Claim claim) async {
    if (_model.busy) return;
    final action = await showPdActions(
      context,
      title: 'Claim actions',
      actions: [
        if (!claim.isOpen)
          const PdAction(label: 'Reopen claim', value: _ClaimAction.reopen),
        const PdAction(
          label: 'Delete claim',
          value: _ClaimAction.delete,
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    if (action == _ClaimAction.reopen) {
      await _run(_model.reopen, success: 'Claim reopened');
    } else if (action == _ClaimAction.delete) {
      await _deleteClaim();
    }
  }

  Future<void> _logUpdate(Claim claim) async {
    final action = claim.isOpen
        ? await showPdActions(
            context,
            title: 'Log an update',
            actions: const [
              PdAction(label: 'Log a reply', value: _ClaimAction.reply),
              PdAction(label: 'Add a note', value: _ClaimAction.note),
            ],
          )
        : _ClaimAction.note;
    if (!mounted || action == null) return;
    if (action == _ClaimAction.reply) {
      final reply = await _askForNote(
        title: 'Log a reply',
        fieldLabel: 'WHAT DID THEY SAY?',
        saveLabel: 'Log reply',
      );
      if (!mounted || reply == null) return;
      await _run(() => _model.logReply(reply), success: 'Reply logged');
    } else {
      final note = await _askForNote(
        title: 'Add a note',
        fieldLabel: 'WHAT HAPPENED?',
        saveLabel: 'Save note',
        requiredNote: true,
      );
      if (!mounted || note == null) return;
      await _run(() => _model.addNote(note), success: 'Note saved');
    }
  }

  Future<void> _markSettled() async {
    final outcome = await _askForNote(
      title: 'Mark settled',
      fieldLabel: 'HOW WAS IT RESOLVED?',
      saveLabel: 'Mark settled',
    );
    if (!mounted || outcome == null) return;
    await _run(() => _model.settle(outcome), success: 'Claim settled');
  }

  Future<String?> _askForNote({
    required String title,
    required String fieldLabel,
    required String saveLabel,
    bool requiredNote = false,
  }) => showPdSheet<String>(
    context,
    title: title,
    body: ClaimNoteForm(
      fieldLabel: fieldLabel,
      saveLabel: saveLabel,
      requiredNote: requiredNote,
    ),
  );

  Future<void> _deleteClaim() async {
    final confirmed = await showPdConfirm(
      context,
      title: 'Delete this claim?',
      message:
          'This removes the claim and its log. Your item stays in the vault.',
      confirmLabel: 'Delete claim',
      destructive: true,
    );
    if (!mounted || !confirmed) return;
    final deleted = await _model.delete();
    if (!mounted) return;
    if (deleted) {
      context.go(Routes.claims);
      showPdSnackbar(context, 'Claim deleted', success: true);
    } else if (_model.error case final error?) {
      showPdSnackbar(context, error);
    }
  }

  Future<void> _advance(String next) async {
    final confirmed = await showPdConfirm(
      context,
      title: 'Move to $next?',
      message: 'Your new message will be drafted for this step.',
      confirmLabel: 'Move to next step',
    );
    if (!mounted || !confirmed) return;
    await _run(_model.advance, success: 'Moved to $next');
  }

  void _share(BuildContext anchor, ClaimMessage message) {
    final box = anchor.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    _run(() => _model.share(message, origin: origin));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _model,
    builder: (context, _) {
      final claim = _model.claim;
      if (claim == null) {
        return PdPushedScaffold(
          backLabel: 'Claims',
          title: 'Claim',
          children: [
            DashedTile(
              title: 'This claim is missing',
              body: 'Open your claims to choose a different one.',
              action: PdButton.primary(
                label: 'Open claims',
                onPressed: () => context.go(Routes.claims),
              ),
            ),
          ],
        );
      }
      final today = _model.today;
      return PdPushedScaffold(
        backLabel: 'CLAIMS',
        backStyle: PdType.monoButton.copyWith(color: Pd.text),
        kicker:
            '${claim.type.caps} · ${claim.itemLabel.toUpperCase()} · '
            'OPENED ${longDate(claim.openedOn).toUpperCase()}',
        title: claim.title,
        titleStyle: PdType.trackerTitle,
        actions: [
          if (claim.isOpen)
            Flexible(
              flex: 2,
              child: PdButton.text(
                key: const ValueKey('mark-claim-settled'),
                label: 'Mark settled',
                monospaced: true,
                onPressed: _model.busy ? null : _markSettled,
              ),
            ),
          PdNavIcon(
            key: const ValueKey('claim-actions'),
            icon: const Icon(LucideIcons.ellipsis),
            semanticLabel: 'Claim actions',
            onTap: () => _showActions(claim),
          ),
        ],
        children: [
          if (claim.isOpen) ...[
            ClaimStatusTicket(claim: claim, today: today),
            const SizedBox(height: Pd.s6),
            ..._openClaimSections(claim),
          ] else
            ClaimOutcome(claim: claim, days: claim.day(today)),
          const SizedBox(height: Pd.s6),
          ClaimLadder(claim: claim, today: today),
          const SizedBox(height: Pd.s6),
          ClaimActivityLog(
            events: claim.events,
            onUpdate: _model.busy ? null : () => _logUpdate(claim),
          ),
        ],
      );
    },
  );

  List<Widget> _openClaimSections(Claim claim) {
    final recommended = recommendedStepFor(claim, _model.today);
    final index = recommended ?? claim.step;
    final step = ladderFor(claim.type)[index];
    final message = _model.messageFor(claim, index);
    final recipient = stepTitle(claim.type, index);
    final portal = step.url;
    final phone = step.phone;
    final next = _model.nextStepTitle(claim);
    return [
      Semantics(
        header: true,
        child: Text(
          recommended == null ? 'Write to $recipient' : 'Next step\n$recipient',
          style: PdType.title2,
        ),
      ),
      const SizedBox(height: Pd.s3),
      ClaimDraftCard(message: message),
      const SizedBox(height: Pd.s3),
      PdButton.primary(
        key: const ValueKey('open-claim-mail'),
        label: 'Open in mail app',
        expand: true,
        onPressed: _model.busy
            ? null
            : () => _run(() => _model.openMail(message)),
      ),
      const SizedBox(height: Pd.s2),
      Row(
        spacing: Pd.s2,
        children: [
          Expanded(
            child: PdButton.secondary(
              key: const ValueKey('copy-claim-message'),
              label: 'Copy email',
              onPressed: _model.busy
                  ? null
                  : () => _run(
                      () => _model.copy(message),
                      success: 'Email copied',
                    ),
            ),
          ),
          Expanded(
            child: PdButton.secondary(
              key: const ValueKey('claim-log-sent'),
              label: recommended == null && _model.hasLoggedSent(claim)
                  ? 'Log another send'
                  : 'I’ve sent it',
              onPressed: _model.busy
                  ? null
                  : () => _run(
                      () => _model.logSent(index),
                      success: 'Sent message logged',
                    ),
            ),
          ),
        ],
      ),
      const SizedBox(height: Pd.s3),
      Text(
        'Add the recipient’s email address and any supporting documents in your mail app.',
        style: PdType.footnote.copyWith(color: Pd.textMuted),
      ),
      Wrap(
        spacing: Pd.s2,
        children: [
          Builder(
            builder: (anchor) => PdButton.text(
              key: const ValueKey('share-claim-message'),
              label: 'Share draft',
              icon: const Icon(CupertinoIcons.share, size: Pd.iconSm),
              onPressed: _model.busy ? null : () => _share(anchor, message),
            ),
          ),
          if (next != null && _model.canAdvance(claim))
            PdButton.text(
              key: const ValueKey('advance-claim'),
              label: 'Move to next step',
              onPressed: _model.busy ? null : () => _advance(next),
            ),
        ],
      ),
      if (portal != null || phone != null) ...[
        const SizedBox(height: Pd.s3),
        Wrap(
          spacing: Pd.s2,
          runSpacing: Pd.s2,
          children: [
            if (phone != null)
              PdButton.secondary(
                label: 'Call $phone',
                icon: const Icon(LucideIcons.phone, size: Pd.iconSm),
                onPressed: _model.busy
                    ? null
                    : () => _run(
                        () => _model.openLink(Uri(scheme: 'tel', path: phone)),
                      ),
              ),
            if (portal != null)
              PdButton.secondary(
                label: step.urlLabel ?? 'Open website',
                icon: const Icon(LucideIcons.externalLink, size: Pd.iconSm),
                onPressed: _model.busy
                    ? null
                    : () => _run(() => _model.openLink(Uri.parse(portal))),
              ),
          ],
        ),
      ],
    ];
  }
}
