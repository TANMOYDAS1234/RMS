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
