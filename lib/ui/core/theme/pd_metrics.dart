import 'package:flutter/animation.dart' show Curve, Curves;
import 'package:flutter/painting.dart';

import 'pd_colors.dart';

/// Spacing tokens (`space-*` in tokens.json). The grid is 4 pt.
///
/// These are theme-independent, so they stay `static const`.
abstract final class PdSpace {
  /// Icon-to-label gap, status label vertical padding.
  static const double s1 = 4;

  /// Gap between glass controls; label-to-value.
  static const double s2 = 8;

  /// Gap between cards in a list; row inner gaps.
  static const double s3 = 12;

  /// Card padding; grouped-row horizontal padding.
  static const double s4 = 16;

  /// iPhone (compact width) screen margin.
  static const double s5 = 20;

  /// Gap between sections; sheet padding.
  static const double s6 = 24;

  /// Gap above a large title; iPad (regular width) screen margin.
  static const double s8 = 32;

  /// Empty-state breathing room.
  static const double s10 = 40;

  /// Bottom clearance under the last row (plus the measured bar inset).
  static const double s12 = 48;

  /// Screen margin under 600 pt.
  static const double marginCompact = s5;

  /// Screen margin at 600 pt and up.
  static const double marginRegular = s8;
}

/// Corner radius tokens (`radius-*`).
abstract final class PdRadius {
  /// Thumbnails of the original photo inside cards.
  static const double xs = 4;

  /// Inner elements inside a 14 pt card.
  static const double sm = 8;

  /// Paper cards, grouped lists, text fields (continuous corners).
  static const double md = 14;

  /// Glass panels, the iPad sidebar.
  static const double lg = 22;

  /// Sheet corners.
  static const double xl = 34;

  /// Capsules: buttons, tab bar, chips, StatusLabel, glass buttons.
  static const double pill = 999;

  /// A continuous (squircle) shape for paper and grouped lists, as iOS
  /// draws them.
  static RoundedSuperellipseBorder continuous(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => RoundedSuperellipseBorder(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        side: side,
      );
}

/// Size tokens (`size` group in tokens.json) plus sizes the component
/// READMEs state in prose.
abstract final class PdSize {
  /// Minimum hit area for anything tappable.
  static const double tapMin = 44;

  /// Buttons and text fields.
  static const double controlHeight = 50;

  /// Small buttons inside cards and toasts.
  static const double controlHeightSm = 36;

  /// Round glass toolbar buttons.
  static const double glassButton = 44;

  /// The glass tab bar and the Scan button beside it.
  static const double tabBarHeight = 62;

  /// Tab bar and Scan button when minimised on scroll.
  static const double tabBarMin = 48;

  /// Widest the tab bar row gets on iPhone (TabBar README).
  static const double tabBarMaxWidth = 440;

  /// DeadlineAccessory and Toast.
  static const double accessoryHeight = 44;

  /// Longest reading column.
  static const double contentMax = 680;

  /// iPad and Mac sidebar.
  static const double sidebarWidth = 320;

  /// Gap between the sidebar and the screen edges (HomeScreenIpad README).
  static const double sidebarInset = 12;

  /// Icons in bars and rows.
  static const double iconBar = 22;

  /// Icons inside buttons.
  static const double iconButton = 18;

  /// StatusLabel height.
  static const double statusLabel = 22;

  /// Meter bar thickness.
  static const double meter = 4;

  /// Grouped list row minimum height.
  static const double listRow = 52;

  /// The round close button in a sheet header (its hit area stays 44).
  static const double sheetClose = 36;

  /// The DeadlineCard number column.
  static const double deadlineNumberColumn = 64;

  /// The signal dot in the DeadlineAccessory.
  static const double signalDot = 8;

  /// The sheet grabber.
  static const Size grabber = Size(36, 5);
}

/// Effect tokens (`effect` group).
abstract final class PdEffects {
  /// Backdrop blur of fallback glass (CSS `blur(20px)` is a 20 px standard
  /// deviation, which is Flutter's sigma).
  static const double glassBlur = 20;

  /// Backdrop saturation of fallback glass (180%).
  static const double glassSaturate = 1.8;

  /// Scale of a card or glass control while pressed.
  static const double pressedScale = 0.97;

  /// Inset of a medium-detent fallback sheet from the screen edges.
  static const double sheetInset = 8;
}

/// Motion constants. With Reduce Motion
/// (`MediaQuery.disableAnimationsOf`) moves become instant or cross-fades and
/// nothing scales; each component applies that itself.
abstract final class PdMotion {
  /// The selection capsule sliding between tabs.
  static const Duration tabSelection = Duration(milliseconds: 200);

  /// Press feedback (scale down / back).
  static const Duration press = Duration(milliseconds: 100);

  /// Cross-fades between glass states (minimised bar, toast replacing the
  /// accessory).
  static const Duration crossFade = Duration(milliseconds: 200);

  /// A toast without Undo stays this long.
  static const Duration toast = Duration(seconds: 4);

  /// A toast with Undo stays this long.
  static const Duration toastWithUndo = Duration(seconds: 6);

  /// Close to the iOS default spring for small moves.
  static const Curve standard = Curves.easeOutCubic;
}

/// Shadow tokens. Their colours are theme tokens in [PdColors]; offsets and
/// blurs come from tokens.json.
abstract final class PdShadows {
  /// `shadow-glass`: under every floating glass control.
  static List<BoxShadow> glass(PdColors colors) => [
    BoxShadow(
      color: colors.shadowGlass,
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  /// `shadow-sheet`: above a sheet.
  static List<BoxShadow> sheet(PdColors colors) => [
    BoxShadow(
      color: colors.shadowSheet,
      offset: const Offset(0, -8),
      blurRadius: 32,
    ),
  ];

  /// `shadow-paper-pressed`: paper while pressed or dragged only.
  static List<BoxShadow> paperPressed(PdColors colors) => [
    BoxShadow(
      color: colors.shadowPaperPressed,
      offset: const Offset(0, 6),
      blurRadius: 16,
    ),
  ];
}
