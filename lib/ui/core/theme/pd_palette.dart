import 'package:flutter/painting.dart' show Color;

import 'pd_colors.dart';

// Dark values: design/liquid-glass/tokens.json (tokens.css). Light values:
// read from the canvas `*Light.dc.html` boards against their dark twins
// (iOSHomeLight vs Main, iOSVaultLight vs iOSVault, iOSSettingsLight vs
// iOSSettings, iPadHomeLight vs iPadHome and every other twin). The boards'
// light override block (.lg/.sel/.edge/.lbl) is identical on every board.
//
// Source column: board = a colour the boards swap 1:1 between the twins;
// unchanged = identical on both twins (paper, ink, lime fills, tickets);
// derived = no board shows it, chosen from the nearest board value so the
// token's usage note (contrast) still holds. Hex is #RRGGBB or #RRGGBBAA.
//
// | Field | Token | Dark | Light | Source |
// |---|---|---|---|---|
// | bg | bg | #0E1311 | #F7F3DF | board |
// | surface1 | surface-1 | #141A17 | #FFFDF3 | board |
// | surface2 | surface-2 | #1A211E | #FFFCF1 | board |
// | surface3 | surface-3 | #222B27 | #DED8C2 | board |
// | hairline | hairline | #FFFFFF14 | #31271714 | board |
// | line | line | #66726B | #AFA78E | board |
// | text | text | #F2F4EF | #20241A | board |
// | text2 | text-2 | #DDE3DF | #353B2D | board |
// | textMuted | text-muted | #A3AEA8 | #565947 | board |
// | textSubtle | text-subtle | #8F9A94 | #595D4C | board |
// | placeholder | placeholder | #7F8A84 | #626451 | board |
// | lime | lime | #D4F25A | #D4F25A | board |
// | limePressed | lime-pressed | #BEDB4C | #BEDB4C | unchanged |
// | limeTint | lime-tint | #D4F25A29 | #D4F25A4D | derived |
// | onLime | on-lime | #0E1311 | #0E1311 | board |
// | limeText | (light rule) | #D4F25A | #465B16 | board |
// | focusRing | focus-ring | #D4F25A | #465B16 | derived |
// | focusRingPaper | focus-ring-paper | #0E1311 | #0E1311 | unchanged |
// | signal | signal | #FF8A4C | #963B16 | board |
// | signalFill | (light rule) | #FF8A4C | #FF8A4C | board |
// | signalSoft | signal-soft | #FFB48C | #963B16 | derived |
// | signalTint | signal-tint | #FF8A4C29 | #963B161F | derived |
// | settled | settled | #7FD39A | #326342 | board |
// | danger | danger | #FF7B72 | #8E3215 | board |
// | paper | paper | #FBFAF6 | #FBFAF6 | unchanged |
// | paper2 | paper-2 | #F3F1E8 | #F3F1E8 | unchanged |
// | paperRule | paper-rule | #CFCDC2 | #CFCDC2 | unchanged |
// | paperTrack | paper-track | #E6E5DE | #E6E5DE | unchanged |
// | ink | ink | #0E1311 | #0E1311 | unchanged |
// | ink2 | ink-2 | #23282A | #23282A | unchanged |
// | inkMuted | ink-muted | #5E6662 | #5E6662 | unchanged |
// | dueInk | due-ink | #A8441A | #A8441A | unchanged |
// | coveredInk | covered-ink | #2A7449 | #2A7449 | unchanged |
// | endedInk | ended-ink | #6B6F6A | #6B6F6A | unchanged |
// | readHighlight | read-highlight | #E4F59C | #E4F59C | unchanged |
// | missTint | miss-tint | #FFF4EC | #FFF4EC | unchanged |
// | missInk | miss-ink | #8A4A2A | #8A4A2A | unchanged |
// | glassFill | glass-fill | #1C231FCC | #FFFCF1DB | board |
// | glassLime | glass-lime | #D4F25AE6 | #D4F25AE6 | unchanged |
// | glassLimeRim | (bundle.css) | #FFFFFF8C | #FFFFFF8C | unchanged |
// | glassLimeRimShade | (bundle.css) | #FFFFFF40 | #FFFFFF40 | unchanged |
// | glassRim | glass-rim | #FFFFFF59 | #FFFFFFE6 | board |
// | glassRimShade | glass-rim-shade | #FFFFFF1F | #3127171A | board |
// | glassSelection | glass-selection | #F2F4EF24 | #31271712 | board |
// | scrim | scrim | #000000A6 | #31271752 | derived |
// | scrimMedium | (boards) | #00000040 | #3127171F | board |
// | shadowGlass | shadow-glass | #00000059 | #4D3A0E24 | board |
// | shadowSheet | shadow-sheet | #00000073 | #4D3A0E33 | derived |
// | shadowPaperPressed | shadow-paper-pressed | #00000059 | #4D3A0E33 | board |
//
// Notes on the board mapping:
// - rgba(255,255,255,a) washes on dark become rgba(49,39,23,a) on light
//   (hairline, glass-selection, rim shade); black shadows become
//   rgba(77,58,14,a) (shadow-glass .14, paper/ticket drop shadow .20).
// - Sheets: rgba(28,34,31,.82-.88) -> rgba(255,252,241,.86) = glass-fill.
// - #D4F25A as text/stroke -> #465B16 (limeText); as a fill it stays.
// - #FF8A4C as text -> #963B16 (signal); as a fill (meter, ticket) it
//   stays (signalFill).
// - focus-ring: the boards' shared CSS keeps a lime outline, but lime on
//   cream is about 1.1:1, so light uses olive (derived).
// - Board-only greys with no token (#C9D1CC->#383C31, #2A332F->#EAE4D2,
//   #3E4843->#CFC8B0) are not tokens and are not carried over.

