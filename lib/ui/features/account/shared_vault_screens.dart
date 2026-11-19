import 'dart:typed_data';

import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/services/drawer_actions.dart';
import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/shared_vault.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../../core/widgets/vault_ticket.dart';
import '../claims/claim_detail_sections.dart';
import '../claims/claims_list_data.dart';
import '../claims/claims_overview.dart';
import '../item/item_detail_sections.dart';
import 'shared_session.dart';

class SharedClaimsScreen extends StatelessWidget {
  const SharedClaimsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    final vault = session.vault;
    return ClaimsOverview(
      data: vault == null
          ? null
          : ClaimsListData(
              vault.claims.map(
                (claim) => ClaimListEntry.shared(claim, session.today.value),
              ),
            ),
      onRefresh: session.refresh,
      onOpen: (id) => context.push('/claims/$id'),
      onVault: () => context.go('/vault'),
      rowKeyPrefix: 'shared-claim',
      notice: session.failed
          ? _LoadFailure(session)
          : vault == null && session.loading
          ? const _Loading()
          : null,
      empty: (filter) => filter == ClaimsFilter.settled
          ? const DashedTile(
              title: 'No settled claims yet',
              body: 'Settled claims will appear here.',
            )
          : DashedTile(
              title: filter == ClaimsFilter.open
                  ? 'No open claims'
                  : 'No claims yet',
              body: 'Open a claim from an item in your vault.',
              action: PdButton.primary(
                label: 'Open vault',
                onPressed: () => context.go('/vault'),
              ),
            ),
    );
  }
}

class SharedItemScreen extends StatelessWidget {
  const SharedItemScreen(this.id, {this.fromHome = false, super.key});
  final String id;
  final bool fromHome;

  String get _backLabel => fromHome ? 'Home' : 'Drawer';
  String get _backRoute => fromHome ? '/home' : '/vault';

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(_backRoute);

  Future<void> _delete(
    BuildContext context,
    SharedSession session,
    SharedItem item,
  ) async {
    final confirmed = await showPdConfirm(
      context,
      title: 'Delete this item?',
      message: 'This permanently removes the item and its originals from your account.',
      confirmLabel: 'Delete item',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await session.deleteItem(item);
      if (context.mounted) _back(context);
    } catch (_) {
      if (context.mounted) {
        showPdSnackbar(context, 'Couldn’t delete this item. Try again.');
      }
    }
  }

