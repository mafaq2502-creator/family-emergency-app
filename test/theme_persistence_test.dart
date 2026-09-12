import 'package:family_emergency_app/core/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Light, Dark and System theme choices persist across initialization',
    () async {
      SharedPreferences.setMockInitialValues({});

      await setAppThemeMode(ThemeMode.dark);
      appThemeMode.value = ThemeMode.system;
      await initializeThemeMode();
      expect(appThemeMode.value, ThemeMode.dark);

      await setAppThemeMode(ThemeMode.light);
      appThemeMode.value = ThemeMode.system;
      await initializeThemeMode();
      expect(appThemeMode.value, ThemeMode.light);

      await setAppThemeMode(ThemeMode.system);
      appThemeMode.value = ThemeMode.dark;
      await initializeThemeMode();
      expect(appThemeMode.value, ThemeMode.system);
    },
  );
}
