import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/item_status.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';

/// The decorative FILED stamp used in PaperDrawer's brand artwork.
class PdFiledStamp extends StatelessWidget {
  const PdFiledStamp({
    this.paperOpacity = 0.55,
    this.padding = const EdgeInsets.symmetric(horizontal: Pd.s2, vertical: 3),
    super.key,
  });

  final double paperOpacity;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Pd.paper.withValues(alpha: paperOpacity),
      border: Border.all(color: Pd.stampCovered, width: 2),
      borderRadius: BorderRadius.circular(Pd.rXs),
    ),
    child: Padding(
      padding: padding,
      child: Text(
        'FILED',
        softWrap: false,
        style: PdType.stamp.copyWith(color: Pd.stampCovered),
      ),
    ),
  );
}

class PdStamp extends StatefulWidget {
  const PdStamp(
    this.kind, {
    this.label,
    this.angleDegrees = -12,
    this.land = false,
    this.onLanded,
    super.key,
  });

  final StampKind kind;
  final String? label;
  final double angleDegrees;
  final bool land;
  final VoidCallback? onLanded;

  @override
  State<PdStamp> createState() => _PdStampState();
}

class _PdStampState extends State<PdStamp> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Pd.stampDuration,
    value: 1,
  )..addStatusListener(_onStatus);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onLanded?.call();
  }

  void _scheduleLanding() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.land) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        widget.onLanded?.call();
        return;
      }
      HapticFeedback.lightImpact();
      _controller.forward(from: 0);
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.land) _scheduleLanding();
  }

  @override
  void didUpdateWidget(PdStamp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.land && (!oldWidget.land || oldWidget.kind != widget.kind)) {
      _scheduleLanding();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.kind) {
      StampKind.due => Pd.stampDue,
      StampKind.covered || StampKind.active => Pd.stampCovered,
      StampKind.expired => Pd.stampExpired,
    };
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: widget.angleDegrees * math.pi / 180,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
            scale:
                1 +
                0.15 * (1 - Curves.easeOutCubic.transform(_controller.value)),
            child: child,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(Pd.rXs),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Pd.s2,
                vertical: Pd.s1,
              ),
              child: Text(
                widget.label ?? widget.kind.word,
                textAlign: TextAlign.center,
                style: PdType.stamp.copyWith(color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