  Future<void> _openOriginal(
    BuildContext context,
    SharedSession session,
    SharedOriginal file,
  ) async {
    try {
      await session.openOriginal(file);
    } catch (_) {
      if (context.mounted) {
        showPdSnackbar(context, 'Couldn’t open this original. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    final item = session.vault?.items
        .where((entry) => entry.item.id == id)
        .firstOrNull;
    if (item == null) {
      return _missing(context, session, _backLabel, _backRoute);
    }
    final summary = ItemSummary.of(item.item, session.today.value);
    final original = item.originals.firstOrNull;
    final leadDays = item.reminderLeadDays ?? session.vault?.profile?.leadDays;
    return PdPushedScaffold(
      backLabel: _backLabel,
      glassBack: true,
      onBack: () => _back(context),
      title: item.item.name,
      titleStyle: PdType.trackerTitle,
      actions: [
        ItemDetailActions(
          onEdit: session.claimBusy
              ? null
              : () => _open(context, session, item.editPath),
          onDelete: session.claimBusy
              ? null
              : () => _delete(context, session, item),
        ),
      ],
      bottom: original == null
          ? null
          : PdButton.primary(
              label: 'Open original',
              expand: true,
              onPressed: () => _openOriginal(context, session, original),
            ),
      children: [
        ItemDeadlineTicket(summary),
        ItemOriginalPaper(
          summary,
          fileFormat: original == null
              ? null
              : (original.mime == 'application/pdf' ? 'PDF' : 'IMAGE'),
          original: original == null
              ? null
              : _SharedItemOriginal(file: original, session: session),
          rows: [
            ...itemRecord(summary),
            for (final detail in item.details)
              if (!const {
                'Invoice number',
                'Serial number',
                'Document number',
              }.contains(detail.$1))
                detail,
          ],
        ),
        if (item.originals.length > 1)
          _Originals(item.originals.skip(1).toList(), session),
        if (summary.windows.isNotEmpty) ...[
          const SizedBox(height: Pd.s5),
          PdListGroup(
            children: [
              PdListRow(
                title: 'In-app reminders',
                value: leadDays == null ? null : '$leadDays days before',
              ),
            ],
          ),
        ],
        if (summary.windows.length > 1) ...[
          const SizedBox(height: Pd.s6),
          ItemCoverage(summary),
        ],
        if (summary.d.notes.isNotEmpty) ...[
          const SizedBox(height: Pd.s5),
          Text('Notes', style: PdType.title2),
          const SizedBox(height: Pd.s2),
          Text(summary.d.notes, style: PdType.body),
        ],
      ],
    );
  }
}

class SharedClaimScreen extends StatelessWidget {
  const SharedClaimScreen(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    final claim = session.vault?.claims
        .where((entry) => entry.id == id)
        .firstOrNull;
    if (claim == null) {
      return _missing(context, session, 'Claims', '/claims');
    }
    final today = session.today.value;
    final entry = ClaimListEntry.shared(claim, today);
    final open = entry.status.isOpen;
    final next = claim.nextStep;
    final step = claim.step.clamp(0, claim.ladderTitles.length - 1);
    final mail = claim.draft;
    const actions = DrawerActions();
    return PdPushedScaffold(
      backLabel: 'CLAIMS',
      backStyle: PdType.monoButton,
      onBack: () => context.canPop() ? context.pop() : context.go('/claims'),
      title: claim.title,
      titleStyle: PdType.trackerTitle,
      kicker: [
        entry.metadata.toUpperCase(),
        'OPENED ${longDate(claim.opened).toUpperCase()}',
        if (!open) entry.status.label,
      ].join(' · '),
      actions: [
        if (open)
          PdButton.text(
            key: const ValueKey('shared-mark-claim-settled'),
            label: 'Mark settled',
            monospaced: true,
            onPressed:
                session.loading ||
                    session.settlingClaim ||
                    session.savingReminders
                ? null
                : () => _markSettled(context, session, claim.id),
          ),
      ],
      children: [
        if (open) ...[
          VaultTicket(
            number: entry.waitDays.toString().padLeft(2, '0'),
            unit: entry.waitDays == 1 ? 'DAY' : 'DAYS',
            kicker:
                'STEP ${step + 1} OF ${claim.ladderTitles.length} · ${entry.status.label}',
            title: next?.$1 ?? claim.ladderTitles[step],
            body: next?.$2 ?? entry.next,
            tone: entry.status.needsAction
                ? VaultTicketTone.lime
                : VaultTicketTone.paper,
            semanticLabel:
                '${entry.waitDays} days since the last reply or the opening date. ${next?.$1 ?? entry.next}',
          ),
          const SizedBox(height: Pd.s5),
        ],
        if (open && mail != null) ...[
          Text('Your next message', style: PdType.title2),
          const SizedBox(height: Pd.s3),
          ClaimDraftCard(message: mail),
          const SizedBox(height: Pd.s2),
          Wrap(
            spacing: Pd.s2,
            runSpacing: Pd.s2,
            children: [
              PdButton.secondary(
                label: 'Copy message',
                icon: const Icon(LucideIcons.copy),
                onPressed: () => _draftAction(
                  context,
                  () => actions.copyText(mail.full),
                  failure: 'Couldn’t copy this message.',
                  success: 'Message copied',
                ),
              ),
              PdButton.secondary(
                label: 'Open mail',
                icon: const Icon(LucideIcons.mail),
                onPressed: () => _draftAction(
                  context,
                  () => actions.openLink(mail.mailto),
                  failure:
                      'Your mail app couldn’t open. You can copy the message.',
                ),
              ),
              Builder(
                builder: (anchor) => PdButton.secondary(
                  label: 'Share',
                  icon: const Icon(LucideIcons.share2),
                  onPressed: () => _draftAction(
                    context,
                    () => actions.shareText(
                      mail.full,
                      origin: _shareOrigin(anchor),
                    ),
                    failure: 'Couldn’t share this message.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Pd.s5),
        ],
        Text('Claim steps', style: PdType.title2),
        const SizedBox(height: Pd.s3),
        PdListGroup(
          children: [
            for (final (index, title) in claim.ladderTitles.indexed)
              PdListRow(
                title: '${index + 1}. $title',
                value: index == step && open ? 'You are here' : null,
                actionIcon: index < step || index == step && !open
                    ? LucideIcons.check
                    : null,
              ),
          ],
        ),
        const SizedBox(height: Pd.s6),
        Row(
          children: [
            Expanded(child: Text('Claim log', style: PdType.title2)),
            Flexible(
              child: PdButton.text(
                label: 'Log an update on web',
                onPressed: () => _open(context, session, claim.webPath),
              ),
            ),
          ],
        ),
        if (claim.events.isEmpty)
          Text('Updates will appear here.', style: PdType.callout)
        else
          PdListGroup(
            children: [
              for (final event in claim.events)
                Padding(
                  padding: const EdgeInsets.all(Pd.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Pd.s1,
                    children: [
                      Text(
                        monoDate(event.date),
                        style: PdType.label.copyWith(color: Pd.textMuted),
                      ),
                      Text(event.title, style: PdType.bodyStrong),
                      if (event.note.isNotEmpty)
                        Text(event.note, style: PdType.callout),
                    ],
                  ),
                ),
            ],
          ),
        _Originals(claim.originals, session),
        const SizedBox(height: Pd.s5),
        if (claim.problem.isNotEmpty) ...[
          Text('What happened', style: PdType.title2),
          const SizedBox(height: Pd.s2),
          Text(claim.problem, style: PdType.body),
          const SizedBox(height: Pd.s3),
        ],
        _Details([
          ('Opened', longDate(claim.opened)),
          if (claim.settled case final settled?) ('Settled', longDate(settled)),
          ...claim.facts,
        ]),
      ],
    );
  }
}

Future<void> _markSettled(
  BuildContext context,
  SharedSession session,
  String claimId,
) async {
  final outcome = await showPdSheet<String>(
    context,
    title: 'Mark settled',
    body: const ClaimNoteForm(
      fieldLabel: 'HOW WAS IT RESOLVED?',
      saveLabel: 'Mark settled',
      requiredNote: false,
    ),
  );
  if (!context.mounted || outcome == null) return;
  try {
    final saved = await session.settleClaim(claimId, outcome);
    if (context.mounted && saved) {
      showPdSnackbar(context, 'Claim settled', success: true);
    }
  } catch (error) {
    if (context.mounted) {
      showPdSnackbar(
        context,
        error is FormatException
            ? error.message
            : 'Couldn’t settle this claim. Try again.',
      );
    }
  }
}

Rect? _shareOrigin(BuildContext anchor) {
  final box = anchor.findRenderObject();
  return box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
}

Future<void> _draftAction(
  BuildContext context,
  Future<void> Function() action, {
  required String failure,
  String? success,
}) async {
  try {
    await action();
    if (context.mounted && success != null) {
      showPdSnackbar(context, success, success: true);
    }
  } catch (_) {
    if (context.mounted) showPdSnackbar(context, failure);
  }
}

class _Details extends StatelessWidget {
  const _Details(this.details);
  final List<(String, String)> details;

  @override
  Widget build(BuildContext context) => PdListGroup(
    header: 'Details',
    children: [
      for (final (label, value) in details)
        PdListRow(title: label, value: value),
    ],
  );
}

class _SharedItemOriginal extends StatefulWidget {
  const _SharedItemOriginal({required this.file, required this.session});

  final SharedOriginal file;
  final SharedSession session;

  @override
  State<_SharedItemOriginal> createState() => _SharedItemOriginalState();
}

class _SharedItemOriginalState extends State<_SharedItemOriginal> {
  late Future<Uint8List?> _preview = widget.session.previewOriginal(
    widget.file,
  );
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _SharedItemOriginal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.session != widget.session) {
      _preview = widget.session.previewOriginal(widget.file);
    }
  }

  Future<void> _handle(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        showPdSnackbar(context, 'Couldn’t load this original. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;
    const placeholder = Center(
      child: Icon(LucideIcons.fileText, color: Pd.inkMuted, size: 46),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Pd.s2,
      children: [
        SizedBox(
          height: file.mime.startsWith('image/') ? 160 : Pd.s12,
          child: FutureBuilder(
            future: _preview,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              return bytes == null
                  ? placeholder
                  : Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      cacheWidth: 1000,
                      errorBuilder: (_, _, _) => placeholder,
                    );
            },
          ),
        ),
        Text(file.name, style: PdType.callout.copyWith(color: Pd.ink2)),
        Builder(
          builder: (anchor) => PdButton.onPaper(
            label: 'Share file',
            onPressed: _busy
                ? null
                : () {
                    final box = anchor.findRenderObject();
                    final origin = box is RenderBox && box.hasSize
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null;
                    _handle(
                      () => widget.session.shareOriginal(file, origin: origin),
                    );
                  },
          ),
        ),
      ],
    );
  }
}

class _Originals extends StatefulWidget {
  const _Originals(this.files, this.session);
  final List<SharedOriginal> files;
  final SharedSession session;

  @override
  State<_Originals> createState() => _OriginalsState();
}

class _OriginalsState extends State<_Originals> {
  String? _opening;

  Future<void> _openOriginal(SharedOriginal file) async {
    setState(() => _opening = file.path);
    try {
      await widget.session.openOriginal(file);
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(context, 'Couldn’t open this original. Try again.');
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Pd.s5),
      child: PdListGroup(
        header: 'Originals',
        children: [
          for (final file in widget.files)
            PdListRow(
              title: file.name,
              value: _opening == file.path ? 'Opening…' : null,
              chevron: true,
              onTap: _opening != null ? null : () => _openOriginal(file),
            ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure(this.session);
  final SharedSession session;

  @override
  Widget build(BuildContext context) => DashedTile(
    title: 'Couldn’t refresh Paper Drawer',
    body: 'Check your connection and try again.',
    action: PdButton.text(label: 'Try again', onPressed: session.refresh),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      'Loading your drawer…',
      style: PdType.callout.copyWith(color: Pd.textMuted),
    ),
  );
}

Widget _missing(
  BuildContext context,
  SharedSession session,
  String back,
  String route,
) => PdPushedScaffold(
  backLabel: back,
  onBack: () => context.canPop() ? context.pop() : context.go(route),
  children: [
    if (session.loading)
      const _Loading()
    else if (session.failed)
      _LoadFailure(session)
    else
      const DashedTile(
        title: 'Record unavailable',
        body: 'Go back to see what’s in your drawer.',
      ),
  ],
);

Future<void> _open(
  BuildContext context,
  SharedSession session,
  String path,
) async {
  try {
    await session.openWeb(path);
  } catch (_) {
    if (!context.mounted) return;
    showPdSnackbar(context, 'Couldn’t open Paper Drawer web.');
  }
}
