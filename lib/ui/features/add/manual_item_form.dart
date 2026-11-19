import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/item_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/capture_service.dart';
import '../../../data/services/reminder_scheduler.dart';
import '../../../data/services/today.dart';
import '../../../domain/formats.dart';
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
import '../../core/widgets/text_field.dart';
import '../account/shared_session.dart';
import '../reminders/reminder_permission.dart';
import 'add_details_args.dart';
import 'item_form_view_model.dart';

class ManualItemForm extends StatefulWidget {
  const ManualItemForm({
    this.id,
    this.kind = ItemKind.bill,
    this.shared = false,
    super.key,
  });

  final String? id;
  final ItemKind kind;
  final bool shared;

  @override
  State<ManualItemForm> createState() => _ManualItemFormState();
}

class _ManualItemFormState extends State<ManualItemForm> {
  ItemFormViewModel? _form;
  final _title = TextEditingController();
  final _scroll = ScrollController();
  final _fileField = GlobalKey();
  final _saveError = GlobalKey();
  bool _picking = false;
  bool _saving = false;
  String? _fileError;

  bool get _editing => widget.id != null;
  String get _heading => _editing ? 'Edit item' : 'Add a file';
  bool get _blocked => _picking || _saving;

  @override
  void initState() {
    super.initState();
    final items = widget.shared ? null : context.read<ItemRepository>();
    final original = widget.id == null ? null : items?.byId(widget.id!);
    if (_editing && original == null) return;
    final createShared = widget.shared
        ? context.read<SharedSession>().itemCreator()
        : null;
    final form = _form = ItemFormViewModel(
      (draft, files, removed) {
        if (createShared != null) return createShared(draft, files.single);
        if (original == null) return items!.create(draft, files: files);
        return items!.update(
          original.id,
          draft,
          addFiles: files,
          removeAttachmentIds: removed,
          prependOriginal: true,
        );
      },
      initial: AddDetailsArgs(kind: widget.kind),
      original: original,
      shared: widget.shared,
      fileFirst: true,
    );
    _title.text = form.initialName;
  }

  @override
  void dispose() {
    _form?.dispose();
    _title.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _close() {
    if (_blocked) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(_editing ? Routes.item(widget.id!) : Routes.home);
    }
  }

