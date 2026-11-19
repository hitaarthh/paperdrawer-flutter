import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../data/services/capture_service.dart';
import '../../../domain/bill_reader.dart';
import '../../../domain/formats.dart';
import '../../../domain/models/item.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/list_row.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import '../../core/widgets/text_field.dart';
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
  bool _editedComponentWarranty = false;
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
    final options = returns ? const [7, 10, 14, 30] : const [6, 12, 24, 36];
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

  Future<void> _chooseComponentWarranty() async {
    final initial = _form.componentWarrantyUntil;
    final action = await showPdActions<_WindowAction>(
      context,
      title: 'Component warranty',
      actions: [
        const PdAction(label: 'Choose an end date', value: _WindowAction.exact),
        if (initial != null || _form.componentWarrantyMonths != null)
          const PdAction(label: 'Clear', value: _WindowAction.clear),
      ],
    );
    if (!mounted || action == null || _form.busy) return;
    if (action == _WindowAction.clear) {
      setState(() => _editedComponentWarranty = true);
      _form.setComponentWarrantyUntil(null);
      return;
    }
    final date = await showPdDatePicker(
      context,
      title: 'Component warranty end',
      initial: initial ?? _form.startsOn,
      min: _form.startsOn,
    );
    if (!mounted || date == null || _form.busy) return;
    setState(() => _editedComponentWarranty = true);
    _form.setComponentWarrantyUntil(date);
  }

  Future<void> _chooseLead(SettingsRepository settings) async {
    final days = await showPdActions<int>(
      context,
      title: 'Remind me before',
      actions: [
        for (final lead in SettingsRepository.leadDayChoices)
          PdAction(label: daysWord(lead), value: lead),
      ],
    );
    if (!mounted || days == null || _form.busy) return;
    try {
      await settings.setLeadDays(days);
    } catch (_) {
      if (!mounted) return;
      showPdSnackbar(
        context,
        'Couldn’t change the reminder timing. Try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBill = _form.kind == ItemKind.bill;
    final date = _form.coverUntil;
    final months = _form.warrantyMonths;
    final returnUntil = _form.returnUntil;
    final settings = context.watch<SettingsRepository>();
    final componentUntil = _form.componentWarrantyUntil;
    final componentName = _form.componentWarrantyName;
    final componentMonths = _form.componentWarrantyMonths;
    final dates = [date, returnUntil, componentUntil].nonNulls.length;
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
        if (isBill) ...[
          _Presets(
            title: 'Return window',
            options: const [0, 7, 10, 30],
            label: (days) => days == 0 ? 'NONE' : daysCaps(days),
            selected: _form.returnDays ?? 0,
            onSelect: (days) {
              if (_form.busy) return;
              if (days == 0) {
                _form.setReturnUntil(null);
              } else {
                _form.setReturnDays(days);
              }
            },
          ),
          const SizedBox(height: Pd.s4),
          _Presets(
            title:
                !_editedCover && _form.readFields.contains(ReadField.warranty)
                ? 'Warranty · Read from bill'
                : 'Warranty',
            options: const [6, 12, 24],
            label: (months) => monthsLabel(months).toUpperCase(),
            selected: months,
            onSelect: (value) {
              if (_form.busy) return;
              setState(() => _editedCover = true);
              _form.setWarrantyMonths(value);
            },
            onOther: _form.busy ? null : () => _chooseWindow(returns: false),
          ),
          const SizedBox(height: Pd.s4),
        ],
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
            if (isBill) ...[
              PdListRow(
                key: const ValueKey('item-component-warranty'),
                title: componentName.isEmpty
                    ? 'Component warranty'
                    : '$componentName warranty',
                value: componentUntil != null
                    ? longDate(componentUntil)
                    : componentMonths != null
                    ? monthsLabel(componentMonths)
                    : 'Optional',
                tag:
                    !_editedComponentWarranty &&
                        _form.readFields.contains(ReadField.componentWarranty)
                    ? 'Read from bill'
                    : null,
                chevron: true,
                onTap: _form.busy ? null : _chooseComponentWarranty,
              ),
              if (componentUntil != null || componentMonths != null)
                _ComponentWarrantyName(key: ObjectKey(_form), form: _form),
            ],
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
            if (dates > 0)
              PdListRow(
                title: '$dates ${dates == 1 ? 'date' : 'dates'} watched',
                value: _form.remind
                    ? 'Remind ${daysWord(settings.leadDays)} before'
                    : 'Reminder off for this item',
                tag: 'Change',
                onTap: _form.busy ? null : () => _chooseLead(settings),
              ),
          ],
        ),
      ],
    );
  }
}

