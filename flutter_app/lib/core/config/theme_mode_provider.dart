// ─── Theme Mode Provider ─────────────────────────────────────────────────────
//
// Persists the user's theme choice (system / light / dark) in
// SharedPreferences and exposes it via Riverpod so main.dart's
// MaterialApp can wire it into `themeMode:`.
//
// Default is `ThemeMode.dark` — first launch keeps the brand-defining
// copper-on-slate look. The user can flip to System or Light via the
// switcher in the Profile screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

class _ThemeModeNotifier extends StateNotifier<ThemeMode> {
  _ThemeModeNotifier() : super(ThemeMode.dark) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kThemeModeKey);
      if (raw == null) return;
      state = ThemeMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => ThemeMode.dark,
      );
    } catch (_) {
      // Defaults stay — SharedPreferences may fail on first cold start.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeModeKey, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider =
    StateNotifierProvider<_ThemeModeNotifier, ThemeMode>((_) => _ThemeModeNotifier());
