import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../theme/pd_dynamic_type.dart';
import '../../theme/pd_metrics.dart';
import '../../theme/pd_theme.dart';

/// One data row on paper: `BOUGHT` · `17.11.2026`.
@immutable
final class PdDataRow {
  const PdDataRow(this.label, this.value, {this.strong = false});

  /// Caps label.
  final String label;

  /// Formatted value (dates `10.11.2026`, money `₹4,20,000`).
  final String value;

  /// The one value the card is about (total, IDV): `data-strong`.
  final bool strong;

  @override
  bool operator ==(Object other) =>
      other is PdDataRow &&
      other.label == label &&
      other.value == value &&
      other.strong == strong;

  @override
  int get hashCode => Object.hash(label, value, strong);
}

/// Data rows on paper with `paper-rule` hairlines between them. At
/// accessibility sizes each label sits above its value.
final class PdDataRows extends StatelessWidget {
  const PdDataRows({required this.rows, super.key});

  final List<PdDataRow> rows;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    final stacked = PdDynamicType.isAccessibilitySize(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: pd.colors.paperRule)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PdSpace.s1 + PdSpace.s1 / 2),
              child: MergeSemantics(child: _row(context, row, stacked)),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, PdDataRow row, bool stacked) {
    final pd = context.pd;
    final label = Text(
      row.label,
      style: pd.type.data.copyWith(color: pd.colors.inkMuted),
    );
    final value = Text(
      row.value,
      textAlign: stacked ? TextAlign.start : TextAlign.end,
      style: (row.strong ? pd.type.dataStrong : pd.type.data).copyWith(
        color: row.strong ? pd.colors.ink2 : pd.colors.inkMuted,
      ),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [label, value],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: label),
        const SizedBox(width: PdSpace.s3),
        Expanded(child: value),
      ],
    );
  }
}
