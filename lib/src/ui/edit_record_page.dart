import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/vault_controller.dart';
import '../data/vault_record.dart';
import '../theme/drawer_theme.dart';
import 'design.dart';

Future<void> showAddEntry(
  BuildContext context, {
  RecordKind kind = RecordKind.receipt,
}) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => EditRecordPage(kind: kind)));

class EditRecordPage extends StatefulWidget {
  const EditRecordPage({required this.kind, this.record, super.key});

  final RecordKind kind;
  final VaultRecord? record;

  @override
  State<EditRecordPage> createState() => _EditRecordPageState();
}

class _EditRecordPageState extends State<EditRecordPage> {
  static const _imports = XTypeGroup(
    label: 'Photos and PDFs',
    extensions: ['jpg', 'jpeg', 'png', 'pdf', 'heic', 'heif', 'webp'],
    mimeTypes: ['image/*', 'application/pdf'],
    uniformTypeIdentifiers: ['public.image', 'com.adobe.pdf'],
  );

  final _form = GlobalKey<FormState>();
  late RecordKind _kind = widget.kind;
  late final _title = TextEditingController(text: widget.record?.draft.title);
  late final _source = TextEditingController(text: widget.record?.draft.source);
  late final _notes = TextEditingController(text: widget.record?.draft.notes);
  late final _amount = TextEditingController(
    text: widget.record?.draft.amountCents == null
        ? ''
        : (widget.record!.draft.amountCents! / 100).toStringAsFixed(2),
  );
  late DateTime? _date = widget.record?.draft.recordedOn;
  late DateTime? _deadline = widget.record?.draft.deadline;
  VaultAttachment? _picked;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _source.dispose();
    _notes.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pick(Future<XFile?> Function() pick) async {
    setState(() => _busy = true);
    try {
      final file = await pick();
      if (!mounted || file == null) return;
      setState(
        () => _picked = VaultAttachment(path: file.path, name: file.name),
      );
    } catch (_) {
      if (mounted) {
        _message('Couldn’t open the picker. Check permissions and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final vault = context.read<VaultController>();
    setState(() => _busy = true);
    try {
      await vault.save(
        VaultDraft(
          kind: _kind,
          title: _title.text,
          source: _source.text,
          notes: _notes.text,
          amountCents: _kind == RecordKind.receipt
              ? parseAmountCents(_amount.text)
              : null,
          recordedOn: _date,
          deadline: _deadline,
        ),
        id: widget.record?.id,
        import: _picked,
      );
      if (mounted) Navigator.of(context).pop();
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) {
        _message(
          'Couldn’t save this item. Check available space and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final editing = widget.record != null;
    final attachment = _picked ?? widget.record?.attachment;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit item' : 'Add an item')),
      body: Form(
        key: _form,
        child: DrawerPage(
          children: [
            Text(
              editing ? 'Edit details' : 'Keep it on record.',
              style: displayStyle(colors.text, 38),
            ),
            const SizedBox(height: 9),
            if (!editing)
              Text(
                'Add a photo or PDF, or enter the details yourself.',
                style: TextStyle(color: colors.muted, height: 1.4),
              ),
            const SizedBox(height: 19),
            if (widget.record?.attachment == null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_camera_outlined, size: 19),
                    label: const Text('Camera'),
                    onPressed: _busy
                        ? null
                        : () => _pick(
                            () => ImagePicker().pickImage(
                              source: ImageSource.camera,
                            ),
                          ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Photos'),
                    onPressed: _busy
                        ? null
                        : () => _pick(
                            () => ImagePicker().pickImage(
                              source: ImageSource.gallery,
                            ),
                          ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file, size: 18),
                    label: const Text('Files'),
                    onPressed: _busy
                        ? null
                        : () => _pick(
                            () => openFile(acceptedTypeGroups: [_imports]),
                          ),
                  ),
                ],
              ),
            if (attachment != null) ...[
              const SizedBox(height: 10),
              PaperPanel(
                child: Row(
                  children: [
                    Icon(Icons.attach_file, size: 18, color: colors.marker),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attachment.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_picked != null)
                      IconButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _picked = null),
                        tooltip: 'Remove selection',
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            DropdownButtonFormField<RecordKind>(
              initialValue: _kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              enabled: !_busy,
              onChanged: (value) {
                if (value != null) setState(() => _kind = value);
              },
              items: [
                for (final kind in RecordKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('item-title'),
              controller: _title,
              enabled: !_busy,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                counterText: '',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _source,
              enabled: !_busy,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _kind.sourceLabel,
                counterText: '',
              ),
            ),
            if (_kind == RecordKind.receipt) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Amount (USD)',
                  prefixText: '\$',
                ),
                validator: (value) {
                  try {
                    parseAmountCents(value ?? '');
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            _DateRow(
              label: _kind == RecordKind.receipt ? 'Purchased on' : 'Issued on',
              value: _date,
              enabled: !_busy,
              onChanged: (value) => setState(() => _date = value),
            ),
            const SizedBox(height: 8),
            _DateRow(
              label: _kind.deadlineLabel,
              value: _deadline,
              enabled: !_busy,
              onChanged: (value) => setState(() => _deadline = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              enabled: !_busy,
              maxLength: 4000,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                counterText: '',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('save-item'),
              onPressed: _busy ? null : _save,
              child: Text(
                _busy
                    ? 'Working…'
                    : editing
                    ? 'Save changes'
                    : 'Save to vault',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => PaperPanel(
    padding: EdgeInsets.zero,
    child: ListTile(
      enabled: enabled,
      title: Text(label),
      subtitle: Text(value == null ? 'No date' : displayDate(value!)),
      leading: Icon(
        Icons.calendar_today_outlined,
        size: 19,
        color: context.palette.marker,
      ),
      trailing: value == null
          ? const Icon(Icons.chevron_right, size: 19)
          : IconButton(
              onPressed: enabled ? () => onChanged(null) : null,
              icon: const Icon(Icons.close, size: 19),
              tooltip: 'Clear date',
            ),
      onTap: enabled
          ? () async {
              final current = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value == null
                    ? current
                    : DateUtils.dateOnly(value!),
                firstDate: DateTime(1900),
                lastDate: DateTime(current.year + 80, 12, 31),
                helpText: label,
              );
              if (context.mounted && picked != null) {
                onChanged(civilDate(picked));
              }
            }
          : null,
    ),
  );
}
