import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../data/vault_controller.dart';
import '../data/vault_record.dart';
import '../theme/drawer_theme.dart';
import 'design.dart';
import 'edit_record_page.dart';

Future<void> showRecord(BuildContext context, String id) =>
    Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => RecordPage(id: id)));

class RecordPage extends StatefulWidget {
  const RecordPage({required this.id, super.key});

  final String id;

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  bool _busy = false;

  Future<void> _archive(VaultController vault, VaultRecord record) async {
    setState(() => _busy = true);
    try {
      await vault.setArchived(record.id, !record.isArchived);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t update the archive. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultController>();
    final colors = context.palette;
    final record = vault.record(widget.id);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vault')),
        body: const Center(child: Text('This item is unavailable.')),
      );
    }
    final draft = record.draft;
    final attachment = record.attachment;
    return Scaffold(
      appBar: AppBar(
        title: Text(draft.kind.label),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          EditRecordPage(kind: draft.kind, record: record),
                    ),
                  ),
            child: const Text('Edit'),
          ),
        ],
      ),
      body: DrawerPage(
        children: [
          Text(
            record.isArchived ? 'ARCHIVED' : draft.kind.label.toUpperCase(),
            style: monoLabel(colors.marker),
          ),
          const SizedBox(height: 8),
          Text(draft.title, style: displayStyle(colors.text, 42)),
          const SizedBox(height: 19),
          PaperPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ON RECORD', style: monoLabel(colors.marker)),
                const SizedBox(height: 13),
                DashedRule(colors.line),
                const SizedBox(height: 9),
                if (draft.source.isNotEmpty)
                  _Field(draft.kind.sourceLabel, draft.source),
                if (draft.recordedOn != null)
                  _Field(
                    draft.kind == RecordKind.receipt ? 'Purchased' : 'Issued',
                    displayDate(draft.recordedOn!),
                  ),
                if (draft.amountCents != null)
                  _Field('Amount', displayAmount(draft.amountCents!)),
                _Field(
                  draft.kind.deadlineLabel,
                  draft.deadline == null
                      ? 'No date'
                      : displayDate(draft.deadline!),
                ),
                if (draft.notes.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  DashedRule(colors.line),
                  const SizedBox(height: 13),
                  SelectableText(draft.notes),
                ],
              ],
            ),
          ),
          if (attachment != null) ...[
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: () => _openAttachment(context, attachment),
              icon: const Icon(Icons.attach_file, size: 19),
              label: Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : () => _archive(vault, record),
              icon: Icon(
                record.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              label: Text(
                record.isArchived ? 'Restore to vault' : 'Archive item',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(
    BuildContext context,
    VaultAttachment attachment,
  ) async {
    if (p.extension(attachment.path).toLowerCase() != '.pdf') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(attachment.name)),
            body: Center(
              child: InteractiveViewer(
                child: Image.file(
                  File(attachment.path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('This photo couldn’t be displayed.'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    var opened = false;
    try {
      opened =
          (await OpenFilex.open(
            attachment.path,
            type: 'application/pdf',
          )).type ==
          ResultType.done;
    } catch (_) {
      // The platform viewer can be unavailable.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Couldn’t open this PDF.')));
    }
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: context.palette.muted)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}
