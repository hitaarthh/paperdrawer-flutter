import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/exporter.dart';
import '../../../data/services/today.dart';
import '../../../domain/models/item.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import 'attachment_viewer.dart';
import 'item_detail_sections.dart';
import 'item_detail_view_model.dart';

enum _ItemAction { archive, restore, delete }

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({required this.id, this.fromHome = false, super.key});

  final String id;
  final bool fromHome;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => ItemDetailViewModel(
      id,
      context.read<ItemRepository>(),
      context.read<ClaimRepository>(),
      context.read<Today>(),
      context.read<Exporter>(),
      context.read<DrawerActions>(),
    ),
    child: _ItemDetailView(fromHome: fromHome),
  );
}

class _ItemDetailView extends StatelessWidget {
  const _ItemDetailView({required this.fromHome});

  final bool fromHome;
  String get _backLabel => fromHome ? 'Home' : 'Vault';

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fromHome ? Routes.home : Routes.vault);
    }
  }

  Future<void> _perform(
    BuildContext context,
    ItemDetailViewModel model,
    Future<bool> operation, {
    String? success,
    bool pop = false,
  }) async {
    final saved = await operation;
    if (!context.mounted) return;
    if (saved) {
      if (success != null) showPdSnackbar(context, success, success: true);
      if (pop) _back(context);
    } else if (model.error case final error?) {
      showPdSnackbar(context, error);
    }
  }

  Future<void> _actions(
    BuildContext context,
    ItemDetailViewModel model,
    Item item,
  ) async {
    if (model.busy) return;
    final action = await showPdActions<_ItemAction>(
      context,
      title: item.name,
      actions: [
        if (item.isArchived)
          const PdAction(label: 'Restore to vault', value: _ItemAction.restore)
        else
          const PdAction(label: 'Move to archive', value: _ItemAction.archive),
        const PdAction(
          label: 'Delete item',
          value: _ItemAction.delete,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case _ItemAction.archive:
        await _perform(
          context,
          model,
          model.archive(true),
          success: 'Moved to archive',
          pop: true,
        );
      case _ItemAction.restore:
        await _perform(
          context,
          model,
          model.archive(false),
          success: 'Restored to vault',
        );
      case _ItemAction.delete:
        final confirmed = await showPdConfirm(
          context,
          title: 'Delete this item?',
          message: 'This permanently removes the item and its originals. Its claim history stays on Home.',
          confirmLabel: 'Delete item',
          destructive: true,
        );
        if (!context.mounted || !confirmed) return;
        await _perform(
          context,
          model,
          model.delete(),
          success: 'Item deleted',
          pop: true,
        );
      case null:
        break;
    }
  }

  Rect? _origin(BuildContext context) {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  Future<void> _openLedger(
    BuildContext context,
    ItemDetailViewModel model,
    Item item,
  ) async {
    final claim = model.claim ?? await model.openLedger(item);
    if (!context.mounted) return;
    if (claim != null) {
      context.push(Routes.claim(claim.id));
    } else if (model.error case final error?) {
      showPdSnackbar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ItemDetailViewModel>();
    final summary = model.summary;
    if (summary == null) {
      return PdPushedScaffold(
        backLabel: _backLabel,
        title: 'Item unavailable',
        onBack: () => _back(context),
        children: const [
          DashedTile(
            title: 'This item is gone',
            body: 'Go back to see the rest of your drawer.',
          ),
        ],
      );
    }
    final item = summary.item;
    final claim = model.claim;
    final original = item.attachments.firstOrNull;
    return PdPushedScaffold(
      backLabel: _backLabel,
      onBack: () => _back(context),
      kicker: itemDetailKicker(summary),
      title: item.name,
      actions: [
        PdButton.text(
          label: 'Edit',
          onPressed: model.busy
              ? null
              : () => context.push(Routes.edit(item.id)),
        ),
        PdNavIcon(
          key: const ValueKey('item-actions'),
          icon: const Icon(LucideIcons.ellipsis),
          semanticLabel: 'Item options',
          onTap: () => _actions(context, model, item),
        ),
      ],
      children: [
        ItemReturnTicket(summary),
        if (original != null) ...[
          Text('Original on file', style: PdType.title2),
          const SizedBox(height: Pd.s3),
          AttachmentViewer(
            key: ValueKey('attachment-${original.id}'),
            attachment: original,
            thumbnail: model.thumbnail,
            featured: true,
            onOpen: model.busy
                ? null
                : () => _perform(context, model, model.open(original)),
          ),
          Wrap(
            spacing: Pd.s2,
            runSpacing: Pd.s1,
            children: [
              PdButton.secondary(
                label: 'Open full size',
                onPressed: model.busy
                    ? null
                    : () => _perform(context, model, model.open(original)),
              ),
              Builder(
                builder: (anchor) => PdButton.secondary(
                  key: const ValueKey('item-share'),
                  label: 'Share originals',
                  onPressed: model.busy
                      ? null
                      : () => _perform(
                          context,
                          model,
                          model.shareOriginals(item, _origin(anchor)),
                        ),
                ),
              ),
            ],
          ),
          for (final attachment in item.attachments.skip(1))
            PdListRow(
              key: ValueKey('attachment-${attachment.id}'),
              title: attachment.name,
              chevron: true,
              onTap: model.busy
                  ? null
                  : () => _perform(context, model, model.open(attachment)),
            ),
          const SizedBox(height: Pd.s6),
        ],
        ItemCoverage(summary),
        ItemClaimKit(
          description: original == null
              ? 'Share your saved details and coverage dates.'
              : 'Share your saved details, coverage dates, and original documents.',
          actions: [
            if (claim != null || !item.isArchived)
              PdButton.primary(
                key: const ValueKey('item-claim'),
                label: claim == null ? 'Open a claim' : 'View claim ledger',
                expand: true,
                onPressed: model.busy
                    ? null
                    : () => _openLedger(context, model, item),
              )
            else
              PdButton.primary(
                key: const ValueKey('item-restore'),
                label: 'Restore to vault',
                onPressed: model.busy
                    ? null
                    : () => _perform(
                        context,
                        model,
                        model.archive(false),
                        success: 'Restored to vault',
                      ),
              ),
            Builder(
              builder: (anchor) => PdButton.secondary(
                key: const ValueKey('item-export-kit'),
                label: 'Share claim kit',
                expand: true,
                onPressed: model.busy
                    ? null
                    : () => _perform(
                        context,
                        model,
                        model.exportKit(item, _origin(anchor)),
                      ),
              ),
            ),
          ],
        ),
        if (model.itemClaims.isNotEmpty) ...[
          PdListGroup(
            header: 'Claims on this item',
            children: [
              for (final entry in model.itemClaims)
                PdListRow(
                  title: entry.title,
                  value: entry.isOpen ? 'Open' : 'Settled',
                  chevron: true,
                  onTap: () => context.push(Routes.claim(entry.id)),
                ),
            ],
          ),
          const SizedBox(height: Pd.s6),
        ] else if (!item.isArchived)
          const ItemClaimHistoryEmpty(),
        ItemRecord(itemRecord(summary)),
        if (item.draft.notes.isNotEmpty) ...[
          const SizedBox(height: Pd.s5),
          Text('Notes', style: PdType.title2),
          const SizedBox(height: Pd.s2),
          Text(item.draft.notes, style: PdType.body),
        ],
      ],
    );
  }
}
