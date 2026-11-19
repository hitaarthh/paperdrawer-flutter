import 'package:flutter/widgets.dart';

/// PaperDrawer Mobile tokens (design/tokens.json). Dark-only at launch.
/// Paper is the content, dark is the room.
abstract final class Pd {
  // Ground and chrome
  static const bg = Color(0xFF0E1311);
  static const surface1 = Color(0xFF141A17);
  static const surface2 = Color(0xFF1A211E);
  static const surface3 = Color(0xFF222B27);
  static const hairline = Color(0x14FFFFFF);
  static const line = Color(0xFF66726B);

  // Floating glass dock
  static const dockGlassTop = Color(0xB8242D28);
  static const dockGlassBottom = Color(0xB8141A17);
  static const dockRimLight = Color(0x59FFFFFF);
  static const dockRimShade = Color(0x1FFFFFFF);
  static const dockSelection = Color(0x24F2F4EF);
  static const dockBlur = 22.0;
  static const dockControlHeight = 56.0;
  static const dockAddWidth = 34.0;
  static const dockAddHeight = 26.0;
  static const dockAddGlow = [
    BoxShadow(color: Color(0x59D4F25A), blurRadius: 16),
  ];
  static const dockMaxWidth = 440.0;
  static const dockSelectionDuration = Duration(milliseconds: 200);

  // Text on dark
  static const text = Color(0xFFF2F4EF);
  static const text2 = Color(0xFFDDE3DF);
  static const textMuted = Color(0xFFA3AEA8);
  static const textSubtle = Color(0xFF8F9A94);
  static const placeholder = Color(0xFF7F8A84);

  // Action
  static const lime = Color(0xFFD4F25A);
  static const limePressed = Color(0xFFBEDB4C);
  static const limeTint = Color(0x29D4F25A);
  static const onLime = bg;

  // Time and status on dark
  static const signal = Color(0xFFFF8A4C);
  static const signalSoft = Color(0xFFFFB48C);
  static const signalTint = Color(0x29FF8A4C);
  static const settled = Color(0xFF7FD39A);

  // Paper
  static const paper = Color(0xFFFBFAF6);
  static const paper2 = Color(0xFFF3F1E8);
  static const paperRule = Color(0xFFCFCDC2);
  static const paperDash = Color(0xFFB9BDB8);
  static const paperTrack = Color(0xFFE6E5DE);

  // Ink on paper
  static const ink = bg;
  static const ink2 = Color(0xFF23282A);
  static const inkMuted = Color(0xFF5E6662);
  static const dueInk = Color(0xFFA8441A);

  // Stamps
  static const stampDue = Color(0xFFC2410C);
  static const stampCovered = Color(0xFF2A7449);
  static const stampExpired = Color(0xFF6B6F6A);

  static const scrim = Color(0xA6000000);

  // Spacing (4pt grid)
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;

  /// iOS screen margin.
  static const margin = s5;

  // Radii
  static const rXs = 3.0;
  static const rSm = 6.0;
  static const rMd = 12.0;
  static const rLg = 20.0;
  static const rPill = 999.0;

  // Sizes
  static const tapMin = 48.0;
  static const controlH = 52.0;
  static const iconMd = 24.0;
  static const iconSm = 18.0;
  static const appbarIos = 44.0;
  static const tabbarIos = 49.0;

  /// Max content width on tablets.
  static const maxContent = 720.0;

  // Shadows
  static const shadowPaper = [
    BoxShadow(color: Color(0x59000000), offset: Offset(0, 18), blurRadius: 24),
  ];
  static const shadowSheet = [
    BoxShadow(color: Color(0x73000000), offset: Offset(0, -12), blurRadius: 32),
  ];
  static const shadowFab = [
    BoxShadow(color: Color(0x73000000), offset: Offset(0, 8), blurRadius: 20),
  ];

  // Motion
  static const sheetDuration = Duration(milliseconds: 250);
  static const stampDuration = Duration(milliseconds: 120);
}
