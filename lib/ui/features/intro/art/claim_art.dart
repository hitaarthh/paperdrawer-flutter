import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/item_status.dart';
import '../../../../domain/models/ledger.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/type.dart';
import '../../../core/widgets/stamp.dart';
import '../../claims/claim_ledger_sections.dart';

/// A sample manual claim ledger drawn on the intro art canvas.
class ClaimArt extends StatelessWidget {
  const ClaimArt({super.key});

  static final _entries = [
    LedgerEntry(
      id: 'repair-call',
      date: DateTime.utc(2026, 11, 12),
      kind: LedgerKind.call,
      text: 'Support booked a repair visit.',
      reference: 'SR-4821',
    ),
    LedgerEntry(
      id: 'repair-email',
      date: DateTime.utc(2026, 11, 10),
      kind: LedgerKind.email,
      text: 'Sent the invoice and a photo of the hinge.',
    ),
  ];

  @override
  Widget build(BuildContext context) => MediaQuery.withNoTextScaling(
    child: DefaultTextStyle(
      style: PdType.body,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Pd.margin, Pd.s2, Pd.margin, 0),
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              alignment: Alignment.topCenter,
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: Pd.s3,
                  children: [
                    Row(
                      spacing: Pd.s2,
                      children: [
                        Expanded(
                          child: Text(
                            'Laptop hinge repair',
                            style: PdType.title2,
                          ),
                        ),
                        const PdStamp(StampKind.escalate, compactLabel: 'OPEN'),
                      ],
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Pd.surface2,
                        border: Border.all(color: Pd.hairline),
                        borderRadius: BorderRadius.circular(Pd.rSm),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Pd.s3),
                        child: Row(
                          spacing: Pd.s2,
                          children: [
                            const Icon(
                              LucideIcons.bell,
                              color: Pd.lime,
                              size: Pd.iconSm,
                            ),
                            Text(
                              'FOLLOW UP SAT 21 NOV',
                              style: PdType.label.copyWith(color: Pd.lime),
                            ),
                          ],
                        ),
                      ),
                    ),
                    LedgerPaper(_entries),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
