import 'package:flutter/widgets.dart';

import '../theme/pd_dynamic_type.dart';
import '../theme/pd_metrics.dart';
import '../theme/pd_theme.dart';
import 'pd_glass.dart';
import 'pd_pressable.dart';

/// The slim glass strip above the tab bar with the single most urgent
/// deadline: a `signal` dot, the text and the count. Tap opens the item.
///
/// The caller decides whether it shows (due within 7 days, never on Home,
/// never an "all good" state) and writes the copy: [text]
/// ("Boat earbuds · return closes Fri"), [count] ("2 DAYS", "TODAY") and
/// [semanticLabel] ("Boat earbuds, return window closes Friday, 2 days
/// left").
final class DeadlineAccessory extends StatelessWidget {
  const DeadlineAccessory({
    required this.text,
    required this.count,
    required this.semanticLabel,
    required this.onPressed,
    this.height = PdSize.accessoryHeight,
    super.key = const ValueKey('deadline-accessory'),
  });

  final String text;
  final String count;
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// [PdSize.accessoryHeight]; [PdSize.tabBarMin] inline in a minimised bar.
  final double height;

  @override
  Widget build(BuildContext context) {
    final pd = context.pd;
    return PdDynamicType.chrome(
      child: PdPressable(
        semanticLabel: semanticLabel,
        onPressed: onPressed,
        minSize: Size(PdSize.tapMin, height),
        child: PdGlass(
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: PdSpace.s4,
                end: PdSpace.s2,
              ),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: PdSize.signalDot,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pd.colors.signal,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: PdSpace.s2),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: pd.type.subhead.copyWith(color: pd.colors.text),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PdSpace.s2,
                    ),
                    child: Text(
                      count,
                      maxLines: 1,
                      style: pd.type.status.copyWith(
                        color: pd.colors.signalSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
