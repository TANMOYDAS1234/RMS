// ─── App Theme ───────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ── Color Palette ─────────────────────────────────────────────────────────────
const Color slateBg = Color(0xFF1E2328);
const Color slateCard = Color(0xFF252B32);
const Color slateSurface = Color(0xFF2D3440);
const Color copperAccent = Color(0xFFD35400);
const Color copperLight = Color(0xFFE8722A);
const Color roseGold = Color(0xFFE29578);
const Color emerald = Color(0xFF00B894);
const Color emeraldDark = Color(0xFF26997C);
const Color amber = Color(0xFFFDCB6E);
const Color crimson = Color(0xFFE17055);
const Color textPrimary = Color(0xFFF5F6FA);
const Color textSecondary = Color(0xFF8A9BB0);
const Color dividerColor = Color(0xFF2F3A47);

// ── Gradients ────────────────────────────────────────────────────────────────
// Used by all primary-action buttons across the app. Centralized so we
// don't have `[copperAccent, Color(0xFFE8722A)]` literally repeated in
// half a dozen files.
const LinearGradient copperGradient = LinearGradient(
  colors: [copperAccent, copperLight],
);

/// Resolve-style success gradient (emerald → darker emerald).
const LinearGradient emeraldGradient = LinearGradient(
  colors: [emerald, emeraldDark],
);

/// Destructive-action gradient for delete / refund / force-close.
const LinearGradient dangerGradient = LinearGradient(
  colors: [crimson, copperLight],
);

ThemeData buildAppTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: slateBg,
      colorScheme: const ColorScheme.dark(
        primary: copperAccent,
        secondary: roseGold,
        surface: slateCard,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      fontFamily: 'SF Pro Display',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: slateCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

// ── Light theme ─────────────────────────────────────────────────────────────
//
// Hybrid look — paper-white page backgrounds with the copper-on-slate
// cards preserved. Same primary palette so the brand stays consistent
// across the two modes. The dark slate cards still ship from their own
// const colors above; only the Scaffold + AppBar + Material dialogs and
// inputs follow the brightness flip. That makes the switch land
// instantly for the OS-controlled chrome without forcing every custom
// widget to refactor against Theme.of(context).
const Color paperBg = Color(0xFFF7F4EE);
const Color paperCard = Color(0xFFFFFFFF);
const Color paperBorder = Color(0xFFE2DCCF);
const Color inkPrimary = Color(0xFF1F1B16);
const Color inkSecondary = Color(0xFF6B6357);

/// Theme-aware brand colour accessor.
///
/// New screens (and refactored old ones) read brand surfaces through
/// `BrandColors.of(context)` instead of the dark-only top-level
/// constants. In Light mode the page bg flips to paper, cards to white,
/// text to ink. Copper accents stay copper either way so the brand
/// reads consistently across the two modes.
///
/// We keep the top-level dark consts (`slateBg`, `slateCard`, etc.)
/// alive so existing code keeps compiling — incremental migration is
/// cheaper than a 50-file refactor in one go.
class BrandColors {
  final Color bg;
  final Color card;
  final Color surface;
  final Color textHi;
  final Color textLo;
  final Color divider;
  const BrandColors({
    required this.bg,
    required this.card,
    required this.surface,
    required this.textHi,
    required this.textLo,
    required this.divider,
  });

  static BrandColors of(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    if (isLight) {
      return const BrandColors(
        bg: paperBg,
        card: paperCard,
        surface: Color(0xFFEFE9DD),
        textHi: inkPrimary,
        textLo: inkSecondary,
        divider: paperBorder,
      );
    }
    // Top-level constants are const Color again, so this constructor
    // resolves to a const expression.
    return const BrandColors(
      bg: slateBg,
      card: slateCard,
      surface: slateSurface,
      textHi: textPrimary,
      textLo: textSecondary,
      divider: dividerColor,
    );
  }
}

/// Brightness-aware Theme override for showDatePicker / showDateRangePicker.
///
/// Date pickers ship with a Material default ColorScheme. Wrapping the
/// dialog in a Theme that forces ColorScheme.dark made every label and
/// number white-on-cream when the app was set to Light, so the user
/// couldn't see what they were picking. This helper picks the right
/// brightness off Theme.of(ctx) and keeps copper as the accent either way.
ThemeData datePickerTheme(BuildContext ctx) {
  final isLight = Theme.of(ctx).brightness == Brightness.light;
  if (isLight) {
    return Theme.of(ctx).copyWith(
      colorScheme: const ColorScheme.light(
        primary: copperAccent,
        onPrimary: Colors.white,
        surface: paperCard,
        onSurface: inkPrimary,
      ),
    );
  }
  return Theme.of(ctx).copyWith(
    colorScheme: const ColorScheme.dark(
      primary: copperAccent,
      onPrimary: Colors.white,
      surface: slateCard,
      onSurface: textPrimary,
    ),
  );
}

ThemeData buildLightTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: paperBg,
      colorScheme: const ColorScheme.light(
        primary: copperAccent,
        secondary: roseGold,
        surface: paperCard,
        onPrimary: Colors.white,
        onSurface: inkPrimary,
      ),
      fontFamily: 'SF Pro Display',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: inkPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
        iconTheme: IconThemeData(color: inkPrimary),
      ),
      cardTheme: CardThemeData(
        color: paperCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerColor: paperBorder,
    );
