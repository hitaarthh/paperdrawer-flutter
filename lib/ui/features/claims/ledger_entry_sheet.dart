import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../data/services/today.dart';
import '../../../domain/formats.dart';
import '../../../domain/models/item.dart';
import '../../../domain/models/ledger.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/chips.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/text_field.dart';

String followUpLabel(DateTime at) => DateFormat('EEE d MMM, HH:mm').format(at.toLocal());

Future<bool?> showLedgerEntrySheet(
  BuildContext context, {
  required String title,
  required int number,
  required Today clock,
  required Future<PendingFile?> Function() pickPhoto,
  required Future<void> Function(LedgerDraft) save,
}) => showPdCustomSheet<bool>(
  context,
  semanticLabel: 'Add a ledger entry',
  builder: (_) => _LedgerEntryForm(
    title: title,
    number: number,
    clock: clock,
    pickPhoto: pickPhoto,
    save: save,
  ),
);

class _LedgerEntryForm extends StatefulWidget {
  const _LedgerEntryForm({
    required this.title,
    required this.number,
    required this.clock,
    required this.pickPhoto,
    required this.save,
  });

  final String title;
  final int number;
  final Today clock;
  final Future<PendingFile?> Function() pickPhoto;
  final Future<void> Function(LedgerDraft) save;

  @override
  State<_LedgerEntryForm> createState() => _LedgerEntryFormState();
}

class _LedgerEntryFormState extends State<_LedgerEntryForm> {
  final _id = const Uuid().v4();
  final _text = TextEditingController();
  final _reference = TextEditingController();
  late DateTime _date = widget.clock.value;
  LedgerKind _kind = LedgerKind.call;
  DateTime? _followUp;
  PendingFile? _photo;
  String? _error;
  bool _saving = false;
  bool _picking = false;

  bool get _busy => _saving || _picking;

  @override
  void dispose() {
    _text.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    FocusScope.of(context).unfocus();
    final date = await showPdDatePicker(
      context,
      initial: _date,
      max: widget.clock.value,
      title: 'Entry date',
    );
    if (!mounted || date == null) return;
    setState(() => _date = date);
  }

  Future<void> _chooseFollowUp() async {
    FocusScope.of(context).unfocus();
    final at = await showPdFollowUpPicker(
      context,
      now: widget.clock.instant.toLocal(),
      initial: _followUp,
    );
    if (!mounted || at == null) return;
    setState(() => _followUp = at);
  }

  Future<void> _choosePhoto() async {
    FocusScope.of(context).unfocus();
    setState(() => _picking = true);
    try {
      final photo = await widget.pickPhoto();
      if (!mounted || photo == null) return;
      setState(() {
        _photo = photo;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Photos couldn’t open. Try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final entry = LedgerDraft(
      id: _id,
      kind: _kind,
      date: _date,
      text: _text.text,
      reference: _reference.text,
      photo: _photo,
      followUp: _followUp,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      entry.validate(widget.clock.instant);
      await widget.save(entry);
      if (!mounted) return;
      Navigator.of(context).pop(entry.followUp != null);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Your entry couldn’t be saved. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    final followUp = _followUp;
    return PopScope(
      canPop: !_saving,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Pd.s3,
        children: [
          Text(
            '${widget.title.toUpperCase()} · ENTRY ${widget.number}',
            style: PdType.label.copyWith(color: Pd.textMuted),
          ),
          const Semantics(
            header: true,
            child: Text('What happened?', style: PdType.title1),
          ),
          Wrap(
            spacing: Pd.s1,
            children: [
              for (final kind in LedgerKind.values)
                PdChoiceChip(
                  key: ValueKey('ledger-kind-${kind.name}'),
                  label: kind.label,
                  onPaper: false,
                  selected: _kind == kind,
                  onTap: () {
                    if (!_busy) setState(() => _kind = kind);
                  },
                ),
            ],
          ),
          PdTextField(
            label: 'In a line or two',
            hint: 'Write what happened',
            controller: _text,
            fieldKey: const ValueKey('ledger-entry-text'),
            maxLines: 3,
            enabled: !_busy,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Pd.s2,
            children: [
              Expanded(
                child: PdFieldButton(
                  key: const ValueKey('ledger-entry-date'),
                  label: 'Date',
                  value: monoDate(_date),
                  onTap: () {
                    if (!_busy) _chooseDate();
                  },
                ),
              ),
              Expanded(
                child: PdTextField(
                  label: 'Reference no.',
                  hint: 'Optional',
                  controller: _reference,
                  fieldKey: const ValueKey('ledger-entry-reference'),
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.none,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: Pd.s2,
            runSpacing: Pd.s1,
            children: [
              PdButton.secondary(
                key: const ValueKey('ledger-entry-photo'),
                label: photo == null ? 'Attach photo' : 'Change photo',
                icon: const Icon(LucideIcons.camera),
                busy: _picking,
                onPressed: _busy ? null : _choosePhoto,
              ),
              PdButton.secondary(
                key: const ValueKey('ledger-entry-follow-up'),
                label: followUp == null ? 'Set follow-up' : followUpLabel(followUp),
                icon: const Icon(LucideIcons.bell),
                onPressed: _busy ? null : _chooseFollowUp,
              ),
            ],
          ),
          if (photo != null)
            _OptionalSelection(label: photo.name, onRemove: _busy ? null : () => setState(() => _photo = null)),
          if (followUp != null)
            _OptionalSelection(label: 'Follow-up reminder', onRemove: _busy ? null : () => setState(() => _followUp = null)),
          if (_error case final message?)
            Semantics(
              liveRegion: true,
              child: Text(message, style: PdType.footnote.copyWith(color: Pd.signalSoft)),
            ),
          ValueListenableBuilder(
            valueListenable: _text,
            builder: (context, value, _) => PdButton.primary(
              key: const ValueKey('ledger-entry-save'),
              label: 'Add to ledger',
              expand: true,
              busy: _saving,
              onPressed: _busy || value.text.trim().isEmpty ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionalSelection extends StatelessWidget {
  const _OptionalSelection({required this.label, required this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Row(
    spacing: Pd.s2,
    children: [
      Expanded(child: Text(label, style: PdType.footnote)),
      PdButton.text(label: 'Remove', onPressed: onRemove),
    ],
  );
}
