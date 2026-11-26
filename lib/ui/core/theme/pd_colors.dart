import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'pd_palette.dart';

/// Every colour token of the Liquid Glass design system, for one theme.
///
/// Read it from the theme with `context.pd.colors` (see `pd_theme.dart`),
/// never from a static constant, so light and dark both work.
/// [PdColors.dark] comes from `design/liquid-glass/tokens.json`;
/// [PdColors.light] from the `*Light.dc.html` canvas boards. The full
/// dark/light table and where each light value comes from is in
/// `pd_palette.dart`.
///
/// Light-mode rules (standard design-system rule, not Flutter behaviour):
/// - use [lime] only as a fill; where lime would be text or a thin stroke
///   use [limeText] (olive `#465B16` in light);
/// - paper, ink, lime fills, [glassLime] and [signalFill] are identical in
///   both themes.
@immutable
final class PdColors extends ThemeExtension<PdColors> {
  const PdColors({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.hairline,
    required this.line,
    required this.text,
    required this.text2,
    required this.textMuted,
    required this.textSubtle,
    required this.placeholder,
    required this.lime,
    required this.limePressed,
    required this.limeTint,
    required this.onLime,
    required this.limeText,
    required this.focusRing,
    required this.focusRingPaper,
    required this.signal,
    required this.signalFill,
    required this.signalSoft,
    required this.signalTint,
    required this.settled,
    required this.danger,
    required this.paper,
    required this.paper2,
    required this.paperRule,
    required this.paperTrack,
    required this.ink,
    required this.ink2,
    required this.inkMuted,
    required this.dueInk,
    required this.coveredInk,
    required this.endedInk,
    required this.readHighlight,
    required this.missTint,
    required this.missInk,
    required this.glassFill,
    required this.glassLime,
    required this.glassLimeRim,
    required this.glassLimeRimShade,
    required this.glassRim,
    required this.glassRimShade,
    required this.glassSelection,
    required this.scrim,
    required this.scrimMedium,
    required this.shadowGlass,
    required this.shadowSheet,
    required this.shadowPaperPressed,
  });

  /// Dark theme (tokens.json).
  static const PdColors dark = pdDarkColors;

  /// Light theme (canvas `*Light` boards).
  static const PdColors light = pdLightColors;

  /// The palette for [brightness].
  static PdColors forBrightness(Brightness brightness) => switch (brightness) {
    Brightness.dark => dark,
    Brightness.light => light,
  };

