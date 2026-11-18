import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../domain/bill_reader.dart';
import '../../../domain/formats.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../../core/widgets/text_field.dart';
import 'add_details_args.dart';
import 'item_form_sections.dart';
import 'item_form_view_model.dart';

enum _DateAction { change, clear }

class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen.create(this.initial, {super.key}) : id = null;
  const ItemFormScreen.edit(this.id, {super.key}) : initial = null;

  final AddDetailsArgs? initial;
  final String? id;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  late final ItemRepository _items;
  ItemFormViewModel? _form;
  late final TextEditingController _name;
  late final TextEditingController _source;
  late final TextEditingController _reference;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  final _edited = <ReadField>{};

  @override
  void initState() {
    super.initState();
    _items = context.read<ItemRepository>();
    final id = widget.id;
    final original = id == null ? null : _items.byId(id);
    if (id != null && original == null) return;
    final form = ItemFormViewModel(_items, initial: widget.initial, original: original);
    _form = form;
    _name = TextEditingController(text: form.initialName);
    _source = TextEditingController(text: form.initialSource);
    _reference = TextEditingController(text: form.initialReference);
    _amount = TextEditingController(text: form.initialAmount);
    _notes = TextEditingController(text: form.initialNotes);
  }

  @override
  void dispose() {
    final form = _form;
    if (form != null) {
      _name.dispose();
      _source.dispose();
      _reference.dispose();
      _amount.dispose();
      _notes.dispose();
      form.dispose();
    }
    super.dispose();
  }

  void _close() {
    if (_form?.busy ?? false) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(widget.id == null ? Routes.vault : Routes.item(widget.id!));
    }
  }

  Future<void> _save(ItemFormViewModel form) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = await form.save(
      name: _name.text,
      source: _source.text,
      reference: _reference.text,
      amount: _amount.text,
      notes: _notes.text,
    );
    if (!mounted || saved == null) return;
    final creating = widget.id == null;
    final appContext = rootNavigatorKey.currentContext;
    showPdSnackbar(
      context,
      creating ? 'Saved to your drawer' : 'Changes saved',
      success: true,
      action: creating ? 'Undo' : null,
      onAction: creating
          ? () async {
              try {
                await _items.delete(saved.id);
              } catch (_) {
                if (appContext?.mounted ?? false) {
                  showPdSnackbar(appContext!, 'The save couldn’t be undone. Try again from the item.');
                }
              }
            }
          : null,
    );
    _close();
  }

  bool _read(ItemFormViewModel form, ReadField field) =>
      form.readFields.contains(field) && !_edited.contains(field);

  void _edit(ReadField field) {
    if (_form!.readFields.contains(field) && _edited.add(field)) setState(() {});
  }

  Future<void> _chooseStart(ItemFormViewModel form) async {
    if (form.startsOn != null) {
      final action = await showPdActions<_DateAction>(
        context,
        title: form.startsLabel,
        actions: const [
          PdAction(label: 'Change date', value: _DateAction.change),
          PdAction(label: 'Clear date', value: _DateAction.clear),
        ],
      );
      if (!mounted || action == null) return;
      if (action == _DateAction.clear) {
        _edit(ReadField.startsOn);
        form.setStartsOn(null);
        return;
      }
    }
    final date = await showPdDatePicker(
      context,
      title: form.startsLabel,
      initial: form.startsOn,
    );
    if (!mounted || date == null) return;
    _edit(ReadField.startsOn);
    form.setStartsOn(date);
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    if (form == null) {
      return PdPushedScaffold(
        backLabel: 'Close',
        title: 'Edit details',
        onBack: _close,
        children: const [
          DashedTile(title: 'Item unavailable', body: 'This item is no longer in your drawer.'),
        ],
      );
    }
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) => PopScope(
        canPop: !form.busy,
        child: PdPushedScaffold(
          backLabel: 'Cancel',
          onBack: _close,
          title: widget.id == null ? 'Check the details' : 'Edit details',
          children: [
            if (form.readFields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Pd.s5),
                child: Text(
                  'Check the details we read against your original.',
                  style: PdType.callout.copyWith(color: Pd.textMuted),
                ),
              )
            else if (widget.initial?.files.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(bottom: Pd.s5),
                child: Text(
                  'Your original is ready to save. Add the details you want to keep.',
                  style: PdType.callout.copyWith(color: Pd.textMuted),
                ),
              ),
            PdTextField(
              fieldKey: const ValueKey('item-name'),
              label: form.kind.nameLabel,
              hint: form.kind.nameHint,
              controller: _name,
              validator: ItemFormViewModel.validateName,
              readFromBill: _read(form, ReadField.name),
              enabled: !form.busy,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _edit(ReadField.name),
            ),
            const SizedBox(height: Pd.s4),
            PdTextField(
              fieldKey: const ValueKey('item-source'),
              label: form.kind.sourceLabel,
              hint: form.kind.sourceHint,
              controller: _source,
              readFromBill: _read(form, ReadField.source),
              enabled: !form.busy,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _edit(ReadField.source),
            ),
            const SizedBox(height: Pd.s4),
            PdTextField(
              fieldKey: const ValueKey('item-amount'),
              label: form.kind.amountLabel,
              hint: 'e.g. 2,999.50',
              controller: _amount,
              prefixText: form.currencyPrefix,
              validator: ItemFormViewModel.validateAmount,
              readFromBill: _read(form, ReadField.amount),
              enabled: !form.busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _edit(ReadField.amount),
            ),
            const SizedBox(height: Pd.s4),
            PdFieldButton(
              key: const ValueKey('item-start-date'),
              label: form.startsLabel,
              value: form.startsOn == null ? '' : longDate(form.startsOn!),
              hint: 'Choose a date',
              readFromBill: _read(form, ReadField.startsOn),
              onTap: () {
                if (!form.busy) _chooseStart(form);
              },
            ),
            const SizedBox(height: Pd.s4),
            PdTextField(
              fieldKey: const ValueKey('item-reference'),
              label: form.kind.referenceLabel,
              controller: _reference,
              textCapitalization: TextCapitalization.characters,
              readFromBill: _read(form, ReadField.reference),
              enabled: !form.busy,
              onChanged: (_) => _edit(ReadField.reference),
            ),
            const SizedBox(height: Pd.s6),
            FormCoverSection(form: form),
            const SizedBox(height: Pd.s6),
            FormOriginalsSection(form: form),
            const SizedBox(height: Pd.s6),
            PdTextField(
              fieldKey: const ValueKey('item-notes'),
              label: 'Notes',
              hint: 'Anything you want to remember',
              controller: _notes,
              maxLines: 3,
              enabled: !form.busy,
            ),
          ],
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (form.error case final error?)
                Padding(
                  padding: const EdgeInsets.only(bottom: Pd.s2),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(error, style: PdType.footnote.copyWith(color: Pd.signal)),
                  ),
                ),
              PdButton.primary(
                key: const ValueKey('save-to-drawer'),
                label: widget.id == null ? 'Save to drawer' : 'Save changes',
                expand: true,
                busy: form.busy,
                onPressed: form.busy ? null : () => _save(form),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
