import 'dart:ui' show FontFeature, FontVariation;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// The Liquid Glass type scale (`type` group in tokens.json), as a theme
/// extension so it is read with `context.pd.type`.
///
/// Families are the names declared in `pubspec.yaml` (`Bricolage`, `Inter`,
/// `JetBrainsMono`). The bundled fonts are variable, so weight is also set on
/// the `wght` axis (and `opsz` for Bricolage). Figures and data use tabular
/// numbers.
///
/// Styles carry **no colour**: a widget picks the colour token for the layer
/// it sits on (`text` on the room and glass, `ink` on paper) with
/// `copyWith(color: ...)`.
///
/// Dynamic Type (Flutter behaviour + PaperDrawer rule):
/// - Flutter applies one [TextScaler] to every style; iOS maps the system
///   text size into it. Every style below scales with it. The iOS text style
///   each one follows is in its doc comment, for reference.
/// - Content (paper, lists, sheets) scales up to the largest accessibility
///   size. At accessibility sizes (`PdDynamicType.isAccessibilitySize`) data
///   rows stack and the DeadlineCard number moves above the title.
/// - Floating glass chrome (tab bar, Scan, DeadlineAccessory, Toast, toolbar
///   buttons) caps its text at `PdDynamicType.chromeMaxScale`, like the iOS
///   system bars do.
@immutable
final class PdTypeScale extends ThemeExtension<PdTypeScale> {
  const PdTypeScale({
    required this.largeTitle,
    required this.title1,
    required this.title2,
    required this.cardTitle,
    required this.figureXl,
    required this.figure,
    required this.figureSm,
    required this.wordmark,
    required this.navTitle,
    required this.body,
    required this.bodyStrong,
    required this.button,
    required this.callout,
    required this.subhead,
    required this.footnote,
    required this.tabLabel,
    required this.label,
    required this.status,
    required this.data,
    required this.dataStrong,
  });

  /// Family name of Bricolage Grotesque in pubspec.yaml.
  static const display = 'Bricolage';

  /// Family name of Inter in pubspec.yaml.
  static const sans = 'Inter';

  /// Family name of JetBrains Mono in pubspec.yaml.
  static const mono = 'JetBrainsMono';

  /// The scale from tokens.json.
  static final PdTypeScale standard = PdTypeScale(
    largeTitle: _display(34, 38, 700, -0.03),
    title1: _display(28, 32, 700, -0.025),
    title2: _display(22, 26, 700, -0.02),
    cardTitle: _display(18, 22, 700, -0.015),
    figureXl: _display(56, 52, 800, -0.04, tabular: true),
    figure: _display(40, 40, 800, -0.04, tabular: true),
    figureSm: _display(22, 26, 700, -0.02, tabular: true),
    wordmark: _display(20, 24, 700, -0.03),
    navTitle: _sans(17, 22, 600),
    body: _sans(17, 24, 400),
    bodyStrong: _sans(17, 24, 600),
    button: _sans(17, 22, 600),
    callout: _sans(15, 21, 400),
    subhead: _sans(15, 20, 500),
    footnote: _sans(13, 18, 400),
    tabLabel: _sans(10, 12, 600, em: 0.01),
    label: _mono(11, 14, 500, 0.08),
    status: _mono(11, 14, 600, 0.08),
    data: _mono(13, 18, 400, 0, tabular: true),
    dataStrong: _mono(13, 18, 600, 0, tabular: true),
  );

  /// Screen titles. iOS Large Title.
  final TextStyle largeTitle;

  /// Item name on detail, large-detent sheet titles. iOS Title 1.
  final TextStyle title1;

  /// Medium-detent sheet titles, empty-state headlines. iOS Title 2.
  final TextStyle title2;

  /// Item names on cards. iOS Title 3.
  final TextStyle cardTitle;

  /// The day count on item detail. iOS Large Title.
  final TextStyle figureXl;

  /// Day counts on DeadlineCard. iOS Large Title.
  final TextStyle figure;

  /// Amounts inside cards. iOS Title 2.
  final TextStyle figureSm;

  /// "PaperDrawer" beside the mark (canvas: 20 pt). iOS Title 3.
  final TextStyle wordmark;

  /// Inline title once the large title collapses. iOS Headline.
  final TextStyle navTitle;

  /// Reading text and list row titles. iOS Body.
  final TextStyle body;

  /// Emphasis; row titles that lead a group. iOS Headline.
  final TextStyle bodyStrong;

  /// Button labels. iOS Headline.
  final TextStyle button;

  /// Supporting lines on cards and sheets. iOS Callout.
  final TextStyle callout;

  /// DeadlineAccessory and Toast text, small buttons. iOS Subheadline.
  final TextStyle subhead;

  /// Footers and helper text. iOS Footnote.
  final TextStyle footnote;

  /// Tab bar labels only. iOS Caption 2 (capped like system tab bars).
  final TextStyle tabLabel;

  /// UPPERCASE eyebrows and section headers (write the copy in caps). iOS
  /// Caption 2.
  final TextStyle label;

