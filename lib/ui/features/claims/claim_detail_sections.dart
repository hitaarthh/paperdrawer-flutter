import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../domain/claim_message.dart';
import '../../../domain/formats.dart';
import '../../../domain/models/claim.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/paper.dart';
import '../../core/widgets/text_field.dart';

class ClaimDraftCard extends StatelessWidget {
  const ClaimDraftCard({
    required this.heading,
    required this.message,
    required this.onCopy,
    required this.onShare,
    required this.shareIcon,
    super.key,
  });

  final String heading;
  final ClaimMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;
  final Widget shareIcon;

  @override
  Widget build(BuildContext context) => DocumentPaper(
    padding: const EdgeInsets.all(Pd.s5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MESSAGE DRAFT', style: PdType.label.copyWith(color: Pd.inkMuted)),
        const SizedBox(height: Pd.s2),
        Text(heading, style: PdType.title2.copyWith(color: Pd.ink)),
        const SizedBox(height: Pd.s4),
        _MessageProperty(label: 'TO', value: message.to),
        const SizedBox(height: Pd.s2),
        _MessageProperty(label: 'SUBJECT', value: message.subject),
        const SizedBox(height: Pd.s3),
        const DashedRule(color: Pd.paperDash),
        const SizedBox(height: Pd.s3),
        SelectableText(
          message.body,
          style: PdType.callout.copyWith(color: Pd.ink2),
        ),
        const SizedBox(height: Pd.s4),
        Wrap(
          spacing: Pd.s2,
          runSpacing: Pd.s2,
          children: [
            PdButton.onPaper(
              key: const ValueKey('copy-claim-message'),
              label: 'Copy message',
              icon: const Icon(LucideIcons.copy, size: Pd.iconSm),
              onPressed: onCopy,
            ),
            PdButton.onPaper(
              key: const ValueKey('share-claim-message'),
              label: 'Share',
              icon: shareIcon,
              onPressed: onShare,
            ),
          ],
        ),
      ],
    ),
  );
}

class _MessageProperty extends StatelessWidget {
  const _MessageProperty({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: PdType.label.copyWith(color: Pd.inkMuted)),
      Text(value, style: PdType.data.copyWith(color: Pd.ink2)),
    ],
  );
}

class ClaimOutcome extends StatelessWidget {
  const ClaimOutcome({required this.claim, required this.days, super.key});

  final Claim claim;
  final int days;

  @override
  Widget build(BuildContext context) => DocumentPaper(
    padding: const EdgeInsets.all(Pd.s5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('OUTCOME', style: PdType.label.copyWith(color: Pd.inkMuted)),
        const SizedBox(height: Pd.s2),
        Text(
          'Settled in ${daysWord(days)}',
          style: PdType.title2.copyWith(color: Pd.ink),
        ),
        if (claim.settledOn case final settled?) ...[
          const SizedBox(height: Pd.s2),
          Text(
            longDate(settled),
            style: PdType.data.copyWith(color: Pd.inkMuted),
          ),
        ],
      ],
    ),
  );
}

class ClaimActivityLog extends StatelessWidget {
  const ClaimActivityLog({required this.events, super.key});

  final List<ClaimEvent> events;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(header: true, child: Text('Claim log', style: PdType.title2)),
      const SizedBox(height: Pd.s3),
      if (events.isEmpty)
        Text(
          'Your updates will appear here.',
          style: PdType.footnote.copyWith(color: Pd.textMuted),
        ),
      for (final event in events) ...[
        const DashedRule(color: Pd.line),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Pd.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monoDate(event.on),
                style: PdType.data.copyWith(color: Pd.textMuted),
              ),
              const SizedBox(height: Pd.s1),
              Text(event.text, style: PdType.callout),
            ],
          ),
        ),
      ],
    ],
  );
}

class ClaimNoteForm extends StatefulWidget {
  const ClaimNoteForm({
    required this.fieldLabel,
    required this.saveLabel,
    required this.requiredNote,
    super.key,
  });

  final String fieldLabel;
  final String saveLabel;
  final bool requiredNote;

  @override
  State<ClaimNoteForm> createState() => _ClaimNoteFormState();
}

class _ClaimNoteFormState extends State<ClaimNoteForm> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      PdTextField(
        label: widget.fieldLabel,
        controller: _note,
        fieldKey: const ValueKey('claim-log-text'),
        hint: widget.requiredNote ? 'Write a note' : 'Optional',
        maxLines: 3,
      ),
      const SizedBox(height: Pd.s4),
      ValueListenableBuilder(
        valueListenable: _note,
        builder: (context, value, _) => PdButton.primary(
          key: const ValueKey('save-claim-log'),
          label: widget.saveLabel,
          expand: true,
          onPressed: widget.requiredNote && value.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(value.text.trim()),
        ),
      ),
    ],
  );
}
