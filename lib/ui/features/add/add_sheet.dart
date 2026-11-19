import 'package:cupertino_ui/cupertino_ui.dart';

import '../../../domain/item_status.dart';
import '../../../domain/models/item.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/sheets.dart';

/// The three ways into the add flow from the Add sheet.
enum AddSheetAction { camera, upload, manual }

/// What the person chose on the Add sheet: a way in, plus the type of paper
/// they picked (Bill & warranty unless they changed it).
@immutable
class AddSheetChoice {
  const AddSheetChoice(this.action, this.kind);

  final AddSheetAction action;
  final ItemKind kind;
}

/// Opens "Scan or add": pick what you are adding, then take a photo, upload a
/// file or type it in. Returns null when the sheet is dismissed.
Future<AddSheetChoice?> showAddSheet(
  BuildContext context, {
  required int used,
  bool shared = false,
  bool onBasePlan = true,
  ItemKind initialKind = ItemKind.bill,
}) => showPdCustomSheet<AddSheetChoice>(
  context,
  semanticLabel: 'Scan or add',
  builder: (context) => AddSheet(
    used: used,
    shared: shared,
    onBasePlan: onBasePlan,
    initialKind: initialKind,
  ),
);

/// The Add sheet's content. Shown inside [showPdCustomSheet], which owns the
/// surface and grabber; the chosen action pops the sheet with an
/// [AddSheetChoice].
class AddSheet extends StatefulWidget {
  const AddSheet({
    required this.used,
    this.shared = false,
    this.onBasePlan = true,
    this.initialKind = ItemKind.bill,
    super.key,
  });

  /// Active items in the drawer, shown against [baseItemLimit].
  final int used;
  final bool shared;
  final bool onBasePlan;
  final ItemKind initialKind;

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  late var _kind = widget.initialKind;

  void _choose(AddSheetAction action) =>
      Navigator.pop(context, AddSheetChoice(action, _kind));

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('add-sheet'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: Pd.s4,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Pd.s2,
        children: [
          Text(
            widget.onBasePlan
                ? 'SCAN OR ADD · ${widget.used} OF $baseItemLimit ITEMS USED'
                : 'SCAN OR ADD',
            style: PdType.label.copyWith(color: Pd.textMuted),
          ),
          Semantics(
            header: true,
            child: Text('What are you adding?', style: PdType.title1),
          ),
          if (widget.shared)
            Text(
              'Continue on Paper Drawer web to save to your shared vault.',
              style: PdType.footnote.copyWith(color: Pd.textMuted),
            ),
        ],
      ),
      _KindGrid(
        selected: _kind,
        onSelect: (kind) => setState(() => _kind = kind),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s3,
        children: [
          PdButton.primary(
            key: const ValueKey('add-sheet-camera'),
            label: 'Take a photo',
            icon: const PdIcon(PdGlyph.scan, size: Pd.iconSm, color: Pd.onLime),
            expand: true,
            onPressed: () => _choose(AddSheetAction.camera),
          ),
          Row(
            spacing: Pd.s3,
            children: [
              Expanded(
                child: PdButton.secondary(
                  key: const ValueKey('add-sheet-upload'),
                  label: 'Upload a file',
                  expand: true,
                  onPressed: () => _choose(AddSheetAction.upload),
                ),
              ),
              Expanded(
                child: PdButton.secondary(
                  key: const ValueKey('add-sheet-manual'),
                  label: 'Type it in',
                  expand: true,
                  onPressed: () => _choose(AddSheetAction.manual),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Bill, policy, vehicle paper and agreement as a two-by-two grid of
/// toggles. Each row of two keeps its cards the same height as the text
/// reflows.
class _KindGrid extends StatelessWidget {
  const _KindGrid({required this.selected, required this.onSelect});

  final ItemKind selected;
  final ValueChanged<ItemKind> onSelect;

  @override
  Widget build(BuildContext context) {
    const kinds = ItemKind.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Pd.s3,
      children: [
        for (var row = 0; row < kinds.length; row += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Pd.s3,
              children: [
                for (final kind in kinds.skip(row).take(2))
                  Expanded(
                    child: _KindCard(
                      kind: kind,
                      selected: kind == selected,
                      onTap: () => onSelect(kind),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ItemKind kind;
  final bool selected;
  final VoidCallback onTap;

  /// Copy for each card: the paper's name and what it usually covers.
  (String, String) get _copy => switch (kind) {
    ItemKind.bill => (
      'Bill & warranty',
      'Electronics, appliances, online orders',
    ),
    ItemKind.policy => ('Insurance policy', 'Health, motor, gadget, home'),
    ItemKind.vehicle => ('Vehicle papers', 'PUC, insurance, servicing'),
    ItemKind.agreement => ('Agreement', 'Rent, AMC, subscriptions'),
  };

  @override
  Widget build(BuildContext context) {
    final (title, description) = _copy;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $description',
      excludeSemantics: true,
      child: CupertinoButton(
        key: ValueKey('add-kind-${kind.name}'),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        pressedOpacity: 0.7,
        focusColor: Pd.lime,
        minimumSize: const Size.square(Pd.tapMin),
        borderRadius: BorderRadius.circular(Pd.rSm),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : Pd.stampDuration,
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: Pd.s12 * 2 + Pd.s2),
          padding: EdgeInsets.all(selected ? Pd.s3 - 1 : Pd.s3),
          decoration: BoxDecoration(
            color: selected ? Pd.limeTint : Pd.surface1,
            borderRadius: BorderRadius.circular(Pd.rSm),
            border: Border.all(
              color: selected ? Pd.lime : Pd.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Pd.s1,
            children: [
              Text(
                selected ? '${kind.chip} · PICKED' : kind.chip,
                style: PdType.label.copyWith(
                  color: selected ? Pd.lime : Pd.textMuted,
                ),
              ),
              Text(title, style: PdType.optionTitle),
              Text(
                description,
                style: PdType.footnote.copyWith(color: Pd.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
