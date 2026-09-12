import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.system);

const _themePreferenceKey = 'app_theme_mode';

Future<void> initializeThemeMode() async {
  try {
    final saved = (await SharedPreferences.getInstance()).getString(
      _themePreferenceKey,
    );
    appThemeMode.value = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  } catch (_) {
    appThemeMode.value = ThemeMode.system;
  }
}

Future<void> setAppThemeMode(ThemeMode mode) async {
  appThemeMode.value = mode;
  try {
    await (await SharedPreferences.getInstance()).setString(
      _themePreferenceKey,
      mode.name,
    );
  } catch (_) {
    // The selected mode still applies for the current session.
  }
}