  Future<void> _pick(ItemFormViewModel form) async {
    setState(() {
      _picking = true;
      _fileError = null;
    });
    try {
      final file = (await context.read<CaptureService>().pickFiles(
        single: true,
      )).firstOrNull;
      if (!mounted || file == null) return;
      form.replacePrimary(file);
    } catch (_) {
      if (mounted)
        setState(() => _fileError = 'Couldn’t open Files. Try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _chooseKind(ItemFormViewModel form) async {
    final kind = await showPdActions<ItemKind>(
      context,
      title: 'Type',
      actions: [
        for (final value in ItemKind.values)
          PdAction(label: _kindLabel(value), value: value),
      ],
    );
    if (!mounted || _blocked || kind == null || kind == form.kind) return;
    form.setKind(kind);
  }

  Future<void> _chooseMeaning(ItemFormViewModel form) async {
    final renews = await showPdActions<bool>(
      context,
      title: 'Date type',
      actions: [
        const PdAction(label: 'Renewal', value: true),
        PdAction(
          label: form.kind == ItemKind.policy ? 'Expiry' : 'End date',
          value: false,
        ),
      ],
    );
    if (mounted && !_blocked && renews != null) form.setCoverageRenews(renews);
  }

  Future<void> _chooseDate(
    ItemFormViewModel form, {
    bool purchase = false,
  }) async {
    final label = purchase ? 'Purchase date' : _dateLabel(form.kind);
    final current = purchase ? form.startsOn : form.coverUntil;
    final actions = current == null
        ? null
        : await showPdActions<bool>(
            context,
            title: label,
            actions: const [
              PdAction(label: 'Change date', value: true),
              PdAction(label: 'Clear date', value: false),
            ],
          );
    if (!mounted || _blocked || (current != null && actions == null)) return;
    final date = actions == false
        ? null
        : await showPdDatePicker(context, title: label, initial: current);
    if (!mounted || _blocked || (actions != false && date == null)) return;
    if (purchase) {
      form.setStartsOn(date);
    } else {
      form.setCoverUntil(date);
    }
  }

  Future<void> _chooseReminder(ItemFormViewModel form) async {
    final date = await showPdFollowUpPicker(
      context,
      title: 'Reminder date and time',
      now: context.read<Today>().instant,
      initial: form.reminderAt,
    );
    if (mounted && !_blocked && date != null) form.setReminderAt(date);
  }

  Future<void> _save(ItemFormViewModel form) async {
    if (_blocked) return;
    if (!_editing && form.added.isEmpty) {
      setState(() => _fileError = 'Choose a file to continue.');
      _reveal(_fileField);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final saved = await form.save(
        name: _title.text,
        source: form.initialSource,
        reference: form.initialReference,
        serialNumber: form.initialSerial,
        amount: form.initialAmount,
        notes: form.initialNotes,
      );
      if (!mounted) return;
      if (saved == null) {
        _reveal(_saveError);
        return;
      }
      if (!widget.shared && saved.draft.reminderAt != null) {
        final settings = context.read<SettingsRepository>();
        if (!settings.remindersOn && !settings.remindersOffered) {
          try {
            await turnOnReminders(context.read<ReminderScheduler?>(), settings);
          } catch (_) {
            if (mounted)
              showPdSnackbar(context, 'Check notification access in Settings.');
          }
          if (!mounted) return;
        }
      }
      showPdSnackbar(
        context,
        _editing ? 'Changes saved' : 'Saved to drawer',
        success: true,
      );
      if (_editing && context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.item(saved.id));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reveal(GlobalKey field) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = field.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, alignment: .15);
      } else {
        _scroll.jumpTo(
          field == _fileField ? 0 : _scroll.position.maxScrollExtent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    if (form == null) {
      return PdPushedScaffold(
        title: _heading,
        backLabel: 'Cancel',
        onBack: _close,
        closeOnRight: true,
        children: const [
          DashedTile(title: 'Item unavailable', body: 'Return to your drawer.'),
        ],
      );
    }
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) {
        final name =
            form.added.firstOrNull?.name ?? form.retained.firstOrNull?.name;
        final allowsMeaning =
            !widget.shared &&
            (form.kind == ItemKind.policy || form.kind == ItemKind.agreement);
        return PopScope(
          canPop: !_blocked,
          child: PdPushedScaffold(
            title: _heading,
            backLabel: 'Cancel',
            onBack: _close,
            closeOnRight: true,
            controller: _scroll,
            bottom: PdButton.primary(
              key: const ValueKey('save-to-drawer'),
              label: _editing ? 'Save changes' : 'Save to drawer',
              busy: _saving,
              expand: true,
              onPressed: _blocked ? null : () => _save(form),
            ),
            children: [
              PdFieldButton(
                key: const ValueKey('choose-original'),
                label: 'Original file',
                value: name ?? '',
                hint: 'Choose from Files',
                onTap: () {
                  if (!_blocked) _pick(form);
                },
              ),
              if (_fileError case final error?)
                KeyedSubtree(key: _fileField, child: _inlineError(error))
              else if (name == null)
                Padding(
                  padding: const EdgeInsets.only(top: Pd.s1),
                  child: Text(
                    'PDF or image',
                    style: PdType.footnote.copyWith(color: Pd.textMuted),
                  ),
                ),
              const SizedBox(height: Pd.s4),
              PdTextField(
                fieldKey: const ValueKey('item-name'),
                label: 'Title',
                hint: form.kind.nameHint,
                controller: _title,
                enabled: !_blocked,
                validator: ItemFormViewModel.validateName,
              ),
              const SizedBox(height: Pd.s4),
              PdFieldButton(
                key: const ValueKey('item-kind-picker'),
                label: 'Type',
                value: _kindLabel(form.kind),
                onTap: () {
                  if (!_blocked) _chooseKind(form);
                },
              ),
              if (widget.shared && form.kind == ItemKind.bill) ...[
                const SizedBox(height: Pd.s4),
                PdFieldButton(
                  key: const ValueKey('item-start-date'),
                  label: 'Purchase date',
                  value: form.startsOn == null ? '' : longDate(form.startsOn!),
                  hint: 'Required',
                  onTap: () {
                    if (!_blocked) _chooseDate(form, purchase: true);
                  },
                ),
              ],
              const SizedBox(height: Pd.s4),
              if (allowsMeaning) ...[
                PdFieldButton(
                  key: const ValueKey('coverage-date-kind'),
                  label: 'Date type',
                  value: form.coverageRenews
                      ? 'Renewal'
                      : (form.kind == ItemKind.policy ? 'Expiry' : 'End date'),
                  onTap: () {
                    if (!_blocked) _chooseMeaning(form);
                  },
                ),
                const SizedBox(height: Pd.s3),
              ],
              PdFieldButton(
                key: const ValueKey('coverage-date'),
                label: _dateLabel(form.kind),
                value: form.coverUntil == null
                    ? ''
                    : longDate(form.coverUntil!),
                hint: widget.shared && form.kind != ItemKind.bill
                    ? 'Required'
                    : 'Optional',
                onTap: () {
                  if (!_blocked) _chooseDate(form);
                },
              ),
              if (!widget.shared) ...[
                const SizedBox(height: Pd.s4),
                PdListRow(
                  title: 'Remind me',
                  trailing: PdSwitch(
                    key: const ValueKey('item-reminder-switch'),
                    value: form.remind,
                    onChanged: _blocked
                        ? null
                        : (enabled) {
                            if (!enabled) {
                              form.setRemind(false);
                            } else {
                              _chooseReminder(form);
                            }
                          },
                  ),
                ),
                if (form.remind)
                  PdFieldButton(
                    key: const ValueKey('item-reminder-date'),
                    label: 'Reminder date and time',
                    value: form.reminderAt == null
                        ? 'Automatic'
                        : DateFormat('d MMM yyyy, h:mm a')
                              .format(form.reminderAt!.toLocal()),
                    onTap: () {
                      if (!_blocked) _chooseReminder(form);
                    },
                  ),
              ],
              if (form.error case final error?)
                KeyedSubtree(key: _saveError, child: _inlineError(error)),
            ],
          ),
        );
      },
    );
  }

  Widget _inlineError(String message) => Padding(
    padding: const EdgeInsets.only(top: Pd.s2),
    child: Semantics(
      liveRegion: true,
      child: Text(message, style: PdType.footnote.copyWith(color: Pd.signal)),
    ),
  );

  String _dateLabel(ItemKind kind) => switch (kind) {
    ItemKind.bill => 'Warranty end date',
    ItemKind.policy => widget.shared ? 'Renewal date' : 'Policy date',
    ItemKind.vehicle => 'Valid until',
    ItemKind.agreement => 'Agreement date',
  };

  String _kindLabel(ItemKind kind) =>
      kind == ItemKind.vehicle ? 'Vehicle papers' : kind.label;
}
