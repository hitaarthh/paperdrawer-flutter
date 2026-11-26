import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'pd_colors.dart';
import 'pd_type_scale.dart';

/// The app's Material theme for [brightness] (Flutter `ThemeData`, built from
/// PaperDrawer tokens). It carries [PdColors] and [PdTypeScale] as theme
/// extensions; widgets read them with `context.pd`.
///
/// Wave 3 wires it as
/// `MaterialApp(theme: pdThemeData(Brightness.light),
/// darkTheme: pdThemeData(Brightness.dark), themeMode: controller.themeMode)`.
ThemeData pdThemeData(Brightness brightness) {
  final colors = PdColors.forBrightness(brightness);
  final type = PdTypeScale.standard;
  return ThemeData(
    brightness: brightness,
    platform: TargetPlatform.iOS,
    fontFamily: PdTypeScale.sans,
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    dividerColor: colors.hairline,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: colors.lime,
      onPrimary: colors.onLime,
      secondary: colors.limeText,
      onSecondary: colors.bg,
      error: colors.danger,
      onError: colors.bg,
      surface: colors.surface1,
      onSurface: colors.text,
      outline: colors.line,
      outlineVariant: colors.hairline,
      scrim: colors.scrim,
    ),
    textTheme: type.toTextTheme(colors.text),
    extensions: [colors, type],
    cupertinoOverrideTheme: pdCupertinoThemeData(brightness),
    splashFactory: NoSplash.splashFactory,
    highlightColor: colors.limeTint,
    focusColor: colors.limeTint,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.limeText,
      selectionColor: colors.limeTint,
      selectionHandleColor: colors.limeText,
    ),
  );
}

/// The Cupertino theme for [brightness]. `primaryColor` is [PdColors.limeText]
/// because Cupertino uses it for text (links, nav actions).
CupertinoThemeData pdCupertinoThemeData(Brightness brightness) {
  final colors = PdColors.forBrightness(brightness);
  final type = PdTypeScale.standard;
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: colors.limeText,
    primaryContrastingColor: colors.onLime,
    barBackgroundColor: colors.bg,
    scaffoldBackgroundColor: colors.bg,
    textTheme: CupertinoTextThemeData(
      primaryColor: colors.limeText,
      textStyle: type.body.copyWith(color: colors.text),
      actionTextStyle: type.bodyStrong.copyWith(color: colors.limeText),
      navTitleTextStyle: type.navTitle.copyWith(color: colors.text),
      navLargeTitleTextStyle: type.largeTitle.copyWith(color: colors.text),
      navActionTextStyle: type.navTitle.copyWith(color: colors.limeText),
      tabLabelTextStyle: type.tabLabel.copyWith(color: colors.text2),
      dateTimePickerTextStyle: type.body.copyWith(color: colors.text),
    ),
  );
}

/// Forces the dark theme below it, whatever Appearance says. For Camera,
/// which stays dark in both themes (canvas note).
final class PdDarkTheme extends StatelessWidget {
  const PdDarkTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: pdThemeData(Brightness.dark), child: child);
}

/// What `context.pd` returns: the theme's colours and type.
@immutable
final class PdThemeView {
  const PdThemeView({required this.colors, required this.type});

  /// Reads the extensions from [context]'s theme. A theme without them (a
  /// test that forgot `pdThemeData`) falls back to the palette for the
  /// theme's brightness, so nothing crashes.
  factory PdThemeView.of(BuildContext context) {
    final theme = Theme.of(context);
    return PdThemeView(
      colors:
          theme.extension<PdColors>() ??
          PdColors.forBrightness(theme.brightness),
      type: theme.extension<PdTypeScale>() ?? PdTypeScale.standard,
    );
  }

  final PdColors colors;
  final PdTypeScale type;

  @override
  bool operator ==(Object other) =>
      other is PdThemeView && other.colors == colors && other.type == type;

  @override
  int get hashCode => Object.hash(colors, type);
}

/// `context.pd.colors.lime`, `context.pd.type.body`.
extension PdThemeContext on BuildContext {
  PdThemeView get pd => PdThemeView.of(this);
}
