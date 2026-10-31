import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand + semantic colours. Teal-green because the app is about taka, and
/// coral for money out so the two never get confused.
abstract final class Palette {
  static const Color taka = Color(0xFF0E9F6E);
  static const Color takaDeep = Color(0xFF0A6E58);
  static const Color expense = Color(0xFFE8575D);
  static const Color income = Color(0xFF0E9F6E);
  static const Color warning = Color(0xFFE9A23B);
  static const Color info = Color(0xFF3C7EDB);

  static const Color lightBg = Color(0xFFF6F7F5);
  static const Color lightInk = Color(0xFF101614);
  static const Color lightMuted = Color(0xFF6C7873);
  static const Color lightLine = Color(0xFFE5E9E3);

  static const Color darkBg = Color(0xFF0B100E);
  static const Color darkSurface = Color(0xFF151B18);
  static const Color darkInk = Color(0xFFECF2EE);
  static const Color darkMuted = Color(0xFF8C9A93);
  static const Color darkLine = Color(0xFF232D28);
}

/// Brightness-aware colour lookups. Screens never hard-code a grey again.
abstract final class AppColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext c) =>
      isDark(c) ? Palette.darkBg : Palette.lightBg;

  static Color surface(BuildContext c) =>
      isDark(c) ? Palette.darkSurface : Colors.white;

  static Color ink(BuildContext c) =>
      isDark(c) ? Palette.darkInk : Palette.lightInk;

  static Color muted(BuildContext c) =>
      isDark(c) ? Palette.darkMuted : Palette.lightMuted;

  static Color line(BuildContext c) =>
      isDark(c) ? Palette.darkLine : Palette.lightLine;

  static Color expense(BuildContext c) => Palette.expense;

  static Color income(BuildContext c) => Palette.income;
}

/// Hind Siliguri carries Latin, Bengali and the ৳ sign, so one family covers
/// the whole app — no fallback chain, no tofu boxes.
const String kFontFamily = 'HindSiliguri';

ThemeData buildAppTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  final Color ink = isDark ? Palette.darkInk : Palette.lightInk;
  final Color muted = isDark ? Palette.darkMuted : Palette.lightMuted;

  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: Palette.taka,
    brightness: brightness,
  ).copyWith(
    surface: isDark ? Palette.darkBg : Palette.lightBg,
    error: Palette.expense,
  );

  final TextTheme text = Typography.blackMountainView
      .apply(fontFamily: kFontFamily, bodyColor: ink, displayColor: ink)
      .copyWith(
        displaySmall: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: ink,
        ),
        titleSmall: TextStyle(
          fontFamily: kFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: muted,
        ),
        bodyMedium: TextStyle(fontFamily: kFontFamily, fontSize: 15, color: ink),
        bodySmall: TextStyle(fontFamily: kFontFamily, fontSize: 13, color: ink),
        labelSmall: TextStyle(fontFamily: kFontFamily, fontSize: 11.5, color: muted),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    scaffoldBackgroundColor: isDark ? Palette.darkBg : Palette.lightBg,
    textTheme: text,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? Palette.darkBg : Palette.lightBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      iconTheme: IconThemeData(color: ink, size: 22),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? Palette.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? Palette.darkLine.withValues(alpha: 0.45) : Colors.white,
      hintStyle: TextStyle(fontFamily: kFontFamily, color: muted, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.taka, width: 1.4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? Palette.darkInk : Palette.lightInk,
      contentTextStyle: TextStyle(fontFamily: kFontFamily, color: isDark ? Palette.darkBg : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? Palette.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

/// Dark status-bar icons on the light theme and vice versa.
void applySystemUiFor(Brightness brightness) {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: brightness == Brightness.dark
          ? Palette.darkBg
          : Palette.lightBg,
      systemNavigationBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    ),
  );
}
