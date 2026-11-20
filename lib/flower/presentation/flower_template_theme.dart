import 'package:flutter/material.dart';

/// Adapted from the hotel booking theme in Best-Flutter-UI-Templates.
/// See third_party/Best-Flutter-UI-Templates-LICENSE.
/// Warm florist palette: sage green, blush pink and cream, with navy kept for
/// primary actions. Widgets read colours through `context.palette` so light
/// and dark mode both work; the constants below are fixed brand colours for
/// surfaces that must always look the same (shared invoice, toasts).
abstract final class FlowerTemplateTheme {
  static const headingFont = 'Nunito';
  static const bodyFont = 'BeVietnamPro';
  static const hydrangea = Color(0xFFA7C7E7);
  static const sage = Color(0xFFA8C69F);
  static const peach = Color(0xFFF4A4A4);
  static const navy = Color(0xFF243B53);
  static const deepSage = Color(0xFF4A6B5D);
  static const ink = Color(0xFF2F3437);
  static const muted = Color(0xFF6B716D);
  static const canvas = Color(0xFFFBF7F2);
  static const line = Color(0xFFEADFD6);

  static ThemeData light() => _build(FlowerPalette.light, Brightness.light);

  static ThemeData dark() => _build(FlowerPalette.dark, Brightness.dark);

  static ThemeData _build(FlowerPalette p, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: sage,
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.blush,
      onSecondary: p.onBlush,
      tertiary: p.accent,
      surface: p.card,
      onSurface: p.ink,
      outline: p.line,
    );
    TextStyle heading(double size) => TextStyle(
      fontFamily: headingFont,
      fontSize: size,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: p.ink,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: bodyFont,
      extensions: [p],
      textTheme: TextTheme(
        headlineLarge: heading(28),
        headlineMedium: heading(24),
        titleLarge: heading(22),
        titleMedium: TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: bodyFont,
          fontSize: 16,
          height: 1.45,
          color: p.ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          height: 1.45,
          color: p.ink,
        ),
        bodySmall: TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          height: 1.45,
          color: p.muted,
        ),
        labelLarge: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      scaffoldBackgroundColor: p.canvas,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.canvas,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: headingFont,
          color: p.ink,
          fontWeight: FontWeight.w700,
          fontSize: 20,
          height: 1.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: brightness == Brightness.dark ? 0 : 1.5,
        shadowColor: const Color(0x1F5A4636),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: brightness == Brightness.dark
              ? BorderSide(color: p.line)
              : BorderSide.none,
        ),
      ),
      // Off switches: no track fill (it blended into the card), a clear
      // outline and thumb instead. On state keeps the Material defaults.
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? null : Colors.transparent,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? null : p.muted,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? null : p.muted,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.primary,
        textColor: p.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        modalBackgroundColor: p.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.field,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: p.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: p.onPrimary,
          backgroundColor: p.primary,
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
          foregroundColor: p.primary,
          side: BorderSide(color: p.line),
          minimumSize: const Size(0, 50),
          shape: const StadiumBorder(),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 4,
        extendedTextStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.card,
        indicatorColor: p.blush,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? p.onBlush : p.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(fontFamily: bodyFont, fontSize: 12, color: p.ink),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.field,
        selectedColor: p.blush,
        side: BorderSide(color: p.line),
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(color: p.line),
    );
  }
}

/// Colours that change between light and dark mode.
@immutable
class FlowerPalette extends ThemeExtension<FlowerPalette> {
  const FlowerPalette({
    required this.canvas,
    required this.card,
    required this.field,
    required this.ink,
    required this.muted,
    required this.line,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.blush,
    required this.onBlush,
    required this.isDark,
  });

  static const light = FlowerPalette(
    canvas: FlowerTemplateTheme.canvas,
    card: Color(0xFFFFFFFF),
    field: Color(0xFFFFFFFF),
    ink: FlowerTemplateTheme.ink,
    muted: FlowerTemplateTheme.muted,
    line: FlowerTemplateTheme.line,
    primary: FlowerTemplateTheme.navy,
    onPrimary: Color(0xFFFFFFFF),
    accent: FlowerTemplateTheme.deepSage,
    blush: Color(0xFFF7DCDA),
    onBlush: Color(0xFF6E3B42),
    isDark: false,
  );

  static const dark = FlowerPalette(
    canvas: Color(0xFF141715),
    card: Color(0xFF1E2320),
    field: Color(0xFF252B27),
    ink: Color(0xFFECE8E2),
    muted: Color(0xFFA4ABA6),
    line: Color(0xFF343B37),
    primary: Color(0xFFA9C1DC),
    onPrimary: Color(0xFF132232),
    accent: Color(0xFF9FC6A9),
    blush: Color(0xFF4D3236),
    onBlush: Color(0xFFF7DCDA),
    isDark: true,
  );

  final Color canvas;
  final Color card;
  final Color field;
  final Color ink;
  final Color muted;
  final Color line;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color blush;
  final Color onBlush;
  final bool isDark;

  /// Lightens fixed status/brand colours so they stay readable on dark cards.
  Color adapt(Color color) =>
      isDark ? Color.lerp(color, const Color(0xFFFFFFFF), 0.5)! : color;

  @override
  FlowerPalette copyWith() => this;

  @override
  FlowerPalette lerp(FlowerPalette? other, double t) {
    if (other == null) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return FlowerPalette(
      canvas: mix(canvas, other.canvas),
      card: mix(card, other.card),
      field: mix(field, other.field),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      accent: mix(accent, other.accent),
      blush: mix(blush, other.blush),
      onBlush: mix(onBlush, other.onBlush),
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension FlowerPaletteContext on BuildContext {
  FlowerPalette get palette =>
      Theme.of(this).extension<FlowerPalette>() ?? FlowerPalette.light;
}
