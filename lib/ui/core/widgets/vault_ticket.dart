import 'package:cupertino_ui/cupertino_ui.dart';

import '../theme/tokens.dart';
import '../theme/type.dart';
import 'paper.dart';

/// Ticket stock: signal for the soonest deadline, paper for the rest, lime
/// for a claim that is ready to escalate.
enum VaultTicketTone { signal, paper, lime }

/// A "Due next" ticket from the vault: a stub with the number of days, a
/// dashed perforation, then a kicker, title and one line of guidance. Notched
/// on both sides like a torn-off ticket.
class VaultTicket extends StatelessWidget {
  const VaultTicket({
    required this.number,
    required this.kicker,
    required this.title,
    required this.body,
    required this.tone,
    required this.semanticLabel,
    this.onTap,
    this.unit,
    this.onLongPress,
    this.onDismiss,
    super.key,
  });

  /// "02", or a word such as "TODAY".
  final String number;

  /// "DAYS" under the number.
  final String? unit;
  final String kicker;
  final String title;
  final String body;
  final VaultTicketTone tone;
  final String semanticLabel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// VoiceOver's dismiss action.
  final VoidCallback? onDismiss;

  static const _stub = Pd.s12 * 2;

  @override
  Widget build(BuildContext context) {
    final (fill, kickerInk, perforation) = switch (tone) {
      VaultTicketTone.signal => (Pd.signal, Pd.ink, 0.35),
      VaultTicketTone.paper => (Pd.paper, Pd.dueInk, 0.25),
      VaultTicketTone.lime => (Pd.lime, Pd.ink, 0.3),
    };
    final numeric = unit != null;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      onDismiss: onDismiss,
      excludeSemantics: true,
      child: CupertinoButton(
        onPressed: onTap,
        onLongPress: onLongPress,
        padding: EdgeInsets.zero,
        pressedOpacity: 0.7,
        focusColor: Pd.text,
        minimumSize: Size.zero,
        child: RepaintBoundary(
          child: NotchedTicketPaper(
            fill: fill,
            perforationAlpha: perforation,
            stubWidth: _stub,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: Pd.s12 * 2 + Pd.s5),
              child: Row(
                children: [
                  SizedBox(
                    width: _stub,
                    child: Padding(
                      padding: const EdgeInsets.all(Pd.s3),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              number,
                              maxLines: 1,
                              style:
                                  (numeric
                                          ? PdType.ticketNumber
                                          : PdType.title2)
                                      .copyWith(color: Pd.ink),
                            ),
                          ),
                          if (unit != null)
                            Text(
                              unit!,
                              textAlign: TextAlign.center,
                              style: PdType.label.copyWith(color: Pd.ink),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Pd.s4,
                        Pd.s3,
                        Pd.s4,
                        Pd.s3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        spacing: Pd.s1,
                        children: [
                          Text(
                            kicker,
                            style: PdType.label.copyWith(color: kickerInk),
                          ),
                          Text(
                            title,
                            style: PdType.cardTitle.copyWith(color: Pd.ink),
                          ),
                          Text(
                            body,
                            style: PdType.footnote.copyWith(
                              color: Pd.ink2,
                              fontWeight: FontWeight.w500,
                              fontVariations: const [FontVariation.weight(500)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
