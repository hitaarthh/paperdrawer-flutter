import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/type.dart';

/// Intro step 3 art: a sample warranty-repair claim on its escalation ladder.
///
/// Drawn on the 390×360 intro art canvas with the mockup's coordinates
/// (iOS Intro 3 · Claim). It is a picture, so text never follows Dynamic
/// Type; the intro flow scales the whole canvas instead.
class ClaimArt extends StatelessWidget {
  const ClaimArt({super.key});

  /// CSS `line-height: normal` for the bundled faces (ascent + descent).
  static const _interNormal = 1.21;
  static const _monoNormal = 1.32;

  @override
  Widget build(BuildContext context) {
    final kicker = PdType.label.copyWith(
      fontSize: 10,
      height: _monoNormal,
      letterSpacing: 10 * 0.1,
    );
    final title = PdType.bodyStrong.copyWith(height: _interNormal);
    final detail = PdType.footnote.copyWith(color: Pd.textMuted, height: 1.45);
    return MediaQuery.withNoTextScaling(
      child: Stack(
        children: [
          Positioned(
            left: Pd.s5,
            right: Pd.s5,
            top: Pd.s2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Pd.surface2,
                borderRadius: BorderRadius.circular(Pd.rSm),
                border: Border.all(color: Pd.hairline),
              ),
              child: Padding(
                // 16 18 6, plus the 1px border DecoratedBox doesn't inset.
                padding: const EdgeInsets.fromLTRB(19, 17, 19, 7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: Pd.s2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'WARRANTY REPAIR · LAPTOP',
                            style: PdType.label.copyWith(color: Pd.textMuted),
                          ),
                          Text(
                            'DAY 14',
                            style: PdType.label.copyWith(color: Pd.signal),
                          ),
                        ],
                      ),
                    ),
                    _Rung(
                      number: '01',
                      fill: Pd.signal,
                      children: [
                        Text(
                          'NO REPLY · 14 DAYS',
                          style: kicker.copyWith(color: Pd.signal),
                        ),
                        Text('Brand support', style: title),
                      ],
                    ),
                    _Rung(
                      number: '02',
                      fill: Pd.lime,
                      children: [
                        Text(
                          'RECOMMENDED NEXT',
                          style: kicker.copyWith(color: Pd.lime),
                        ),
                        Text('Grievance officer', style: title),
                      ],
                    ),
                    _Rung(
                      number: '03',
                      children: [
                        Text('National Consumer Helpline', style: title),
                        Text(
                          'Call 1915 or file at consumerhelpline.gov.in',
                          style: detail,
                        ),
                      ],
                    ),
                    _Rung(
                      number: '04',
                      children: [
                        Text('Consumer commission', style: title),
                        Text('File online at e-Jagriti', style: detail),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One ladder step: a numbered dot beside its copy, under a hairline.
/// [fill] null draws the upcoming-step outline dot.
class _Rung extends StatelessWidget {
  const _Rung({required this.number, required this.children, this.fill});

  static const _dot = 28.0;

  final String number;
  final Color? fill;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Pd.hairline)),
    ),
    child: Padding(
      // 12px vertical padding, below the 1px top border.
      padding: const EdgeInsets.only(top: 1 + Pd.s3, bottom: Pd.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Container(
            width: _dot,
            height: _dot,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: fill == null
                  ? Border.all(color: Pd.line, width: 2)
                  : null,
            ),
            child: Text(
              number,
              style: PdType.dataStrong.copyWith(
                fontSize: 12,
                height: 1,
                color: fill == null ? Pd.textMuted : Pd.onLime,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}
