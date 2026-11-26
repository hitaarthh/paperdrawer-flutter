import 'package:flutter/widgets.dart';

import '../theme/pd_metrics.dart';

/// Caps a reading column at `content-max` (680 pt) and centres it.
final class PdContentWidth extends StatelessWidget {
  const PdContentWidth({
    required this.child,
    this.maxWidth = PdSize.contentMax,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// The sliver version of [PdContentWidth], for `CustomScrollView`s.
final class PdSliverContentWidth extends StatelessWidget {
  const PdSliverContentWidth({
    required this.sliver,
    this.maxWidth = PdSize.contentMax,
    super.key,
  });

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SliverConstrainedCrossAxis(
    maxExtent: maxWidth,
    sliver: sliver,
  );
}
