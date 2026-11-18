import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../domain/formats.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/shared_vault.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/meter.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/snackbar.dart';
import 'shared_session.dart';

class SharedVaultScreen extends StatelessWidget {
  const SharedVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    final inbox = session.vault;
    final today = session.today.value;
    final claims = <String>{
      for (final claim in inbox?.claims ?? const <SharedClaim>[])
        if (claim.settled == null && claim.itemId != null) claim.itemId!,
    };
    final cards = [
      for (final entry in inbox?.items ?? const <SharedItem>[])
        ItemSummary.of(
          entry.item,
          today,
          hasOpenClaim: claims.contains(entry.item.id),
        ),
    ]..sort((a, b) => a.sortRank.compareTo(b.sortRank));
    return PdLargeTitleScaffold(
      title: 'Vault',
      heroTag: 'shared-vault',
      trailing: _Refresh(session),
      slivers: [
        if (session.failed) _inset(_LoadFailure(session)),
        if (inbox == null && session.loading) _inset(const _Loading()),
        if (inbox != null && cards.isEmpty)
          _inset(
            DashedTile(
              title: 'Your drawer is empty',
              body: 'Add a bill on PaperDrawer web. It will appear here when you refresh.',
              action: PdButton.primary(
                label: 'Open PaperDrawer web',
                onPressed: () => _open(context, session, '/vault'),
              ),
            ),
          )
        else if (cards.isNotEmpty) ...[
          _inset(
            PdButton.text(
              label: 'Manage vault on web',
              onPressed: () => _open(context, session, '/vault'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
            sliver: SliverList.builder(
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final summary = cards[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: Pd.s3),
                  child: ItemCard(
                    key: ValueKey('shared-item-${summary.item.id}'),
                    summary: summary,
                    onTap: () => context.push('/vault/item/${summary.item.id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class SharedClaimsScreen extends StatelessWidget {
  const SharedClaimsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    final claims = session.vault?.claims;
    return PdLargeTitleScaffold(
      title: 'Claims',
      heroTag: 'shared-claims',
      trailing: _Refresh(session),
      slivers: [
        if (session.failed) _inset(_LoadFailure(session)),
        if (claims == null && session.loading) _inset(const _Loading()),
        if (claims != null && claims.isEmpty)
          _inset(
            DashedTile(
              title: 'No claims yet',
              body: 'Claims you start on the web will appear here.',
              action: PdButton.primary(
                label: 'Open claims on web',
                onPressed: () => _open(context, session, '/claims'),
              ),
            ),
          ),
        if (claims != null && claims.isNotEmpty)
          _inset(
            PdListGroup(
              children: [
                for (final claim in claims)
                  PdListRow(
                    key: ValueKey('shared-claim-${claim.id}'),
                    title: claim.title,
                    value: claim.statusLabel,
                    chevron: true,
                    onTap: () => context.push('/claims/${claim.id}'),
                  ),
              ],
            ),
          ),
      ],
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
    final draft = item.item.draft;
    final summary = ItemSummary.of(
      item.item,
      session.today.value,
      hasOpenClaim: session.vault!.claims.any(
        (claim) => claim.itemId == id && claim.settled == null,
      ),
    );
    return PdPushedScaffold(
      backLabel: 'Vault',
      onBack: () => context.canPop() ? context.pop() : context.go('/vault'),
      children: [
        ItemCard(summary: summary),
        for (final window in summary.windows)
          Padding(
            padding: const EdgeInsets.only(top: Pd.s4),
            child: PdMeter(window: window, today: summary.today),
          ),
        if (item.details.isNotEmpty) ...[
          const SizedBox(height: Pd.s5),
          _Details(item.details),
        ],
        if (draft.notes.isNotEmpty) ...[
          const SizedBox(height: Pd.s5),
          Text(draft.notes, style: PdType.body),
        ],
        _Originals(item.originals, session),
        const SizedBox(height: Pd.s5),
        PdButton.secondary(
          label: 'Open on web',
          onPressed: () => _open(context, session, item.webPath),
        ),
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

class SharedSettingsScreen extends StatefulWidget {
  const SharedSettingsScreen({super.key});

  @override
  State<SharedSettingsScreen> createState() => _SharedSettingsScreenState();
}

class _SharedSettingsScreenState extends State<SharedSettingsScreen> {
  bool _busy = false;

  Future<void> _signOut(SharedSession session) async {
    setState(() => _busy = true);
    try {
      await session.account.signOut();
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(
        context,
        'Couldn’t sign out. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SharedSession>();
    return PdLargeTitleScaffold(
      title: 'Settings',
      heroTag: 'shared-settings',
      slivers: [
        _inset(
          PdListGroup(
            header: 'Account',
            children: [
              PdListRow(title: 'Email', value: session.email),
              PdListRow(
                title: 'Manage account on web',
                chevron: true,
                onTap: () => _open(context, session, '/settings'),
              ),
              PdListRow(
                key: const ValueKey('account-sign-out'),
                title: 'Sign out',
                onTap: _busy ? null : () => _signOut(session),
              ),
            ],
          ),
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

class _Refresh extends StatelessWidget {
  const _Refresh(this.session);
  final SharedSession session;

  @override
  Widget build(BuildContext context) => PdNavIcon(
    icon: const Icon(LucideIcons.refreshCw),
    semanticLabel: 'Refresh from PaperDrawer web',
    onTap: session.refresh,
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure(this.session);
  final SharedSession session;

  @override
  Widget build(BuildContext context) => DashedTile(
    title: 'Couldn’t refresh PaperDrawer',
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

Widget _inset(Widget child) => SliverPadding(
  padding: const EdgeInsets.fromLTRB(Pd.margin, Pd.s3, Pd.margin, Pd.s4),
  sliver: SliverToBoxAdapter(child: child),
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
    showPdSnackbar(context, 'Couldn’t open PaperDrawer web.');
  }
}
