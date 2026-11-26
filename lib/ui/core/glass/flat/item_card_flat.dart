import 'package:flutter/widgets.dart';

import '../../theme/pd_dynamic_type.dart';
import '../../theme/pd_metrics.dart';
import '../../theme/pd_theme.dart';
import 'data_row.dart';
import 'meter_flat.dart';
import 'paper.dart';
import 'status_label.dart';

/// A paper card for one thing in the vault, without decoration: meta
/// (`BILL · CROMA`) with one [StatusLabel] top right, the name in
/// `card-title`, data rows (the last `strong`), and the nearest window's
/// meter. The whole card is one button with one VoiceOver label.
///
/// At accessibility sizes the status drops below the meta and data rows
/// stack.
final class ItemCardFlat extends StatelessWidget {
  const ItemCardFlat({
    required this.meta,
    required this.title,
    required this.semanticLabel,
    this.status,
    this.rows = const [],
    this.meter,
    this.paper = PdPaperKind.bill,
    this.onPressed,
    this.onLongPress,
    super.key,
  });

  /// Caps meta: `BILL · CROMA`.
  final String meta;
  final String title;

  /// "Boat Airdopes 141, bill from Croma, due, return window 2 of 10 days
  /// left".
  final String semanticLabel;
  final StatusLabel? status;
  final List<PdDataRow> rows;
  final PdMeterFlat? meter;
  final PdPaperKind paper;
  final VoidCallback? onPressed;

  /// Opens the context menu (Open, Share, Delete).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    final metaText = Text(
      meta,
      style: pd.type.label.copyWith(color: pd.colors.inkMuted),
    );
    final status = this.status;
    final Widget header;
    if (status == null) {
      header = metaText;
    } else if (PdDynamicType.isAccessibilitySize(context)) {
      header = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          metaText,
          const SizedBox(height: PdSpace.s1),
          status,
        ],
      );
    } else {
      header = Row(
        children: [
          Expanded(child: metaText),
          const SizedBox(width: PdSpace.s3),
          Flexible(child: status),
        ],
      );
    }
    final meter = this.meter;
    return PdPaper(
      kind: paper,
      onPressed: onPressed,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          const SizedBox(height: PdSpace.s2 + PdSpace.s1 / 2),
          Text(title, style: pd.type.cardTitle.copyWith(color: pd.colors.ink)),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: PdSpace.s2 + PdSpace.s1 / 2),
            PdDataRows(rows: rows),
          ],
          if (meter != null) ...[
            const SizedBox(height: PdSpace.s2 + PdSpace.s1 / 2),
            meter,
          ],
        ],
      ),
    );
  }
}
