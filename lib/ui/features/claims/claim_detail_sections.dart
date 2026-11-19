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
  const ClaimDraftCard({required this.message, super.key});

  final ClaimMessage message;

  @override
  Widget build(BuildContext context) => DocumentPaper(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'DRAFTED FOR YOU',
          style: PdType.label.copyWith(color: Pd.inkMuted),
        ),
        const SizedBox(height: Pd.s3),
        _MessageProperty(label: 'TO', value: message.to),
        _MessageProperty(label: 'SUBJECT', value: message.subject),
        const SizedBox(height: Pd.s3),
        const SolidRule(),
        const SizedBox(height: Pd.s3),
        SelectableText(
          message.body,
          style: PdType.callout.copyWith(color: Pd.ink2),
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
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label  ',
          style: PdType.label.copyWith(color: Pd.inkMuted),
        ),
        TextSpan(
          text: value,
          style: label == 'TO'
              ? TextStyle(color: Pd.dueInk, backgroundColor: Pd.signalTint)
              : null,
        ),
      ],
    ),
    style: PdType.data.copyWith(color: Pd.ink2),
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
  const ClaimActivityLog({
    required this.events,
    required this.onUpdate,
    super.key,
  });

  final List<ClaimEvent> events;
  final VoidCallback? onUpdate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'CLAIM LOG',
                style: PdType.label.copyWith(color: Pd.textMuted),
              ),
            ),
          ),
          Flexible(
            child: PdButton.text(
              key: const ValueKey('claim-log-update'),
              label: 'Log an update',
              monospaced: true,
              onPressed: onUpdate,
            ),
          ),
        ],
      ),
      if (events.isEmpty)
        Text(
          'Your updates will appear here.',
          style: PdType.footnote.copyWith(color: Pd.textMuted),
        ),
      for (final event in events) _ClaimLogEntry(event),
    ],
  );
}

class _ClaimLogEntry extends StatelessWidget {
  const _ClaimLogEntry(this.event);

  final ClaimEvent event;

  @override
  Widget build(BuildContext context) {
    final (label, title) = switch (event.kind) {
      ClaimEventKind.opened => ('CLAIM', 'Claim opened'),
      ClaimEventKind.sent => ('SENT', event.text),
      ClaimEventKind.reply => ('REPLY', 'Reply received'),
      ClaimEventKind.step => ('STEP', 'Moved to ${event.text}'),
      ClaimEventKind.note => ('NOTE', 'Note added'),
      ClaimEventKind.settled => ('CLAIM', 'Claim settled'),
      ClaimEventKind.reopened => ('CLAIM', 'Claim reopened'),
      ClaimEventKind.call ||
      ClaimEventKind.email ||
      ClaimEventKind.visit ||
      ClaimEventKind.refund => (
        event.kind.ledgerKind.label.toUpperCase(),
        event.text,
      ),
    };
    final detail = switch (event.kind) {
      ClaimEventKind.reply ||
      ClaimEventKind.note ||
      ClaimEventKind.settled when event.text != title => event.text,
      _ => null,
    };
    return Column(
      children: [
        const SolidRule(color: Pd.hairline),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Pd.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Pd.s3,
            children: [
              SizedBox(
                width: Pd.s12 + Pd.s3,
                child: Text(
                  shortDate(event.on).toUpperCase(),
                  style: PdType.label.copyWith(color: Pd.textMuted),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: PdType.label.copyWith(
                        color: event.kind == ClaimEventKind.step
                            ? Pd.lime
                            : Pd.textMuted,
                      ),
                    ),
                    Text(title, style: PdType.bodyStrong),
                    if (detail != null)
                      Text(
                        detail,
                        style: PdType.footnote.copyWith(color: Pd.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
              : () => Navigator.of(context).pop(_note.text.trim()),
        ),
      ),
    ],
  );
}
