import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart' show XFile;

import '../../../data/services/ledger_pdf.dart';
import '../../../data/services/today.dart';
import '../../../domain/formats.dart';
import '../../../domain/models/item.dart';
import '../../../domain/models/ledger.dart';
import '../../../routing/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/nav.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/snackbar.dart';
import 'claim_detail_sections.dart';
import 'claim_ledger_sections.dart';
import 'ledger_entry_sheet.dart';

typedef LedgerFile = ({String name, Future<void> Function() open});

class ClaimLedgerScreen extends StatefulWidget {
  const ClaimLedgerScreen({
    required this.title,
    required this.itemLabel,
    required this.opened,
    required this.settled,
    required this.entries,
    required this.followUp,
    required this.clock,
    required this.files,
    required this.pickPhoto,
    required this.addEntry,
    required this.setFollowUp,
    required this.enableNotifications,
    required this.share,
    required this.settle,
    this.serial = '',
    this.busy = false,
    this.actions = const [],
    this.settleKey = 'mark-claim-settled',
    super.key,
  });

  final String title;
  final String itemLabel;
  final DateTime opened;
  final DateTime? settled;
  final List<LedgerEntry> entries;
  final DateTime? followUp;
  final Today clock;
  final List<LedgerFile> files;
  final String serial;
  final bool busy;
  final List<Widget> actions;
  final String settleKey;
  final Future<PendingFile?> Function() pickPhoto;
  final Future<void> Function(LedgerDraft) addEntry;
  final Future<void> Function(DateTime?) setFollowUp;
  final Future<bool> Function() enableNotifications;
  final Future<void> Function(XFile, Rect?) share;
  final Future<void> Function(String) settle;

  @override
  State<ClaimLedgerScreen> createState() => _ClaimLedgerScreenState();
}

enum _FollowUpAction { change, remove }

class _ClaimLedgerScreenState extends State<ClaimLedgerScreen> {
  bool _working = false;
  bool get _busy => _working || widget.busy;

