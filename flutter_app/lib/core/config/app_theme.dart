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
const Color amber = Color(0xFFFDCB6E);
const Color crimson = Color(0xFFE17055);
const Color textPrimary = Color(0xFFF5F6FA);
const Color textSecondary = Color(0xFF8A9BB0);
const Color dividerColor = Color(0xFF2F3A47);

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
