import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/services/today.dart';
import '../../../domain/item_status.dart';
import '../../../domain/models/item.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/snackbar.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String? _restoring;

  Future<void> _restore(Item item) async {
    if (_restoring != null) return;
    final repository = context.read<ItemRepository>();
    setState(() => _restoring = item.id);
    try {
      await repository.setArchived(item.id, false);
      if (!mounted) return;
      showPdSnackbar(context, 'Restored to drawer', success: true);
    } on LimitReachedException catch (error) {
      if (!mounted) return;
      showPdSnackbar(context, error.message);
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(context, 'This item couldn’t be restored. Try again.');
    } finally {
      if (mounted) setState(() => _restoring = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ItemRepository>().archived
      ..sort((a, b) => b.archivedAt!.compareTo(a.archivedAt!));
    final today = context.watch<Today>().value;
    return PdPushedScaffold(
      backLabel: 'Settings',
      glassBack: true,
      title: 'Archive',
      onBack: () =>
          context.canPop() ? context.pop() : context.go(Routes.settings),
      children: [
        if (items.isEmpty)
          const DashedTile(
            title: 'Nothing in the archive',
            body: 'Archive an item to free up room in your drawer. You can restore it here.',
          )
        else ...[
          Text(
            'Archived items and their originals stay on this device.',
            style: PdType.callout.copyWith(color: Pd.textMuted),
          ),
          const SizedBox(height: Pd.s4),
          for (final item in items) ...[
            ItemCard(
              key: ValueKey('archived-item-${item.id}'),
              summary: ItemSummary.of(item, today),
              onTap: () => context.push(Routes.item(item.id)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: PdButton.text(
                key: ValueKey('restore-item-${item.id}'),
                label: 'Restore to drawer',
                busy: _restoring == item.id,
                onPressed: _restoring == null ? () => _restore(item) : null,
              ),
            ),
            const SizedBox(height: Pd.s4),
          ],
        ],
      ],
    );
  }
}
