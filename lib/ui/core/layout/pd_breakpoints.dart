import 'package:flutter/widgets.dart';

import '../theme/pd_metrics.dart';

/// Width classes. Layout follows the width the app gets, not the device
/// (iPad split view, Mac windows, iPhone Duo open/closed).
enum PdWidthClass {
  /// Under 600 pt: one column, floating tab bar.
  compact,

  /// 600 pt and up: sidebar, two or three columns.
  regular;

  /// `space-5` on compact, `space-8` on regular.
  double get screenMargin => switch (this) {
    PdWidthClass.compact => PdSpace.marginCompact,
    PdWidthClass.regular => PdSpace.marginRegular,
  };
}

abstract final class PdBreakpoints {
  /// The first regular width.
  static const double regular = 600;

  static PdWidthClass classify(double width) =>
      width >= regular ? PdWidthClass.regular : PdWidthClass.compact;

  /// The width class of the whole window.
  static PdWidthClass of(BuildContext context) =>
      classify(MediaQuery.sizeOf(context).width);
}
