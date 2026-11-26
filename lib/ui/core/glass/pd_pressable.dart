import 'package:flutter/services.dart' show MouseCursor, SystemMouseCursors;
import 'package:flutter/widgets.dart';

import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';

/// Which focus ring colour a control uses.
enum PdFocusGround {
  /// On the room or glass: `focus-ring` (lime, olive in light).
  room,

  /// On paper: `focus-ring-paper`.
  paper,
}

/// The one tappable building block of the kit: one semantics node with a
/// label, a hit area of at least 44 pt, keyboard/Switch Control activation
/// with a 2 pt focus ring 2 pt outside, and press feedback
/// (`pressed-scale`, none with Reduce Motion).
///
/// The child is drawn as is; its own semantics are replaced by
/// [semanticLabel].
final class PdPressable extends StatefulWidget {
  const PdPressable({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.selected,
    this.semanticHint,
    this.isButton = true,
    this.inMutuallyExclusiveGroup = false,
    this.minSize = const Size.square(PdSize.tapMin),
    this.pressedScale = PdEffects.pressedScale,
    this.focusRadius = PdRadius.pill,
    this.focusGround = PdFocusGround.room,
    this.pressedShadow,
    this.onFocusChange,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget child;
  final bool? selected;
  final String? semanticHint;
  final bool isButton;
  final bool inMutuallyExclusiveGroup;
  final Size minSize;

  /// 1 turns scaling off (tabs, rows).
  final double pressedScale;
  final double focusRadius;
  final PdFocusGround focusGround;

  /// Shadow while pressed (paper cards: `shadow-paper-pressed`).
  final List<BoxShadow>? pressedShadow;

  /// Accessibility focus moved onto or off this control (VoiceOver).
  final ValueChanged<bool>? onFocusChange;

  @override
  State<PdPressable> createState() => _PdPressableState();
}

final class _PdPressableState extends State<PdPressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pd.colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = _pressed && !reduceMotion ? widget.pressedScale : 1.0;
    final ring = switch (widget.focusGround) {
      PdFocusGround.room => colors.focusRing,
      PdFocusGround.paper => colors.focusRingPaper,
    };
    Widget visual = widget.child;
    final shadow = widget.pressedShadow;
    if (shadow != null) {
      visual = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.focusRadius),
          boxShadow: _pressed ? shadow : const [],
        ),
        child: visual,
      );
    }
    visual = CustomPaint(
      foregroundPainter: _focused
          ? _FocusRingPainter(color: ring, radius: widget.focusRadius)
          : null,
      child: AnimatedScale(
        scale: scale,
        duration: reduceMotion ? Duration.zero : PdMotion.press,
        child: visual,
      ),
    );
    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      inMutuallyExclusiveGroup: widget.inMutuallyExclusiveGroup,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      onDidGainAccessibilityFocus: widget.onFocusChange == null
          ? null
          : () => widget.onFocusChange?.call(true),
      onDidLoseAccessibilityFocus: widget.onFocusChange == null
          ? null
          : () => widget.onFocusChange?.call(false),
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: widget.onPressed,
          onLongPress: widget.onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.minSize.width,
              minHeight: widget.minSize.height,
            ),
            child: visual,
          ),
        ),
      ),
    );
  }
}

final class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  /// 2 pt offset plus half the 2 pt stroke.
  static const double _outset = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(_outset);
    final r = radius.clamp(0, rect.shortestSide / 2).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(r + _outset)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