  /// `bg`: The room: screen ground behind everything.
  final Color bg;
  /// `surface-1`: Grouped list rows, text fields, sidebar fallback.
  final Color surface1;
  /// `surface-2`: Secondary buttons; solid glass under Reduce Transparency.
  final Color surface2;
  /// `surface-3`: Meter tracks on the room, pressed rows, disabled fills.
  final Color surface3;
  /// `hairline`: Decorative separators between rows on the room.
  final Color hairline;
  /// `line`: Control borders on bg and surface-1; Increase Contrast rim.
  final Color line;
  /// `text`: Primary text and icons on the room and on glass.
  final Color text;
  /// `text-2`: Secondary strong text; unselected glass labels.
  final Color text2;
  /// `text-muted`: Meta and helper text on the room. Never on glass.
  final Color textMuted;
  /// `text-subtle`: Quietest text: footers, chevrons. Never on glass.
  final Color textSubtle;
  /// `placeholder`: Field placeholders on surface-1.
  final Color placeholder;
  /// `lime`: The one action colour as a FILL (buttons, Scan, switch track).
  final Color lime;
  /// `lime-pressed`: Pressed lime fill.
  final Color limePressed;
  /// `lime-tint`: Lime wash behind selected picker rows.
  final Color limeTint;
  /// `on-lime`: Text and icons on lime and glass-lime.
  final Color onLime;
  /// `(light rule)`: Lime used as TEXT or a thin stroke: links, plain buttons, selected tab. Olive in light.
  final Color limeText;
  /// `focus-ring`: Focus ring on the room and glass (2pt, 2pt offset).
  final Color focusRing;
  /// `focus-ring-paper`: Focus ring on paper.
  final Color focusRingPaper;
  /// `signal`: Time is close, on the room: dot, DUE labels and counts.
  final Color signal;
  /// `(light rule)`: Orange FILLS on the room: due meter fill, the orange ticket. Same in both.
  final Color signalFill;
  /// `signal-soft`: Due text on glass and on signal-tint.
  final Color signalSoft;
  /// `signal-tint`: Background of a due row or banner on the room.
  final Color signalTint;
  /// `settled`: Done/covered on the room.
  final Color settled;
  /// `danger`: Destructive actions only.
  final Color danger;
  /// `paper`: Bills and receipts: the paper card ground.
  final Color paper;
  /// `paper-2`: Policies, vehicle papers, agreements.
  final Color paper2;
  /// `paper-rule`: Hairlines on paper.
  final Color paperRule;
  /// `paper-track`: Meter track on paper.
  final Color paperTrack;
  /// `ink`: Figures and titles on paper.
  final Color ink;
  /// `ink-2`: Body text and data on paper.
  final Color ink2;
  /// `ink-muted`: Labels and meta on paper.
  final Color inkMuted;
  /// `due-ink`: Time is close, on paper.
  final Color dueInk;
  /// `covered-ink`: COVERED labels on paper.
  final Color coveredInk;
  /// `ended-ink`: ENDED labels and lapsed dates on paper.
  final Color endedInk;
  /// `read-highlight`: Behind a value read from the photo.
  final Color readHighlight;
  /// `miss-tint`: Behind a field the reader couldn't read.
  final Color missTint;
  /// `miss-ink`: Couldn't-read hint text on miss-tint.
  final Color missInk;
  /// `glass-fill`: Fallback glass fill under the blur.
  final Color glassFill;
  /// `glass-lime`: Tinted glass for Scan only.
  final Color glassLime;
  /// `(bundle.css)`: Top highlight of lime glass (.pd-glass-lime).
  final Color glassLimeRim;
  /// `(bundle.css)`: Ring around lime glass (.pd-glass-lime).
  final Color glassLimeRimShade;
  /// `glass-rim`: Top specular edge of fallback glass (1pt).
  final Color glassRim;
  /// `glass-rim-shade`: Hairline ring around fallback glass.
  final Color glassRimShade;
  /// `glass-selection`: Selection capsule inside glass.
  final Color glassSelection;
  /// `scrim`: Behind a large-detent sheet.
  final Color scrim;
  /// `(boards)`: Dim behind a medium-detent sheet.
  final Color scrimMedium;
  /// `shadow-glass`: Colour of shadow-glass (0 8 24).
  final Color shadowGlass;
  /// `shadow-sheet`: Colour of shadow-sheet (0 -8 32).
  final Color shadowSheet;
  /// `shadow-paper-pressed`: Colour of shadow-paper-pressed (0 6 16).
  final Color shadowPaperPressed;