/// Dark palette. Use `PdColors.dark`.
const pdDarkColors = PdColors(
  bg: Color(0xFF0E1311),
  surface1: Color(0xFF141A17),
  surface2: Color(0xFF1A211E),
  surface3: Color(0xFF222B27),
  hairline: Color(0x14FFFFFF),
  line: Color(0xFF66726B),
  text: Color(0xFFF2F4EF),
  text2: Color(0xFFDDE3DF),
  textMuted: Color(0xFFA3AEA8),
  textSubtle: Color(0xFF8F9A94),
  placeholder: Color(0xFF7F8A84),
  lime: Color(0xFFD4F25A),
  limePressed: Color(0xFFBEDB4C),
  limeTint: Color(0x29D4F25A),
  onLime: Color(0xFF0E1311),
  limeText: Color(0xFFD4F25A),
  focusRing: Color(0xFFD4F25A),
  focusRingPaper: Color(0xFF0E1311),
  signal: Color(0xFFFF8A4C),
  signalFill: Color(0xFFFF8A4C),
  signalSoft: Color(0xFFFFB48C),
  signalTint: Color(0x29FF8A4C),
  settled: Color(0xFF7FD39A),
  danger: Color(0xFFFF7B72),
  paper: Color(0xFFFBFAF6),
  paper2: Color(0xFFF3F1E8),
  paperRule: Color(0xFFCFCDC2),
  paperTrack: Color(0xFFE6E5DE),
  ink: Color(0xFF0E1311),
  ink2: Color(0xFF23282A),
  inkMuted: Color(0xFF5E6662),
  dueInk: Color(0xFFA8441A),
  coveredInk: Color(0xFF2A7449),
  endedInk: Color(0xFF6B6F6A),
  readHighlight: Color(0xFFE4F59C),
  missTint: Color(0xFFFFF4EC),
  missInk: Color(0xFF8A4A2A),
  glassFill: Color(0xCC1C231F),
  glassLime: Color(0xE6D4F25A),
  glassLimeRim: Color(0x8CFFFFFF),
  glassLimeRimShade: Color(0x40FFFFFF),
  glassRim: Color(0x59FFFFFF),
  glassRimShade: Color(0x1FFFFFFF),
  glassSelection: Color(0x24F2F4EF),
  scrim: Color(0xA6000000),
  scrimMedium: Color(0x40000000),
  shadowGlass: Color(0x59000000),
  shadowSheet: Color(0x73000000),
  shadowPaperPressed: Color(0x59000000),
);

/// Light palette. Use `PdColors.light`.
const pdLightColors = PdColors(
  bg: Color(0xFFF7F3DF),
  surface1: Color(0xFFFFFDF3),
  surface2: Color(0xFFFFFCF1),
  surface3: Color(0xFFDED8C2),
  hairline: Color(0x14312717),
  line: Color(0xFFAFA78E),
  text: Color(0xFF20241A),
  text2: Color(0xFF353B2D),
  textMuted: Color(0xFF565947),
  textSubtle: Color(0xFF595D4C),
  placeholder: Color(0xFF626451),
  lime: Color(0xFFD4F25A),
  limePressed: Color(0xFFBEDB4C),
  limeTint: Color(0x4DD4F25A),
  onLime: Color(0xFF0E1311),
  limeText: Color(0xFF465B16),
  focusRing: Color(0xFF465B16),
  focusRingPaper: Color(0xFF0E1311),
  signal: Color(0xFF963B16),
  signalFill: Color(0xFFFF8A4C),
  signalSoft: Color(0xFF963B16),
  signalTint: Color(0x1F963B16),
  settled: Color(0xFF326342),
  danger: Color(0xFF8E3215),
  paper: Color(0xFFFBFAF6),
  paper2: Color(0xFFF3F1E8),
  paperRule: Color(0xFFCFCDC2),
  paperTrack: Color(0xFFE6E5DE),
  ink: Color(0xFF0E1311),
  ink2: Color(0xFF23282A),
  inkMuted: Color(0xFF5E6662),
  dueInk: Color(0xFFA8441A),
  coveredInk: Color(0xFF2A7449),
  endedInk: Color(0xFF6B6F6A),
  readHighlight: Color(0xFFE4F59C),
  missTint: Color(0xFFFFF4EC),
  missInk: Color(0xFF8A4A2A),
  glassFill: Color(0xDBFFFCF1),
  glassLime: Color(0xE6D4F25A),
  glassLimeRim: Color(0x8CFFFFFF),
  glassLimeRimShade: Color(0x40FFFFFF),
  glassRim: Color(0xE6FFFFFF),
  glassRimShade: Color(0x1A312717),
  glassSelection: Color(0x12312717),
  scrim: Color(0x52312717),
  scrimMedium: Color(0x1F312717),
  shadowGlass: Color(0x244D3A0E),
  shadowSheet: Color(0x334D3A0E),
  shadowPaperPressed: Color(0x334D3A0E),
);
