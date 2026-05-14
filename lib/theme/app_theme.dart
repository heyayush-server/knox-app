import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Knox AMOLED Design System
/// Inspired by Samsung Knox & OneUI with cyber-security aesthetics
class AppTheme {
  // ─── Color Palette ────────────────────────────────────────────────────────
  static const Color black = Color(0xFF000000);
  static const Color surface1 = Color(0xFF0A0A0A);
  static const Color surface2 = Color(0xFF111111);
  static const Color surface3 = Color(0xFF1A1A1A);
  static const Color surface4 = Color(0xFF222222);

  // Electric blue accent — the Knox signature color
  static const Color accent = Color(0xFF00A8FF);
  static const Color accentGlow = Color(0x4400A8FF);
  static const Color accentDim = Color(0xFF0066CC);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanGlow = Color(0x3300E5FF);

  // Text
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFF999999);
  static const Color textTertiary = Color(0xFF555555);
  static const Color textAccent = Color(0xFF00A8FF);

  // Security / danger
  static const Color danger = Color(0xFFFF3B30);
  static const Color dangerGlow = Color(0x44FF3B30);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color success = Color(0xFF30D158);

  // Dividers
  static const Color divider = Color(0xFF1E1E1E);
  static const Color border = Color(0xFF2A2A2A);

  // ─── Text Styles ──────────────────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: 'SamsungOne',
    fontSize: 32,
    fontWeight: FontWeight.w300,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: 'SamsungOne',
    fontSize: 24,
    fontWeight: FontWeight.w300,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.1,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.15,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    letterSpacing: 0.1,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.1,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
    letterSpacing: 1.2,
  );

  static const TextStyle pinDigit = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w200,
    color: textPrimary,
    letterSpacing: 8,
  );

  static const TextStyle monoSmall = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: 0.5,
  );

  // ─── Border Radius ────────────────────────────────────────────────────────
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 14.0;
  static const double radiusLarge = 20.0;
  static const double radiusXL = 28.0;
  static const double radiusCircle = 100.0;

  // ─── Spacing ──────────────────────────────────────────────────────────────
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ─── Material Theme ───────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: cyan,
        surface: surface2,
        error: danger,
        onPrimary: black,
        onSecondary: black,
        onSurface: textPrimary,
        onError: textPrimary,
        outline: border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: titleLarge,
        iconTheme: IconThemeData(color: textPrimary, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardTheme(
        color: surface2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: border, width: 0.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return const Color(0xFF555555);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentGlow;
          return const Color(0xFF2A2A2A);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      textTheme: const TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        labelLarge: labelLarge,
      ),
      iconTheme: const IconThemeData(color: textPrimary, size: 20),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 0.5,
        space: 0,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        iconColor: textSecondary,
        titleTextStyle: bodyLarge,
        subtitleTextStyle: bodyMedium,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}