  @override
  PdColors copyWith({
    Color? bg,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? hairline,
    Color? line,
    Color? text,
    Color? text2,
    Color? textMuted,
    Color? textSubtle,
    Color? placeholder,
    Color? lime,
    Color? limePressed,
    Color? limeTint,
    Color? onLime,
    Color? limeText,
    Color? focusRing,
    Color? focusRingPaper,
    Color? signal,
    Color? signalFill,
    Color? signalSoft,
    Color? signalTint,
    Color? settled,
    Color? danger,
    Color? paper,
    Color? paper2,
    Color? paperRule,
    Color? paperTrack,
    Color? ink,
    Color? ink2,
    Color? inkMuted,
    Color? dueInk,
    Color? coveredInk,
    Color? endedInk,
    Color? readHighlight,
    Color? missTint,
    Color? missInk,
    Color? glassFill,
    Color? glassLime,
    Color? glassLimeRim,
    Color? glassLimeRimShade,
    Color? glassRim,
    Color? glassRimShade,
    Color? glassSelection,
    Color? scrim,
    Color? scrimMedium,
    Color? shadowGlass,
    Color? shadowSheet,
    Color? shadowPaperPressed,
  }) => PdColors(
    bg: bg ?? this.bg,
    surface1: surface1 ?? this.surface1,
    surface2: surface2 ?? this.surface2,
    surface3: surface3 ?? this.surface3,
    hairline: hairline ?? this.hairline,
    line: line ?? this.line,
    text: text ?? this.text,
    text2: text2 ?? this.text2,
    textMuted: textMuted ?? this.textMuted,
    textSubtle: textSubtle ?? this.textSubtle,
    placeholder: placeholder ?? this.placeholder,
    lime: lime ?? this.lime,
    limePressed: limePressed ?? this.limePressed,
    limeTint: limeTint ?? this.limeTint,
    onLime: onLime ?? this.onLime,
    limeText: limeText ?? this.limeText,
    focusRing: focusRing ?? this.focusRing,
    focusRingPaper: focusRingPaper ?? this.focusRingPaper,
    signal: signal ?? this.signal,
    signalFill: signalFill ?? this.signalFill,
    signalSoft: signalSoft ?? this.signalSoft,
    signalTint: signalTint ?? this.signalTint,
    settled: settled ?? this.settled,
    danger: danger ?? this.danger,
    paper: paper ?? this.paper,
    paper2: paper2 ?? this.paper2,
    paperRule: paperRule ?? this.paperRule,
    paperTrack: paperTrack ?? this.paperTrack,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    inkMuted: inkMuted ?? this.inkMuted,
    dueInk: dueInk ?? this.dueInk,
    coveredInk: coveredInk ?? this.coveredInk,
    endedInk: endedInk ?? this.endedInk,
    readHighlight: readHighlight ?? this.readHighlight,
    missTint: missTint ?? this.missTint,
    missInk: missInk ?? this.missInk,
    glassFill: glassFill ?? this.glassFill,
    glassLime: glassLime ?? this.glassLime,
    glassLimeRim: glassLimeRim ?? this.glassLimeRim,
    glassLimeRimShade: glassLimeRimShade ?? this.glassLimeRimShade,
    glassRim: glassRim ?? this.glassRim,
    glassRimShade: glassRimShade ?? this.glassRimShade,
    glassSelection: glassSelection ?? this.glassSelection,
    scrim: scrim ?? this.scrim,
    scrimMedium: scrimMedium ?? this.scrimMedium,
    shadowGlass: shadowGlass ?? this.shadowGlass,
    shadowSheet: shadowSheet ?? this.shadowSheet,
    shadowPaperPressed: shadowPaperPressed ?? this.shadowPaperPressed,
  );

