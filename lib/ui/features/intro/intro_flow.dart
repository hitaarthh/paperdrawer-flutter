import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/type.dart';
import '../../core/widgets/button.dart';
import '../../core/widgets/icons.dart';
import '../../core/widgets/paper.dart';
import 'art/claim_art.dart';
import 'art/keep_art.dart';
import 'art/remember_art.dart';

/// Size of the art slot in the intro mockups (iOS Intro 1–3). Every phase's
/// art is drawn on this canvas and scaled down to fit smaller screens.
const introArtSize = Size(390, 360);

/// Inactive step-dot colour from the intro mockups.
const _dotIdle = Color(0xFF3E4843);

class _Phase {
  const _Phase(this.kicker, this.title, this.body, this.art);

  final String kicker;
  final String title;
  final String body;
  final Widget art;
}

const _phases = [
  _Phase(
    '01 · KEEP',
    'Keep it.',
    'Snap a bill or upload a policy PDF. Paper Drawer reads the details and '
        'files the original.',
    KeepArt(),
  ),
  _Phase(
    '02 · REMEMBER',
    'Remember it.',
    'Return windows, warranty ends, policy renewals, PUC and service dates. '
        'A heads-up before each one, on your schedule.',
    RememberArt(),
  ),
  _Phase(
    '03 · CLAIM',
    'Claim it.',
    'Something broke, or a refund never came? Open a claim, log every call, '
        'and choose when to follow up.',
    ClaimArt(),
  ),
];

/// Three-step welcome: Keep, Remember, Claim.
///
/// [onStart] runs from SKIP and from the last step's "Start your vault".
/// [onSignIn] runs from "I already have an account"; leave it null where
/// there are no accounts and the link is hidden.
class IntroFlow extends StatefulWidget {
  const IntroFlow({required this.onStart, this.onSignIn, super.key});

  final VoidCallback onStart;
  final VoidCallback? onSignIn;

  @override
  State<IntroFlow> createState() => _IntroFlowState();
}

class _IntroFlowState extends State<IntroFlow> {
  final _pages = PageController();
  int _step = 0;

  bool get _last => _step == _phases.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) return widget.onStart();
    final target = _step + 1;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Pd.bg,
    child: CustomPaint(
      painter: const PaperGrain(),
      // Page swipes repaint above the grain, never the grain itself.
      child: RepaintBoundary(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Pd.maxContent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(onSkip: _last ? null : widget.onStart),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (step) => setState(() => _step = step),
                      children: [for (final phase in _phases) _Page(phase)],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Pd.margin,
                      Pd.s2,
                      Pd.margin,
                      Pd.s2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 10,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: Pd.s2),
                          child: _Dots(step: _step, count: _phases.length),
                        ),
                        PdButton.primary(
                          key: const ValueKey('intro-next'),
                          label: _last ? 'Start your vault' : 'Next',
                          icon: _last
                              ? null
                              : const Icon(LucideIcons.arrowRight),
                          expand: true,
                          onPressed: _next,
                        ),
                        if (widget.onSignIn case final onSignIn?)
                          _QuietLink(
                            key: const ValueKey('intro-sign-in'),
                            label: 'I already have an account',
                            onPressed: onSignIn,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onSkip});

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          const PaperDrawerMark(size: 21),
          const SizedBox(width: Pd.s2),
          Expanded(
            child: Text(
              'Paper Drawer',
              style: PdType.cardTitle.copyWith(letterSpacing: 20 * -0.03),
            ),
          ),
          if (onSkip case final onSkip?)
            CupertinoButton(
              key: const ValueKey('intro-skip'),
              onPressed: onSkip,
              padding: const EdgeInsets.symmetric(horizontal: Pd.s1),
              minimumSize: const Size(Pd.tapMin, 44),
              pressedOpacity: 0.7,
              focusColor: Pd.lime,
              child: Text(
                'SKIP',
                style: PdType.monoButton.copyWith(color: Pd.textMuted),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Page extends StatelessWidget {
  const _Page(this.phase);

  final _Phase phase;

  @override
  Widget build(BuildContext context) {
    final copy = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Pd.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: Pd.s3,
        children: [
          Text(phase.kicker, style: PdType.label.copyWith(color: Pd.lime)),
          Semantics(
            header: true,
            child: Text(
              phase.title,
              style: PdType.largeTitle.copyWith(
                fontSize: 44,
                height: 0.95,
                letterSpacing: 44 * -0.05,
                fontVariations: const [
                  FontVariation.weight(700),
                  FontVariation.opticalSize(44),
                ],
              ),
            ),
          ),
          Text(
            phase.body,
            style: PdType.body.copyWith(color: Pd.textMuted, height: 1.5),
          ),
        ],
      ),
    );
    // The art is decoration; the copy carries the meaning.
    final art = ExcludeSemantics(
      child: FittedBox(
        child: SizedBox.fromSize(size: introArtSize, child: phase.art),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // At accessibility text sizes or on very short screens the copy
        // needs the room: the art shrinks to a fixed band and the page
        // scrolls instead of clipping.
        if (isLargeText(context) || constraints.maxHeight < 420) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Pd.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 180, child: art),
                const SizedBox(height: Pd.s5),
                copy,
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: Pd.s2),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: introArtSize.height),
                child: art,
              ),
            ),
            const SizedBox(height: 22),
            copy,
            const Spacer(),
          ],
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step ${step + 1} of $count',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: i == step ? 28 : 10,
            height: 4,
            decoration: BoxDecoration(
              color: i == step ? Pd.lime : _dotIdle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}

class _QuietLink extends StatelessWidget {
  const _QuietLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: onPressed,
    padding: const EdgeInsets.symmetric(horizontal: Pd.s2),
    minimumSize: const Size(Pd.tapMin, 44),
    pressedOpacity: 0.7,
    focusColor: Pd.lime,
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: PdType.callout.copyWith(color: Pd.textMuted),
    ),
  );
}
