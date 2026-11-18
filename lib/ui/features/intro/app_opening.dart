import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/paper.dart';
import '../../core/widgets/stamp.dart';

/// Plays the opening artwork alongside either app bootstrap.
class AppOpening<T extends Object> extends StatefulWidget {
  const AppOpening({
    required this.opening,
    required this.appBuilder,
    required this.errorBuilder,
    super.key,
  });

  final Future<T> opening;
  final Widget Function(T) appBuilder;
  final Widget Function(Object) errorBuilder;

  @override
  State<AppOpening<T>> createState() => _AppOpeningState<T>();
}

class _AppOpeningState<T extends Object> extends State<AppOpening<T>>
    with SingleTickerProviderStateMixin {
  static const _artworkKey = ValueKey('opening-artwork');
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..addStatusListener(_onRevealStatus);
  bool _revealComplete = false;
  bool _reduceMotion = false;

  void _onRevealStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _revealComplete = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _reveal.stop();
      _revealComplete = true;
    } else if (!_revealComplete && !_reveal.isAnimating) {
      _reveal.forward();
    }
  }

  @override
  void didUpdateWidget(AppOpening<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opening != widget.opening) {
      _reveal.stop();
      _revealComplete = true;
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  static Widget _transition(Widget child, Animation<double> animation) =>
      child.key == _artworkKey
      ? FadeTransition(opacity: animation, child: child)
      : child;

  static Widget _stack(Widget? current, List<Widget> previous) => Stack(
    alignment: Alignment.topLeft,
    fit: StackFit.expand,
    children: [
      ?current,
      for (final child in previous)
        IgnorePointer(child: ExcludeSemantics(child: child)),
    ],
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: widget.opening,
    builder: (context, snapshot) {
      final completed = snapshot.connectionState == ConnectionState.done;
      if (completed && snapshot.hasError) {
        return widget.errorBuilder(snapshot.error!);
      }
      final opened = completed ? snapshot.data : null;
      return AnimatedSwitcher(
        duration: _reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 160),
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: _transition,
        layoutBuilder: _stack,
        child: opened != null && _revealComplete
            ? KeyedSubtree(
                key: const ValueKey('opening-content'),
                child: widget.appBuilder(opened),
              )
            : _OpeningArtwork(
                key: _artworkKey,
                progress: _revealComplete
                    ? const AlwaysStoppedAnimation(1.0)
                    : _reveal,
              ),
      );
    },
  );
}

class _OpeningArtwork extends StatelessWidget {
  const _OpeningArtwork({required this.progress, super.key});

  final Animation<double> progress;

  // Artboard coordinates and keyframes from the iOS opening reference.
  // The tagline finishes at 52% of the reference's six-second loop.
  static const _artboard = Size(390, 844);
  static const _markWidth = Pd.s8 * 2;
  static const _ticketWidth = 300.0;
  static const _ticketTop = 396.0;
  static const _stampTop = 380.0;
  static const _revealEnd = 0.52;
  static const _easeOut = Cubic(0, 0, 0.58, 1);
  static const _mark = Interval(0.06, 0.18, curve: Cubic(0.2, 0.8, 0.2, 1));
  static const _wordmark = Interval(0.12, 0.22, curve: _easeOut);
  static const _ticket = Interval(0.22, 0.36, curve: Cubic(0.3, 0.7, 0.2, 1));
  static const _stamp = Interval(0.37, 0.42, curve: Cubic(0.3, 1.4, 0.5, 1));
  static const _stampSettle = Interval(
    0.42,
    0.45,
    curve: Cubic(0.3, 1.4, 0.5, 1),
  );
  static const _tagline = Interval(0.44, _revealEnd, curve: _easeOut);

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: 2);
    final wordmarkSize = PdType.openingWordmark.fontSize!;
    final ticketShift = math.max(
      0.0,
      textScaler.scale(wordmarkSize) - wordmarkSize,
    );
    return Semantics(
      label: 'PaperDrawer is opening',
      excludeSemantics: true,
      child: ColoredBox(
        color: Pd.bg,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(child: CustomPaint(painter: PaperGrain())),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox.fromSize(
                size: _artboard,
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: DefaultTextStyle(
                    style: PdType.body,
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 2,
                      child: AnimatedBuilder(
                        animation: progress,
                        builder: (context, _) =>
                            _frame(progress.value * _revealEnd, ticketShift),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _frame(double time, double ticketShift) {
    final mark = _mark.transform(time);
    final wordmark = _wordmark.transform(time);
    final stamp = _stamp.transform(time);
    final stampSettle = _stampSettle.transform(time);
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 230 + 156 * (1 - mark),
          child: const PaperDrawerMark(size: _markWidth),
        ),
        Positioned(
          top: 326 + 14 * (1 - wordmark),
          left: Pd.margin,
          right: Pd.margin,
          child: Opacity(
            opacity: wordmark,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'PaperDrawer',
                maxLines: 1,
                softWrap: false,
                style: PdType.openingWordmark,
              ),
            ),
          ),
        ),
        Positioned(
          top: _ticketTop + ticketShift,
          width: _ticketWidth,
          child: ClipRect(
            clipper: _TicketReveal(_ticket.transform(time)),
            child: const RepaintBoundary(child: _OpeningTicket()),
          ),
        ),
        Positioned(
          top: _stampTop + ticketShift,
          left: 252,
          child: Opacity(
            opacity: stamp.clamp(0.0, 1.0),
            child: Transform.rotate(
              // The reference's stamp has a permanent -10° tilt.
              angle: (-24 + 4 * stamp) * math.pi / 180,
              child: Transform.scale(
                scale: 1.9 - 0.96 * stamp + 0.06 * stampSettle,
                child: const PdFiledStamp(
                  paperOpacity: 0.6,
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 92,
          left: Pd.margin,
          right: Pd.margin,
          child: Opacity(
            opacity: _tagline.transform(time),
            child: Text(
              'KEEP IT · REMEMBER IT · CLAIM IT',
              textAlign: TextAlign.center,
              style: PdType.openingTagline.copyWith(color: Pd.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketReveal extends CustomClipper<Rect> {
  const _TicketReveal(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * fraction);

  @override
  bool shouldReclip(_TicketReveal oldClipper) =>
      oldClipper.fraction != fraction;
}

class _OpeningTicket extends StatelessWidget {
  const _OpeningTicket();

  static const _stubWidth = 76.0;
  static const _minHeight = 104.0;
  static const _contentInset = 14.0;
  static const _lineGap = 6.0;

  @override
  Widget build(BuildContext context) => NotchedTicketPaper(
    stubWidth: _stubWidth - 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _minHeight),
      child: Row(
        children: [
          SizedBox(
            width: _stubWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Pd.s2),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    'ADMIT ONE',
                    style: PdType.compactStamp.copyWith(color: Pd.ink),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Pd.s4,
                vertical: _contentInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: _lineGap,
                children: [
                  Text(
                    'NO. 000001',
                    style: PdType.openingTicketNumber.copyWith(
                      color: Pd.inkMuted,
                    ),
                  ),
                  Text(
                    'Never lose a claim to a missing bill.',
                    style: PdType.openingTicketTitle.copyWith(color: Pd.ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