  @override
  PdColors lerp(PdColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? b;
    return PdColors(
      bg: mix(bg, other.bg),
      surface1: mix(surface1, other.surface1),
      surface2: mix(surface2, other.surface2),
      surface3: mix(surface3, other.surface3),
      hairline: mix(hairline, other.hairline),
      line: mix(line, other.line),
      text: mix(text, other.text),
      text2: mix(text2, other.text2),
      textMuted: mix(textMuted, other.textMuted),
      textSubtle: mix(textSubtle, other.textSubtle),
      placeholder: mix(placeholder, other.placeholder),
      lime: mix(lime, other.lime),
      limePressed: mix(limePressed, other.limePressed),
      limeTint: mix(limeTint, other.limeTint),
      onLime: mix(onLime, other.onLime),
      limeText: mix(limeText, other.limeText),
      focusRing: mix(focusRing, other.focusRing),
      focusRingPaper: mix(focusRingPaper, other.focusRingPaper),
      signal: mix(signal, other.signal),
      signalFill: mix(signalFill, other.signalFill),
      signalSoft: mix(signalSoft, other.signalSoft),
      signalTint: mix(signalTint, other.signalTint),
      settled: mix(settled, other.settled),
      danger: mix(danger, other.danger),
      paper: mix(paper, other.paper),
      paper2: mix(paper2, other.paper2),
      paperRule: mix(paperRule, other.paperRule),
      paperTrack: mix(paperTrack, other.paperTrack),
      ink: mix(ink, other.ink),
      ink2: mix(ink2, other.ink2),
      inkMuted: mix(inkMuted, other.inkMuted),
      dueInk: mix(dueInk, other.dueInk),
      coveredInk: mix(coveredInk, other.coveredInk),
      endedInk: mix(endedInk, other.endedInk),
      readHighlight: mix(readHighlight, other.readHighlight),
      missTint: mix(missTint, other.missTint),
      missInk: mix(missInk, other.missInk),
      glassFill: mix(glassFill, other.glassFill),
      glassLime: mix(glassLime, other.glassLime),
      glassLimeRim: mix(glassLimeRim, other.glassLimeRim),
      glassLimeRimShade: mix(glassLimeRimShade, other.glassLimeRimShade),
      glassRim: mix(glassRim, other.glassRim),
      glassRimShade: mix(glassRimShade, other.glassRimShade),
      glassSelection: mix(glassSelection, other.glassSelection),
      scrim: mix(scrim, other.scrim),
      scrimMedium: mix(scrimMedium, other.scrimMedium),
      shadowGlass: mix(shadowGlass, other.shadowGlass),
      shadowSheet: mix(shadowSheet, other.shadowSheet),
      shadowPaperPressed: mix(shadowPaperPressed, other.shadowPaperPressed),
    );
  }

  /// Every token by its design name (`surface-1`), for tests and tools.
  Map<String, Color> get byTokenName => {
    'bg': bg,
    'surface-1': surface1,
    'surface-2': surface2,
    'surface-3': surface3,
    'hairline': hairline,
    'line': line,
    'text': text,
    'text-2': text2,
    'text-muted': textMuted,
    'text-subtle': textSubtle,
    'placeholder': placeholder,
    'lime': lime,
    'lime-pressed': limePressed,
    'lime-tint': limeTint,
    'on-lime': onLime,
    'focus-ring': focusRing,
    'focus-ring-paper': focusRingPaper,
    'signal': signal,
    'signal-soft': signalSoft,
    'signal-tint': signalTint,
    'settled': settled,
    'danger': danger,
    'paper': paper,
    'paper-2': paper2,
    'paper-rule': paperRule,
    'paper-track': paperTrack,
    'ink': ink,
    'ink-2': ink2,
    'ink-muted': inkMuted,
    'due-ink': dueInk,
    'covered-ink': coveredInk,
    'ended-ink': endedInk,
    'read-highlight': readHighlight,
    'miss-tint': missTint,
    'miss-ink': missInk,
    'glass-fill': glassFill,
    'glass-lime': glassLime,
    'glass-rim': glassRim,
    'glass-rim-shade': glassRimShade,
    'glass-selection': glassSelection,
    'scrim': scrim,
    'shadow-glass': shadowGlass,
    'shadow-sheet': shadowSheet,
    'shadow-paper-pressed': shadowPaperPressed,
  };

  List<Color> get _all => [
    bg,
    surface1,
    surface2,
    surface3,
    hairline,
    line,
    text,
    text2,
    textMuted,
    textSubtle,
    placeholder,
    lime,
    limePressed,
    limeTint,
    onLime,
    limeText,
    focusRing,
    focusRingPaper,
    signal,
    signalFill,
    signalSoft,
    signalTint,
    settled,
    danger,
    paper,
    paper2,
    paperRule,
    paperTrack,
    ink,
    ink2,
    inkMuted,
    dueInk,
    coveredInk,
    endedInk,
    readHighlight,
    missTint,
    missInk,
    glassFill,
    glassLime,
    glassLimeRim,
    glassLimeRimShade,
    glassRim,
    glassRimShade,
    glassSelection,
    scrim,
    scrimMedium,
    shadowGlass,
    shadowSheet,
    shadowPaperPressed,
  ];

  @override
  bool operator ==(Object other) =>
      other is PdColors && listEquals(other._all, _all);

  @override
  int get hashCode => Object.hashAll(_all);
}
