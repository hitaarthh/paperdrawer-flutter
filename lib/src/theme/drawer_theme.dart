import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

const drawerLime = Color(0xffd4f25a);
const drawerInk = Color(0xff0e1311);
const drawerPaper = Color(0xfffbfaf6);
const drawerOrange = Color(0xffff8a4c);

@immutable
class DrawerColors {
  const DrawerColors({
    required this.page,
    required this.panel,
    required this.text,
    required this.muted,
    required this.line,
    required this.marker,
    required this.grain,
  });

  final Color page;
  final Color panel;
  final Color text;
  final Color muted;
  final Color line;
  final Color marker;
  final Color grain;

  static const light = DrawerColors(
    page: Color(0xfff7f3df),
    panel: Color(0xfffffcf1),
    text: Color(0xff20241a),
    muted: Color(0xff565947),
    line: Color(0xffcdc6af),
    marker: Color(0xff465b16),
    grain: Color(0x0c4d3a0e),
  );

  static const dark = DrawerColors(
    page: drawerInk,
    panel: Color(0xff1a211e),
    text: Color(0xfff2f4ef),
    muted: Color(0xffb7c1bb),
    line: Color(0xff3e4843),
    marker: drawerLime,
    grain: Color(0x0affffff),
  );
}

extension DrawerThemeContext on BuildContext {
  DrawerColors get palette => Theme.of(this).brightness == Brightness.dark
      ? DrawerColors.dark
      : DrawerColors.light;
}

TextStyle monoLabel(Color color, {double size = 11}) => TextStyle(
  color: color,
  fontFamily: 'JetBrainsMono',
  fontSize: size,
  fontWeight: FontWeight.w500,
  letterSpacing: 1.1,
);

TextStyle displayStyle(Color color, double size) => TextStyle(
  color: color,
  fontFamily: 'Bricolage',
  fontVariations: const [FontVariation('wght', 750)],
  height: 1.02,
  letterSpacing: -size * .044,
  fontSize: size,
);

ThemeData drawerTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = dark ? DrawerColors.dark : DrawerColors.light;
  final schema = ColorScheme.fromSeed(
    seedColor: colors.marker,
    brightness: brightness,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: schema.copyWith(
      primary: colors.marker,
      onPrimary: dark ? drawerInk : drawerPaper,
      surface: colors.panel,
      onSurface: colors.text,
      onSurfaceVariant: colors.muted,
      outline: colors.line,
    ),
    scaffoldBackgroundColor: colors.page,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: colors.text,
      displayColor: colors.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.page,
      foregroundColor: colors.text,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: drawerLime,
        foregroundColor: drawerInk,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: colors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.panel,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: colors.line),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? drawerPaper : drawerInk,
      contentTextStyle: TextStyle(color: dark ? drawerInk : drawerPaper),
    ),
  );
}
