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
import '../../core/widgets/item_card.dart';
import '../../core/widgets/meter.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import 'attachment_viewer.dart';
import 'item_detail_view_model.dart';

enum _ItemAction { edit, archive, restore, delete }

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({required this.id, super.key});

  final String id;

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
    child: const _ItemDetailView(),
  );
}

class _ItemDetailView extends StatelessWidget {
  const _ItemDetailView();

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.vault);
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
        const PdAction(label: 'Edit details', value: _ItemAction.edit),
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
      case _ItemAction.edit:
        context.push(Routes.edit(item.id));
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
          message: 'This permanently removes the item and its originals. Its claim history stays in Claims.',
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

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ItemDetailViewModel>();
    final summary = model.summary;
    if (summary == null) {
      return PdPushedScaffold(
        backLabel: 'Vault',
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
    return PdPushedScaffold(
      backLabel: 'Vault',
      onBack: () => _back(context),
      actions: [
        if (item.attachments.isNotEmpty)
          Builder(
            builder: (anchor) => PdNavIcon(
              key: const ValueKey('item-share'),
              icon: const Icon(CupertinoIcons.share),
              semanticLabel: 'Share originals',
              onTap: () => _perform(
                context,
                model,
                model.shareOriginals(item, _origin(anchor)),
              ),
            ),
          ),
        PdNavIcon(
          key: const ValueKey('item-actions'),
          icon: const Icon(LucideIcons.ellipsis),
          semanticLabel: 'Item options',
          onTap: () => _actions(context, model, item),
        ),
      ],
      children: [
        if (item.isArchived)
          Padding(
            padding: const EdgeInsets.only(bottom: Pd.s3),
            child: Text(
              'ARCHIVED',
              style: PdType.label.copyWith(color: Pd.textMuted),
            ),
          ),
        ItemCard(summary: summary),
        for (final window in summary.windows)
          Padding(
            padding: const EdgeInsets.only(top: Pd.s6),
            child: PdMeter(window: window, today: summary.today),
          ),
        if (item.attachments.isNotEmpty) ...[
          const SizedBox(height: Pd.s6),
          Text(
            'ORIGINAL DOCUMENTS',
            style: PdType.label.copyWith(color: Pd.textMuted),
          ),
          const SizedBox(height: Pd.s3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: Pd.s3,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final attachment in item.attachments)
                  AttachmentViewer(
                    key: ValueKey('attachment-${attachment.id}'),
                    attachment: attachment,
                    thumbnail: model.thumbnail,
                    onOpen: model.busy
                        ? null
                        : () =>
                              _perform(context, model, model.open(attachment)),
                  ),
              ],
            ),
          ),
        ],
        if (item.draft.notes.isNotEmpty) ...[
          const SizedBox(height: Pd.s6),
          Text('NOTES', style: PdType.label.copyWith(color: Pd.textMuted)),
          const SizedBox(height: Pd.s2),
          Text(item.draft.notes, style: PdType.body),
        ],
        const SizedBox(height: Pd.s8),
        if (claim != null || !item.isArchived)
          PdButton.primary(
            key: const ValueKey('item-claim'),
            label: claim == null ? 'Start a claim' : 'View claim',
            onPressed: model.busy
                ? null
                : () {
                    if (claim != null) {
                      context.go(Routes.claim(claim.id));
                    } else {
                      context.push(Routes.startClaim(item.id));
                    }
                  },
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
        const SizedBox(height: Pd.s2),
        Builder(
          builder: (anchor) => PdButton.secondary(
            key: const ValueKey('item-export-kit'),
            label: 'Export claim kit',
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
    );
  }
}
