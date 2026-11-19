import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/drawer_actions.dart';
import '../../../data/services/today.dart';
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

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({required this.id, this.fromHome = false, super.key});

  final String id;
  final bool fromHome;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => ItemDetailViewModel(
      id,
      context.read<ItemRepository>(),
      context.read<Today>(),
      context.read<DrawerActions>(),
    ),
    child: _ItemDetailView(fromHome: fromHome),
  );
}

class _ItemDetailView extends StatelessWidget {
  const _ItemDetailView({required this.fromHome});

  final bool fromHome;
  String get _backLabel => fromHome ? 'Home' : 'Drawer';

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

  Future<void> _delete(BuildContext context, ItemDetailViewModel model) async {
    final confirmed = await showPdConfirm(
      context,
      title: 'Delete this item?',
      message: 'This permanently removes the item and its originals from this iPhone.',
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
        backLabel: _backLabel,
        glassBack: true,
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
    final original = item.attachments.firstOrNull;
    final openOriginal = original == null || model.busy
        ? null
        : () => _perform(context, model, model.open(original));
    final remind = item.draft.remind && !item.isArchived;
    final settings = context.watch<SettingsRepository>();
    final reminderAt = item.draft.reminderAt;
    final reminder = switch ((remind, reminderAt)) {
      (false, _) => 'None',
      (true, final DateTime at) => DateFormat(
        'd MMM yyyy · h:mm a',
      ).format(at.toLocal()),
      (true, null) => 'Automatic',
    };
    return PdPushedScaffold(
      backLabel: _backLabel,
      glassBack: true,
      onBack: () => _back(context),
      title: item.name,
      titleStyle: PdType.trackerTitle,
      actions: [
        ItemDetailActions(
          onEdit: model.busy ? null : () => context.push(Routes.edit(item.id)),
          onDelete: model.busy ? null : () => _delete(context, model),
        ),
      ],
      bottom: original == null
          ? null
          : PdButton.primary(
              label: 'Open original',
              expand: true,
              onPressed: openOriginal,
            ),
      children: [
        ItemDeadlineTicket(summary),
        ItemOriginalPaper(
          summary,
          rows: itemRecord(summary),
          fileFormat: original == null
              ? null
              : (original.isPdf ? 'PDF' : 'IMAGE'),
          original: original == null
              ? null
              : AttachmentViewer(
                  key: ValueKey('attachment-${original.id}'),
                  attachment: original,
                  thumbnail: model.thumbnail,
                  featured: true,
                  onPaper: true,
                  onOpen: openOriginal,
                ),
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
        const SizedBox(height: Pd.s5),
        PdListGroup(
          children: [
            PdListRow(
              title: 'Reminder',
              value: remind && !settings.remindersOn
                  ? '$reminder · Paused'
                  : reminder,
            ),
          ],
        ),
        if (summary.windows.length > 1) ...[
          const SizedBox(height: Pd.s6),
          ItemCoverage(summary),
        ],
        if (item.draft.notes.isNotEmpty) ...[
          const SizedBox(height: Pd.s5),
          Text('Notes', style: PdType.title2),
          const SizedBox(height: Pd.s2),
          Text(item.draft.notes, style: PdType.body),
        ],
        const SizedBox(height: Pd.s5),
        PdListGroup(
          children: [
            if (original != null)
              Builder(
                builder: (anchor) => PdListRow(
                  key: const ValueKey('item-share'),
                  title: 'Share originals',
                  onTap: model.busy
                      ? null
                      : () => _perform(
                          context,
                          model,
                          model.shareOriginals(item, _origin(anchor)),
                        ),
                ),
              ),
            PdListRow(
              key: ValueKey(item.isArchived ? 'item-restore' : 'item-archive'),
              title: item.isArchived ? 'Restore to drawer' : 'Move to archive',
              onTap: model.busy
                  ? null
                  : () => _perform(
                      context,
                      model,
                      model.archive(!item.isArchived),
                      success: item.isArchived
                          ? 'Restored to drawer'
                          : 'Moved to archive',
                      pop: !item.isArchived,
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
