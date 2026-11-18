import 'dart:typed_data';

import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/shared_vault.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/brand_bar.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/paper.dart';
import '../../core/widgets/snackbar.dart';
import '../add/shared_add_flow.dart';
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
      trailing: vault == null
          ? null
          : PdBrandAction(
              key: const ValueKey('shared-claims-scan'),
              label: 'Scan or add',
              icon: LucideIcons.scanLine,
              onPressed: () => showSharedAdd(context, session, vault),
            ),
      empty: (filter) => filter == ClaimsFilter.settled
          ? const DashedTile(
              title: 'No settled claims yet',
              body: 'Settled claims will appear here.',
            )
          : DashedTile(
              title: filter == ClaimsFilter.open
                  ? 'No open claims'
                  : 'No claims yet',
              body: 'Claims you start on the web will appear here.',
              action: PdButton.primary(
                label: 'Open claims on web',
                onPressed: () => _open(context, session, '/claims'),
              ),
            ),
    );
  }
}

class SharedItemScreen extends StatelessWidget {
  const SharedItemScreen(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    final item = session.vault?.items
        .where((entry) => entry.item.id == id)
        .firstOrNull;
    if (item == null) {
      return _missing(context, session, 'Vault', '/vault');
    }
    final linkedClaims = session.vault!.claims
        .where((claim) => claim.itemId == id)
        .toList();
    final activeClaim = linkedClaims
        .where((claim) => claim.settled == null)
        .firstOrNull;
    final summary = ItemSummary.of(
      item.item,
      session.today.value,
      hasOpenClaim: activeClaim != null,
    );
    final category = item.details
        .where((detail) => detail.$1 == 'Category')
        .firstOrNull
        ?.$2;
    return PdPushedScaffold(
      backLabel: 'Vault',
      onBack: () => context.canPop() ? context.pop() : context.go('/vault'),
      kicker: itemDetailKicker(summary, category: category),
      title: item.item.name,
      actions: [
        PdButton.text(
          label: 'Edit on web',
          onPressed: () => _open(context, session, item.editPath),
        ),
      ],
      children: [
        ItemReturnTicket(summary),
        if (item.originals.isNotEmpty) ...[
          Text('Original on file', style: PdType.title2),
          const SizedBox(height: Pd.s3),
          _SharedItemOriginal(file: item.originals.first, session: session),
          _Originals(item.originals.skip(1).toList(), session),
          const SizedBox(height: Pd.s6),
        ],
        ItemCoverage(summary),
        ItemClaimKit(
          description:
              'Open Paper Drawer web to manage this record and its claim kit.',
          actions: [
            if (activeClaim == null)
              PdButton.primary(
                label: 'Start a claim on web',
                onPressed: () => _open(context, session, item.startClaimPath),
              )
            else
              PdButton.primary(
                label: 'View claim',
                onPressed: () => context.push('/claims/${activeClaim.id}'),
              ),
            PdButton.secondary(
              label: 'Open on web',
              onPressed: () => _open(context, session, item.webPath),
            ),
          ],
        ),
        if (linkedClaims.isNotEmpty) ...[
          PdListGroup(
            header: 'Claims',
            children: [
              for (final claim in linkedClaims)
                PdListRow(
                  title: claim.title,
                  value: claim.statusLabel,
                  chevron: true,
                  onTap: () => context.push('/claims/${claim.id}'),
                ),
            ],
          ),
          const SizedBox(height: Pd.s6),
        ],
        ItemRecord([
          ...itemRecord(summary),
          for (final detail in item.details)
            if (!const {
              'Invoice number',
              'Serial number',
              'Document number',
            }.contains(detail.$1))
              detail,
        ]),
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
    return PdPushedScaffold(
      backLabel: 'Claims',
      onBack: () => context.canPop() ? context.pop() : context.go('/claims'),
      title: claim.title,
      kicker: claim.statusLabel.toUpperCase(),
      children: [
        if (claim.itemLabel.isNotEmpty)
          Text(claim.itemLabel, style: PdType.bodyStrong),
        const SizedBox(height: Pd.s2),
        Text(claim.problem, style: PdType.body),
        const SizedBox(height: Pd.s5),
        _Details([
          ('Opened', longDate(claim.opened)),
          if (claim.settled case final settled?) ('Settled', longDate(settled)),
          ...claim.facts,
        ]),
        _Originals(claim.originals, session),
        if (claim.events.isNotEmpty) ...[
          const SizedBox(height: Pd.s5),
          PdListGroup(
            header: 'Activity',
            children: [
              for (final event in claim.events)
                Padding(
                  padding: const EdgeInsets.all(Pd.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: Pd.s1,
                    children: [
                      Text(monoDate(event.date), style: PdType.label),
                      Text(event.title, style: PdType.bodyStrong),
                      if (event.note.isNotEmpty)
                        Text(event.note, style: PdType.callout),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: Pd.s5),
        PdButton.secondary(
          label: 'Manage claim on web',
          onPressed: () => _open(context, session, claim.webPath),
        ),
      ],
    );
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
      if (mounted)
        showPdSnackbar(context, 'Couldn’t load this original. Try again.');
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
    return DocumentPaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s2,
        children: [
          SizedBox(
            height: file.mime.startsWith('image/') ? 175 : 70,
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
          const DashedRule(),
          Wrap(
            spacing: Pd.s2,
            runSpacing: Pd.s2,
            children: [
              PdButton.onPaper(
                label: 'Open full size',
                onPressed: _busy
                    ? null
                    : () => _handle(() => widget.session.openOriginal(file)),
              ),
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
                            () => widget.session.shareOriginal(
                              file,
                              origin: origin,
                            ),
                          );
                        },
                ),
              ),
            ],
          ),
        ],
      ),
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