  /// StatusLabel text only. iOS Caption 2.
  final TextStyle status;

  /// Dates, references, amounts in data rows. iOS Footnote.
  final TextStyle data;

  /// The one value a data row is about. iOS Footnote.
  final TextStyle dataStrong;

  static TextStyle _style(
    String family,
    double size,
    double lineHeight,
    int weight, {
    double em = 0,
    bool tabular = false,
    bool opticalSize = false,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [
      FontVariation.weight(weight.toDouble()),
      if (opticalSize) FontVariation.opticalSize(size.clamp(12, 96).toDouble()),
    ],
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    letterSpacing: size * em,
  );

  static TextStyle _display(
    double size,
    double lineHeight,
    int weight,
    double em, {
    bool tabular = false,
  }) => _style(
    display,
    size,
    lineHeight,
    weight,
    em: em,
    tabular: tabular,
    opticalSize: true,
  );

  static TextStyle _sans(
    double size,
    double lineHeight,
    int weight, {
    double em = 0,
  }) => _style(sans, size, lineHeight, weight, em: em);

  static TextStyle _mono(
    double size,
    double lineHeight,
    int weight,
    double em, {
    bool tabular = false,
  }) => _style(mono, size, lineHeight, weight, em: em, tabular: tabular);

  List<TextStyle> get _all => [
    largeTitle,
    title1,
    title2,
    cardTitle,
    figureXl,
    figure,
    figureSm,
    wordmark,
    navTitle,
    body,
    bodyStrong,
    button,
    callout,
    subhead,
    footnote,
    tabLabel,
    label,
    status,
    data,
    dataStrong,
  ];

  /// A Material [TextTheme] in [color], so plain `Text` gets body type.
  TextTheme toTextTheme(Color color) {
    TextStyle c(TextStyle style) => style.copyWith(color: color);
    return TextTheme(
      displayLarge: c(figureXl),
      displayMedium: c(figure),
      displaySmall: c(largeTitle),
      headlineLarge: c(largeTitle),
      headlineMedium: c(title1),
      headlineSmall: c(title2),
      titleLarge: c(title2),
      titleMedium: c(cardTitle),
      titleSmall: c(bodyStrong),
      bodyLarge: c(body),
      bodyMedium: c(body),
      bodySmall: c(footnote),
      labelLarge: c(button),
      labelMedium: c(subhead),
      labelSmall: c(label),
    );
  }

  @override
  PdTypeScale copyWith({
    TextStyle? largeTitle,
    TextStyle? title1,
    TextStyle? title2,
    TextStyle? cardTitle,
    TextStyle? figureXl,
    TextStyle? figure,
    TextStyle? figureSm,
    TextStyle? wordmark,
    TextStyle? navTitle,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? button,
    TextStyle? callout,
    TextStyle? subhead,
    TextStyle? footnote,
    TextStyle? tabLabel,
    TextStyle? label,
    TextStyle? status,
    TextStyle? data,
    TextStyle? dataStrong,
  }) => PdTypeScale(
    largeTitle: largeTitle ?? this.largeTitle,
    title1: title1 ?? this.title1,
    title2: title2 ?? this.title2,
    cardTitle: cardTitle ?? this.cardTitle,
    figureXl: figureXl ?? this.figureXl,
    figure: figure ?? this.figure,
    figureSm: figureSm ?? this.figureSm,
    wordmark: wordmark ?? this.wordmark,
    navTitle: navTitle ?? this.navTitle,
    body: body ?? this.body,
    bodyStrong: bodyStrong ?? this.bodyStrong,
    button: button ?? this.button,
    callout: callout ?? this.callout,
    subhead: subhead ?? this.subhead,
    footnote: footnote ?? this.footnote,
    tabLabel: tabLabel ?? this.tabLabel,
    label: label ?? this.label,
    status: status ?? this.status,
    data: data ?? this.data,
    dataStrong: dataStrong ?? this.dataStrong,
  );

  @override
  PdTypeScale lerp(PdTypeScale? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t) ?? b;
    return PdTypeScale(
      largeTitle: mix(largeTitle, other.largeTitle),
      title1: mix(title1, other.title1),
      title2: mix(title2, other.title2),
      cardTitle: mix(cardTitle, other.cardTitle),
      figureXl: mix(figureXl, other.figureXl),
      figure: mix(figure, other.figure),
      figureSm: mix(figureSm, other.figureSm),
      wordmark: mix(wordmark, other.wordmark),
      navTitle: mix(navTitle, other.navTitle),
      body: mix(body, other.body),
      bodyStrong: mix(bodyStrong, other.bodyStrong),
      button: mix(button, other.button),
      callout: mix(callout, other.callout),
      subhead: mix(subhead, other.subhead),
      footnote: mix(footnote, other.footnote),
      tabLabel: mix(tabLabel, other.tabLabel),
      label: mix(label, other.label),
      status: mix(status, other.status),
      data: mix(data, other.data),
      dataStrong: mix(dataStrong, other.dataStrong),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PdTypeScale && listEquals(other._all, _all);

  @override
  int get hashCode => Object.hashAll(_all);
}