class _ComponentWarrantyName extends StatefulWidget {
  const _ComponentWarrantyName({required this.form, super.key});

  final ItemFormViewModel form;

  @override
  State<_ComponentWarrantyName> createState() => _ComponentWarrantyNameState();
}

class _ComponentWarrantyNameState extends State<_ComponentWarrantyName> {
  late final _name = TextEditingController(
    text: widget.form.componentWarrantyName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Pd.s3),
    child: PdTextField(
      fieldKey: const ValueKey('item-component-warranty-name'),
      label: 'COVERED COMPONENT',
      hint: 'e.g. Compressor',
      enabled: !widget.form.busy,
      controller: _name,
      onChanged: widget.form.setComponentWarrantyName,
    ),
  );
}

class _Presets extends StatelessWidget {
  const _Presets({
    required this.title,
    required this.options,
    required this.label,
    required this.selected,
    required this.onSelect,
    this.onOther,
  });

  final String title;
  final List<int> options;
  final String Function(int) label;
  final int? selected;
  final ValueChanged<int> onSelect;
  final VoidCallback? onOther;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: Pd.s2,
    children: [
      Text(
        title.toUpperCase(),
        style: PdType.label.copyWith(color: Pd.textMuted),
      ),
      Wrap(
        spacing: Pd.s2,
        children: [
          for (final option in options)
            PdChoiceChip(
              label: label(option),
              selected: selected == option,
              onPaper: false,
              onTap: () => onSelect(option),
            ),
          if (onOther case final handler?)
            PdChoiceChip(
              label: 'OTHER',
              selected: false,
              onPaper: false,
              onTap: handler,
            ),
        ],
      ),
    ],
  );
}

class FormReviewOriginal extends StatefulWidget {
  const FormReviewOriginal({
    required this.original,
    required this.onRetake,
    super.key,
  });

  final PendingFile original;
  final VoidCallback? onRetake;

  @override
  State<FormReviewOriginal> createState() => _FormReviewOriginalState();
}

class _FormReviewOriginalState extends State<FormReviewOriginal> {
  late final _original = context.read<CaptureService>().inspect(
    widget.original,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _original,
    builder: (context, state) {
      final size = state.data?.size;
      final image = state.data?.preview;
      final description = size == null
          ? 'KEPT AS THE ORIGINAL'
          : '${_fileSize(size)} · KEPT AS THE ORIGINAL';
      final icon = Icon(
        LucideIcons.fileText,
        color: Pd.textMuted,
        size: Pd.iconMd,
      );
      return PdListGroup(
        children: [
          Padding(
            padding: const EdgeInsets.all(Pd.s3),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Pd.s3,
              runSpacing: Pd.s2,
              children: [
                SizedBox.square(
                  dimension: Pd.s12,
                  child: image == null
                      ? icon
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(Pd.rXs),
                          child: Image.memory(
                            image,
                            cacheWidth: 144,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                            errorBuilder: (_, _, _) => icon,
                          ),
                        ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.53,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.original.name, style: PdType.dataStrong),
                      Text(
                        description,
                        style: PdType.label.copyWith(color: Pd.textMuted),
                      ),
                    ],
                  ),
                ),
                PdButton.text(
                  key: const ValueKey('review-retake'),
                  label: 'Retake',
                  onPressed: widget.onRetake,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