  Future<void> _run(Future<void> Function() action, String fallback) async {
    if (_busy) return;
    setState(() => _working = true);
    try {
      await action();
    } on FormatException catch (error) {
      if (mounted) showPdSnackbar(context, error.message);
    } catch (_) {
      if (mounted) showPdSnackbar(context, fallback);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _confirmNotifications() async {
    final allowed = await widget.enableNotifications();
    if (!mounted || allowed) return;
    showPdSnackbar(context, 'Turn on notifications in Settings to get this reminder.');
  }

  Future<void> _add() async {
    final shouldNotify = await showLedgerEntrySheet(
      context,
      title: widget.title,
      number: widget.entries.length + 1,
      clock: widget.clock,
      pickPhoto: widget.pickPhoto,
      save: widget.addEntry,
    );
    if (!mounted || shouldNotify != true) return;
    await _confirmNotifications();
  }

  Future<void> _changeFollowUp() async {
    final existing = widget.followUp;
    if (existing != null) {
      final action = await showPdActions<_FollowUpAction>(
        context,
        title: 'Follow-up reminder',
        actions: const [
          PdAction(label: 'Change reminder', value: _FollowUpAction.change),
          PdAction(label: 'Remove reminder', value: _FollowUpAction.remove),
        ],
      );
      if (!mounted || action == null) return;
      if (action == _FollowUpAction.remove) {
        await _run(() => widget.setFollowUp(null), 'The reminder couldn’t be removed. Try again.');
        return;
      }
    }
    final date = await showPdFollowUpPicker(
      context,
      now: widget.clock.instant.toLocal(),
      initial: existing,
    );
    if (!mounted || date == null) return;
    await _run(() async {
      await widget.setFollowUp(date);
      if (!mounted) return;
      await _confirmNotifications();
    }, 'The reminder couldn’t be saved. Try again.');
  }

  Future<void> _markSettled() async {
    final note = await showPdSheet<String>(
      context,
      title: 'Mark settled',
      body: const ClaimNoteForm(
        fieldLabel: 'How was it resolved?',
        saveLabel: 'Mark settled',
        requiredNote: false,
      ),
    );
    if (!mounted || note == null) return;
    await _run(() async {
      await widget.settle(note);
      if (mounted) showPdSnackbar(context, 'Claim settled', success: true);
    }, 'The claim couldn’t be settled. Try again.');
  }

  void _sharePdf(BuildContext anchor) {
    final box = anchor.findRenderObject();
    final origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
    final share = widget.share;
    _run(() async {
      final pdf = await buildLedgerPdf(
        title: widget.title,
        opened: widget.opened,
        settled: widget.settled,
        entries: widget.entries,
        files: [for (final file in widget.files) file.name],
        serial: widget.serial,
      );
      if (!mounted) return;
      await share(pdf, origin);
    }, 'The ledger PDF couldn’t be shared. Try again.');
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.settled == null;
    final day = daysBetween(widget.opened, widget.settled ?? widget.clock.value).clamp(0, 1 << 30);
    final followUp = widget.followUp;
    return PdPushedScaffold(
      backLabel: 'HOME',
      backStyle: PdType.monoButton,
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.claims),
      kicker: [
        'CLAIM',
        if (widget.itemLabel.isNotEmpty) widget.itemLabel,
        'OPENED ${longDate(widget.opened)}',
      ].join(' · ').toUpperCase(),
      title: widget.title,
      titleStyle: PdType.trackerTitle,
      actions: widget.actions,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Pd.s6,
          children: [
            LedgerStatus(isOpen: open, day: day, entries: widget.entries),
            if (open) ...[
              LedgerReminder(
                value: followUp == null ? null : followUpLabel(followUp),
                onChange: _busy ? null : _changeFollowUp,
              ),
              PdButton.primary(
                key: const ValueKey('ledger-add-entry'),
                label: 'Add an entry',
                icon: const Icon(LucideIcons.plus),
                onPressed: _busy ? null : _add,
                expand: true,
              ),
            ],
            LedgerPaper(widget.entries),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Pd.s2,
              children: [
                Text('ON FILE FOR THIS CLAIM', style: PdType.label.copyWith(color: Pd.textMuted)),
                if (widget.files.isEmpty && widget.serial.isEmpty)
                  Text('No files attached.', style: PdType.footnote.copyWith(color: Pd.textMuted)),
                Wrap(
                  spacing: Pd.s2,
                  runSpacing: Pd.s2,
                  children: [
                    for (final (index, file) in widget.files.indexed)
                      PdButton.secondary(
                        key: ValueKey('ledger-file-$index'),
                        label: file.name,
                        icon: const Icon(LucideIcons.paperclip),
                        onPressed: _busy ? null : () => _run(file.open, 'The file couldn’t open. Try again.'),
                      ),
                    if (widget.serial.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: Pd.s3),
                        child: Text('SERIAL ${widget.serial}', style: PdType.monoButton),
                      ),
                  ],
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Pd.s2,
              children: [
                Expanded(
                  child: Builder(
                    builder: (anchor) => PdButton.secondary(
                      key: const ValueKey('ledger-share-pdf'),
                      label: 'Share as PDF',
                      onPressed: _busy ? null : () => _sharePdf(anchor),
                    ),
                  ),
                ),
                if (open)
                  Expanded(
                    child: PdButton.positive(
                      key: ValueKey(widget.settleKey),
                      label: 'Mark settled',
                      onPressed: _busy ? null : _markSettled,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class MissingLedger extends StatelessWidget {
  const MissingLedger({this.loading = false, super.key});

  final bool loading;

  @override
  Widget build(BuildContext context) => PdPushedScaffold(
    backLabel: 'HOME',
    title: 'Claim',
    onBack: () => context.canPop() ? context.pop() : context.go(Routes.claims),
    children: [
      if (loading)
        const Center(child: CircularProgressIndicator())
      else
        const DashedTile(
          title: 'This claim is unavailable',
          body: 'Go back to see the rest of your claims.',
        ),
    ],
  );
}
