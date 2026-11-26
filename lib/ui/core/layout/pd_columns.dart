import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/pd_metrics.dart';
import 'pd_breakpoints.dart';

/// How many columns a list of cards gets in [width]: one under 600 pt, then
/// as many [minColumnWidth] columns as fit, up to [maxColumns] (two on iPad,
/// three on wide Mac windows).
int pdColumnCount(
  double width, {
  int maxColumns = 3,
  double minColumnWidth = 300,
  double gap = PdSpace.s3,
}) {
  if (PdBreakpoints.classify(width) == PdWidthClass.compact) return 1;
  final fit = ((width + gap) / (minColumnWidth + gap)).floor();
  return math.max(1, math.min(maxColumns, fit));
}

/// Lays [children] out in rows of [pdColumnCount] columns with [gap]
/// between them, top-aligned (cards keep their own heights). One column
/// under 600 pt. Uses the width it is given, not the window's.
final class PdColumns extends StatelessWidget {
  const PdColumns({
    required this.children,
    this.maxColumns = 3,
    this.minColumnWidth = 300,
    this.gap = PdSpace.s3,
    super.key,
  });

  final List<Widget> children;
  final int maxColumns;
  final double minColumnWidth;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = pdColumnCount(
        constraints.maxWidth,
        maxColumns: maxColumns,
        minColumnWidth: minColumnWidth,
        gap: gap,
      );
      final rows = (children.length / columns).ceil();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < rows; row++) ...[
            if (row > 0) SizedBox(height: gap),
            _PdColumnsRow(
              children: children,
              row: row,
              columns: columns,
              gap: gap,
            ),
          ],
        ],
      );
    },
  );
}

/// The sliver version of [PdColumns] for long lists: builds rows lazily.
final class PdSliverColumns extends StatelessWidget {
  const PdSliverColumns({
    required this.itemCount,
    required this.itemBuilder,
    this.maxColumns = 3,
    this.minColumnWidth = 300,
    this.gap = PdSpace.s3,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int maxColumns;
  final double minColumnWidth;
  final double gap;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final columns = pdColumnCount(
        constraints.crossAxisExtent,
        maxColumns: maxColumns,
        minColumnWidth: minColumnWidth,
        gap: gap,
      );
      final rows = (itemCount / columns).ceil();
      return SliverList.separated(
        itemCount: rows,
        separatorBuilder: (_, _) => SizedBox(height: gap),
        itemBuilder: (context, row) => _PdColumnsRow(
          children: [
            for (
              var i = row * columns;
              i < math.min(itemCount, (row + 1) * columns);
              i++
            )
              itemBuilder(context, i),
          ],
          row: 0,
          columns: columns,
          gap: gap,
        ),
      );
    },
  );
}

final class _PdColumnsRow extends StatelessWidget {
  const _PdColumnsRow({
    required this.children,
    required this.row,
    required this.columns,
    required this.gap,
  });

  final List<Widget> children;
  final int row;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (columns == 1) return children[row];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var column = 0; column < columns; column++) ...[
          if (column > 0) SizedBox(width: gap),
          Expanded(
            child: row * columns + column < children.length
                ? children[row * columns + column]
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}
