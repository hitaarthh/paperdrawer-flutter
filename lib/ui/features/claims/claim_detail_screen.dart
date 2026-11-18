import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../domain/claim_message.dart';
import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
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
import '../../core/widgets/stamp.dart';
import 'claim_detail_sections.dart';
import 'claim_detail_view_model.dart';
import 'claims_view_model.dart';

class ClaimDetailScreen extends StatefulWidget {
  const ClaimDetailScreen({required this.id, super.key});

  final String id;

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

enum _ClaimAction { reply, note, settle, reopen, delete }

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
        if (claim.isOpen)
          const PdAction(label: 'Log a reply', value: _ClaimAction.reply),
        const PdAction(label: 'Add a note', value: _ClaimAction.note),
        if (claim.isOpen)
          const PdAction(label: 'Mark settled', value: _ClaimAction.settle)
        else
          const PdAction(label: 'Reopen claim', value: _ClaimAction.reopen),
        const PdAction(
          label: 'Delete claim',
          value: _ClaimAction.delete,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _ClaimAction.reply:
        final reply = await _askForNote(
          title: 'Log a reply',
          fieldLabel: 'WHAT DID THEY SAY?',
          saveLabel: 'Log reply',
        );
        if (!mounted || reply == null) return;
        await _run(() => _model.logReply(reply), success: 'Reply logged');
      case _ClaimAction.note:
        final note = await _askForNote(
          title: 'Add a note',
          fieldLabel: 'WHAT HAPPENED?',
          saveLabel: 'Save note',
          requiredNote: true,
        );
        if (!mounted || note == null) return;
        await _run(() => _model.addNote(note), success: 'Note saved');
      case _ClaimAction.settle:
        final outcome = await _askForNote(
          title: 'Mark settled',
          fieldLabel: 'HOW WAS IT RESOLVED?',
          saveLabel: 'Mark settled',
        );
        if (!mounted || outcome == null) return;
        await _run(() => _model.settle(outcome), success: 'Claim settled');
      case _ClaimAction.reopen:
        await _run(_model.reopen, success: 'Claim reopened');
      case _ClaimAction.delete:
        await _deleteClaim();
    }
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
      final status = claim.status(_model.today).stamp;
      final next = _model.nextStepTitle(claim);
      final day = claim.day(_model.today);
      return PdPushedScaffold(
        backLabel: 'Claims',
        kicker: claim.type.caps,
        title: claim.title,
        actions: [
          PdNavIcon(
            key: const ValueKey('claim-actions'),
            icon: const Icon(LucideIcons.ellipsis),
            semanticLabel: 'Claim actions',
            onTap: () => _showActions(claim),
          ),
        ],
        children: [
          Wrap(
            spacing: Pd.s3,
            runSpacing: Pd.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                label: status.word.toLowerCase(),
                child: PdStamp(status, angleDegrees: 0),
              ),
              Text(
                'DAY $day',
                style: PdType.dataStrong.copyWith(
                  color: claim.isOpen ? Pd.signal : Pd.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: Pd.s5),
          ClaimLadder(claim: claim, today: _model.today),
          if (claim.isOpen) ...[
            ..._openClaimSections(claim, next),
          ] else ...[
            const SizedBox(height: Pd.s6),
            ClaimOutcome(claim: claim, days: day),
          ],
          const SizedBox(height: Pd.s8),
          ClaimActivityLog(events: claim.events),
        ],
      );
    },
  );

  List<Widget> _openClaimSections(Claim claim, String? next) {
    final step = _model.currentStep(claim);
    final message = _model.messageFor(claim);
    final portal = step.url;
    final phone = step.phone;
    final canAdvance = _model.canAdvance(claim);
    return [
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
      if (next != null) ...[
        const SizedBox(height: Pd.s4),
        if (canAdvance)
          PdButton.primary(
            key: const ValueKey('advance-claim'),
            label: 'Move to next step',
            onPressed: _model.busy ? null : () => _advance(next),
          )
        else
          Text(
            'If you’re still waiting on ${longDate(claim.nudgeOn)}, '
            'your next step is $next.',
            style: PdType.footnote.copyWith(color: Pd.textMuted),
          ),
      ],
      const SizedBox(height: Pd.s6),
      Builder(
        builder: (context) => ClaimDraftCard(
          heading: 'Write to ${stepTitle(claim.type, claim.step)}',
          message: message,
          onCopy: _model.busy
              ? null
              : () =>
                    _run(() => _model.copy(message), success: 'Message copied'),
          onShare: _model.busy ? null : () => _share(context, message),
          shareIcon: const Icon(CupertinoIcons.share, size: Pd.iconSm),
        ),
      ),
      const SizedBox(height: Pd.s2),
      PdButton.text(
        key: const ValueKey('claim-log-sent'),
        label: _model.hasLoggedSent(claim)
            ? 'Log another sent message'
            : 'I’ve sent it',
        onPressed: _model.busy
            ? null
            : () => _run(_model.logSent, success: 'Sent message logged'),
      ),
    ];
  }
}
