import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';
import 'type.dart';

ThemeData pdTheme() => ThemeData(
  brightness: Brightness.dark,
  platform: TargetPlatform.iOS,
  fontFamily: PdType.sans,
  scaffoldBackgroundColor: Pd.bg,
  canvasColor: Pd.bg,
  colorScheme: const ColorScheme.dark(
    primary: Pd.lime,
    onPrimary: Pd.onLime,
    surface: Pd.surface1,
    onSurface: Pd.text,
    error: Pd.signal,
    outline: Pd.line,
  ),
  cupertinoOverrideTheme: pdCupertinoTheme(),
  splashFactory: NoSplash.splashFactory,
  highlightColor: Pd.limeTint,
  focusColor: Pd.limeTint,
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(textStyle: PdType.monoButton),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Pd.lime,
    selectionColor: Pd.limeTint,
    selectionHandleColor: Pd.lime,
  ),
);

CupertinoThemeData pdCupertinoTheme() => CupertinoThemeData(
  brightness: Brightness.dark,
  primaryColor: Pd.lime,
  primaryContrastingColor: Pd.onLime,
  barBackgroundColor: Pd.bg,
  scaffoldBackgroundColor: Pd.bg,
  textTheme: CupertinoTextThemeData(
    primaryColor: Pd.lime,
    textStyle: PdType.body,
    actionTextStyle: PdType.bodyStrong.copyWith(color: Pd.lime),
    navTitleTextStyle: PdType.navInline,
    navLargeTitleTextStyle: PdType.largeTitle,
    navActionTextStyle: PdType.navBack.copyWith(color: Pd.lime),
    tabLabelTextStyle: PdType.tabLabel,
    dateTimePickerTextStyle: PdType.body,
  ),
);
