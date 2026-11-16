import 'package:flutter/material.dart';

/// Adapted from the hotel booking theme in Best-Flutter-UI-Templates.
/// See third_party/Best-Flutter-UI-Templates-LICENSE.
/// Colors and typography follow the Boutique direction in the design guides.
abstract final class FlowerTemplateTheme {
  static const headingFont = 'PlayfairDisplay';
  static const bodyFont = 'BeVietnamPro';
  static const hydrangea = Color(0xFFA7C7E7);
  static const sky = Color(0xFFB6D0E2);
  static const periwinkle = Color(0xFFB8C4E6);
  static const sage = Color(0xFFA8C69F);
  static const peach = Color(0xFFF4A4A4);
  static const navy = Color(0xFF243B53);
  static const deepSage = Color(0xFF4A6B5D);
  static const ink = Color(0xFF333740);
  static const muted = Color(0xFF687487);
  static const canvas = Color(0xFFFAF9F6);
  static const ice = Color(0xFFF2F6FA);
  static const line = Color(0xFFDCE6EE);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: hydrangea,
      primary: navy,
      onPrimary: Colors.white,
      secondary: hydrangea,
      onSecondary: navy,
      surface: ice,
      onSurface: ink,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: bodyFont,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: headingFont,
          fontSize: 28,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: headingFont,
          fontSize: 24,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontFamily: headingFont,
          fontSize: 22,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          height: 1.45,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          height: 1.45,
          color: ink,
        ),
        bodySmall: TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          height: 1.45,
          color: muted,
        ),
        labelLarge: TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      scaffoldBackgroundColor: canvas,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: sky,
        foregroundColor: navy,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: headingFont,
          color: navy,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          height: 1.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: ice,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: const Color(0x243B5370),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: navy,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: navy, width: 1.5),
        ),
        hintStyle: const TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: navy,
          minimumSize: const Size(0, 52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: line),
          minimumSize: const Size(0, 50),
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 6,
        extendedTextStyle: TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: hydrangea.withValues(alpha: 0.55),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: bodyFont, fontSize: 12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: hydrangea.withValues(alpha: 0.42),
        side: const BorderSide(color: line),
        shape: const StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(color: line),
    );
  }
}
