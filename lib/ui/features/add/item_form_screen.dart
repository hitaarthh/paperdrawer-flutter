import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/claim_repository.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../data/services/today.dart';
import '../../../domain/bill_reader.dart';
import '../../../domain/formats.dart';
import '../../../domain/models/item.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../../core/widgets/text_field.dart';
import '../account/shared_session.dart';
import '../reminders/reminder_permission.dart';
import 'add_details_args.dart';
import 'item_form_sections.dart';
import 'item_form_view_model.dart';

enum _DateAction { change, clear }

class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen.create(this.initial, {this.shared = false, super.key})
    : id = null;
  const ItemFormScreen.edit(this.id, {super.key})
    : initial = null,
      shared = false;

  final AddDetailsArgs? initial;
  final String? id;
  final bool shared;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  late final ItemRepository _items;
  ItemFormViewModel? _form;
  late final TextEditingController _name;
  late final TextEditingController _source;
  late final TextEditingController _reference;
  late final TextEditingController _serial;
  late final TextEditingController _amount;
  late final TextEditingController _notes;
  final _edited = <ReadField>{};

  @override
  void initState() {
    super.initState();
    final id = widget.id;
    if (!widget.shared) _items = context.read<ItemRepository>();
    final original = id == null ? null : _items.byId(id);
    if (id != null && original == null) return;
    final createShared = widget.shared
        ? context.read<SharedSession>().itemCreator()
        : null;
    final form = ItemFormViewModel(
      (draft, files, removed) {
        if (createShared != null) {
          return createShared(draft, files.singleOrNull);
        }
        if (id == null) return _items.create(draft, files: files);
        return _items.update(
          id,
          draft,
          addFiles: files,
          removeAttachmentIds: removed,
        );
      },
      initial: widget.initial,
      original: original,
      shared: widget.shared,
    );
    _form = form;
    _name = TextEditingController(text: form.initialName);
    _source = TextEditingController(text: form.initialSource);
    _reference = TextEditingController(text: form.initialReference);
    _serial = TextEditingController(text: form.initialSerial);
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
      _serial.dispose();
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
      serialNumber: _serial.text,
      amount: _amount.text,
      notes: _notes.text,
    );
    if (!mounted || saved == null) return;
    if (widget.shared) {
      showPdSnackbar(context, 'Saved to your vault', success: true);
      context.go(Routes.item(saved.id));
      return;
    }
    final creating = widget.id == null;
    if (creating &&
        shouldOfferReminders(
          scheduler: context.read<ReminderScheduler?>(),
          settings: context.read<SettingsRepository>(),
          saved: saved,
          today: context.read<Today>().value,
        )) {
      // Offer reminders once, over this form; closing it closes both, and
      // the "Saved" snackbar (with Undo) follows on the vault.
      await context.push<void>(Routes.reminders);
      if (!mounted) return;
    }
    final appContext = rootNavigatorKey.currentContext;
    showPdSnackbar(
      context,
      creating ? _savedMessage(saved) : 'Changes saved',
      success: true,
      action: creating ? 'Undo' : null,
      onAction: creating
          ? () async {
              try {
                await _items.delete(saved.id);
              } catch (_) {
                if (appContext != null && appContext.mounted) {
                  showPdSnackbar(
                    appContext,
                    'The save couldn’t be undone. Try again from the item.',
                  );
                }
              }
            }
          : null,
    );
    if (creating) {
      context.go(Routes.vaultWithRecent(saved.id));
    } else {
      _close();
    }
  }

  String _savedMessage(Item saved) {
    final settings = context.read<SettingsRepository>();
    if (!settings.remindersOn || context.read<ReminderScheduler?>() == null) {
      return 'Saved to your drawer';
    }
    final plans = planReminders(
      items: _items.active,
      claims: context.read<ClaimRepository>().claims,
      leadDays: settings.leadDays,
      now: context.read<Today>().instant,
    );
    final next = plans
        .where((plan) => plan.location == Routes.item(saved.id))
        .firstOrNull;
    return next == null
        ? 'Saved to your drawer'
        : 'Saved. Next reminder planned for ${shortDate(next.at)}.';
  }

  bool _read(ItemFormViewModel form, ReadField field) =>
      form.readFields.contains(field) && !_edited.contains(field);

  void _edit(ReadField field) {
    if (_form!.readFields.contains(field) && _edited.add(field)) {
      setState(() {});
    }
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

  Future<void> _retake(ItemFormViewModel form) async {
    final confirmed = await showPdConfirm(
      context,
      title: 'Retake the original?',
      message: 'You’ll review the details again after the new scan.',
      confirmLabel: 'Retake',
    );
    if (!mounted || !confirmed || form.busy) return;
    context.pushReplacement(Routes.camera, extra: form.kind);
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
          DashedTile(
            title: 'Item unavailable',
            body: 'This item is no longer in your drawer.',
          ),
        ],
      );
    }
    final original = widget.initial?.files.firstOrNull;
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) => PopScope(
        canPop: !form.busy,
        child: PdPushedScaffold(
          backLabel: 'Cancel',
          onBack: _close,
          kicker: original == null
              ? null
              : 'NEW ${form.kind.chip} · ${form.reviewedFieldCount} '
                    '${form.reviewedFieldCount == 1 ? 'FIELD' : 'FIELDS'} READ',
          title: widget.id != null
              ? 'Edit details'
              : original == null
              ? 'Check the details'
              : 'Check what we read',
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (form.error case final error?)
                Padding(
                  padding: const EdgeInsets.only(bottom: Pd.s2),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: PdType.footnote.copyWith(color: Pd.signal),
                    ),
                  ),
                ),
              PdButton.primary(
                key: const ValueKey('save-to-drawer'),
                label: widget.id == null ? 'Save to vault' : 'Save changes',
                expand: true,
                busy: form.busy,
                onPressed: form.busy ? null : () => _save(form),
              ),
            ],
          ),
          children: [
            if (original != null) ...[
              if (form.added.contains(original)) ...[
                FormReviewOriginal(
                  key: ValueKey(original.path),
                  original: original,
                  onRetake: form.busy ? null : () => _retake(form),
                ),
                const SizedBox(height: Pd.s4),
              ],
              Padding(
                padding: const EdgeInsets.only(bottom: Pd.s5),
                child: Text(
                  'Check the fields marked Read from bill. Add details we couldn’t read.',
                  style: PdType.callout.copyWith(color: Pd.textMuted),
                ),
              ),
            ],
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _edit(ReadField.amount),
            ),
            const SizedBox(height: Pd.s4),
            PdFieldButton(
              key: const ValueKey('item-start-date'),
              label: form.startsLabel,
              value: form.startsOn == null ? '' : longDate(form.startsOn!),
              hint: form.shared && form.kind == ItemKind.bill
                  ? 'Required'
                  : 'Choose a date',
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
            if (form.kind == ItemKind.bill) ...[
              const SizedBox(height: Pd.s4),
              PdTextField(
                fieldKey: const ValueKey('item-serial-number'),
                label: 'Serial no.',
                hint: 'Optional',
                help:
                    original != null &&
                        !form.readFields.contains(ReadField.serialNumber)
                    ? 'Couldn’t read the serial number from the original.'
                    : null,
                controller: _serial,
                textCapitalization: TextCapitalization.characters,
                readFromBill: _read(form, ReadField.serialNumber),
                enabled: !form.busy,
                onChanged: (_) => _edit(ReadField.serialNumber),
              ),
            ],
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
        ),
      ),
    );
  }
}
