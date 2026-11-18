import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/bill_reader.dart';
import '../../../domain/formats.dart';
import '../../../domain/models/item.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/sheets.dart';
import 'add_flow.dart';
import 'item_form_view_model.dart';

enum _WindowAction { exact, clear }

class FormCoverSection extends StatefulWidget {
  const FormCoverSection({required this.form, super.key});

  final ItemFormViewModel form;

  @override
  State<FormCoverSection> createState() => _FormCoverSectionState();
}

class _FormCoverSectionState extends State<FormCoverSection> {
  bool _editedCover = false;
  ItemFormViewModel get _form => widget.form;

  Future<void> _chooseSubtype() async {
    final selected = await showPdActions<String>(
      context,
      title: 'Document type',
      actions: [
        for (final subtype in _form.kind.subtypes)
          PdAction(label: subtype, value: subtype),
        const PdAction(label: 'Clear type', value: ''),
      ],
    );
    if (!mounted || selected == null) return;
    _form.setSubtype(selected);
  }

  Future<void> _chooseWindow({required bool returns}) async {
    final initial = returns ? _form.returnUntil : _form.coverUntil;
    final title = returns ? 'Return window' : _form.coverLabel;
    final options = returns ? const [7, 14, 30] : const [6, 12, 24, 36];
    final offerDurations =
        _form.kind == ItemKind.bill && _form.startsOn != null;
    final chosen = await showPdActions<Object>(
      context,
      title: title,
      actions: [
        if (offerDurations)
          for (final n in options)
            PdAction(label: returns ? daysWord(n) : monthsLabel(n), value: n),
        const PdAction(label: 'Choose a date', value: _WindowAction.exact),
        if (initial != null || (!returns && _form.warrantyMonths != null))
          const PdAction(label: 'Clear', value: _WindowAction.clear),
      ],
    );
    if (!mounted || chosen == null) return;
    if (chosen is int) {
      if (returns) {
        _form.setReturnDays(chosen);
      } else {
        setState(() => _editedCover = true);
        _form.setWarrantyMonths(chosen);
      }
      return;
    }
    DateTime? date;
    if (chosen == _WindowAction.exact) {
      date = await showPdDatePicker(
        context,
        title: title,
        initial: initial ?? _form.startsOn,
        min: _form.startsOn,
      );
      if (!mounted || date == null) return;
    }
    if (returns) {
      _form.setReturnUntil(date);
    } else {
      setState(() => _editedCover = true);
      _form.setCoverUntil(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBill = _form.kind == ItemKind.bill;
    final date = _form.coverUntil;
    final months = _form.warrantyMonths;
    final returnUntil = _form.returnUntil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ITEM TYPE', style: PdType.label.copyWith(color: Pd.textMuted)),
        const SizedBox(height: Pd.s2),
        Wrap(
          spacing: Pd.s2,
          children: [
            for (final kind in ItemKind.values)
              PdChoiceChip(
                key: ValueKey('item-kind-${kind.name}'),
                label: kind.chip,
                selected: _form.kind == kind,
                onPaper: false,
                onTap: () {
                  if (!_form.busy) {
                    setState(() => _editedCover = true);
                    _form.setKind(kind);
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: Pd.s3),
        PdListGroup(
          children: [
            if (!isBill)
              PdListRow(
                title: 'Document type',
                value: _form.subtype.isEmpty ? 'Optional' : _form.subtype,
                chevron: true,
                onTap: _form.busy ? null : _chooseSubtype,
              ),
            PdListRow(
              key: const ValueKey('item-cover-date'),
              title: _form.coverLabel,
              value: date != null
                  ? longDate(date)
                  : (months == null ? 'Optional' : monthsLabel(months)),
              tag:
                  !_editedCover &&
                      (_form.readFields.contains(ReadField.coverUntil) ||
                          _form.readFields.contains(ReadField.warranty))
                  ? 'Read from bill'
                  : null,
              chevron: true,
              onTap: _form.busy ? null : () => _chooseWindow(returns: false),
            ),
            if (isBill)
              PdListRow(
                key: const ValueKey('item-return-date'),
                title: 'Return window',
                value: returnUntil == null ? 'Optional' : longDate(returnUntil),
                chevron: true,
                onTap: _form.busy ? null : () => _chooseWindow(returns: true),
              ),
            PdListRow(
              title: 'Reminder',
              trailing: Semantics(
                label: 'Reminder for this item',
                child: PdSwitch(
                  key: const ValueKey('item-reminder'),
                  value: _form.remind,
                  onChanged: _form.busy ? null : _form.setRemind,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class FormOriginalsSection extends StatelessWidget {
  const FormOriginalsSection({required this.form, super.key});

  final ItemFormViewModel form;

  Future<void> _pick(BuildContext context) async {
    final files = await AddFlow.chooseOriginals(context);
    if (context.mounted && files.isNotEmpty && !form.busy) form.addFiles(files);
  }

  Future<void> _remove(
    BuildContext context,
    String name,
    VoidCallback onRemove,
  ) async {
    final remove = await showPdActions<bool>(
      context,
      title: name,
      actions: const [
        PdAction(label: 'Remove from item', value: true, destructive: true),
      ],
    );
    if (context.mounted && remove == true && !form.busy) onRemove();
  }

  @override
  Widget build(BuildContext context) => PdListGroup(
    header: 'Originals',
    children: [
      for (final file in form.retained)
        PdListRow(
          title: file.name,
          actionIcon: LucideIcons.ellipsis,
          onTap: form.busy
              ? null
              : () => _remove(
                  context,
                  file.name,
                  () => form.removeOriginal(file),
                ),
        ),
      for (final file in form.added)
        PdListRow(
          title: file.name,
          actionIcon: LucideIcons.ellipsis,
          onTap: form.busy
              ? null
              : () => _remove(context, file.name, () => form.removeAdded(file)),
        ),
      PdListRow(
        key: const ValueKey('item-add-original'),
        title: 'Add a photo or PDF',
        actionIcon: LucideIcons.plus,
        onTap: form.busy ? null : () => _pick(context),
      ),
    ],
  );
}
