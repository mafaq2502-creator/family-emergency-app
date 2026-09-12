import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:family_emergency_app/core/domain/mobile_phone_number.dart';
import 'package:family_emergency_app/core/theme/theme_mode_controller.dart';
import 'package:family_emergency_app/core/widgets/app_bottom_navigation.dart';
import 'package:family_emergency_app/features/auth/presentation/signup_screen.dart';
import 'package:family_emergency_app/features/profile/presentation/account_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_form_test.dart' show FakeAuthActions;

void main() {
  test('mobile numbers normalize once and reject malformed input', () {
    expect(MobilePhoneNumber.normalize('300 1234567', '92'), '+923001234567');
    expect(
      MobilePhoneNumber.normalize('+92 3001234567', '92'),
      '+923001234567',
    );
    expect(
      MobilePhoneNumber.validateLocal('+92 +92 3001234567', '92'),
      isNotNull,
    );
    expect(MobilePhoneNumber.validateLocal('phone123', '92'), isNotNull);
    expect(MobilePhoneNumber.validateLocal('123', '92'), isNotNull);
    expect(
      MobilePhoneNumber.validateLocal('12345678901234567890', '92'),
      isNotNull,
    );
  });

  testWidgets(
    'Sign Up country selection updates the visible code immediately',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'PK'),
          home: SignUpScreen(authService: FakeAuthActions()),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('mobile-country-code')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'United Kingdom');
      await tester.pumpAndSettle();
      await tester.tap(find.text('United Kingdom').last);
      await tester.pumpAndSettle();
      expect(find.text('+44'), findsOneWidget);
      expect(find.text('+92'), findsNothing);
    },
  );

  testWidgets('Account Settings saves an edited phone as E.164', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? savedPhone;
    String? savedIso;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsScreen(
          initialName: 'Test User',
          email: 'test@example.com',
          initialPhone: '+923001234567',
          initialPhoneCountryIso: 'PK',
          relationship: 'Self',
          relationships: const ['Self'],
          onSave: (_, _) async => true,
          onSaveAddress: (_) async => true,
          onSavePhone: (phone, iso, _) async {
            savedPhone = phone;
            savedIso = iso;
            return true;
          },
          onUpdatePassword: () {},
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('mobile-phone-number')),
      '301 7654321',
    );
    final save = find.widgetWithText(ElevatedButton, 'Save Settings');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(savedPhone, '+923017654321');
    expect(savedIso, 'PK');
  });

  testWidgets('dark OFF and disabled switches remain visually distinct', (
    tester,
  ) async {
    appThemeMode.value = ThemeMode.dark;
    addTearDown(() => appThemeMode.value = ThemeMode.system);
    final key = GlobalKey();
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: Scaffold(
          body: Switch(key: key, value: false, onChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final theme = Theme.of(key.currentContext!).switchTheme;
    final off = theme.trackColor!.resolve({});
    final on = theme.trackColor!.resolve({WidgetState.selected});
    final disabled = theme.trackColor!.resolve({WidgetState.disabled});
    expect(off, isNot(Theme.of(key.currentContext!).scaffoldBackgroundColor));
    expect(off, isNot(on));
    expect(disabled, isNot(off));
    expect(theme.thumbColor!.resolve({}), isNot(off));
  });

  testWidgets('bottom navigation order and destination indices stay correct', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavigation(
            selectedIndex: 2,
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );
    final labels = ['Progress', 'Family', 'Home', 'Plan', 'Profile'];
    final x = labels
        .map((label) => tester.getCenter(find.text(label)).dx)
        .toList();
    expect(x, orderedEquals([...x]..sort()));
    await tester.tap(find.text('Progress'));
    expect(selected, 1);
    await tester.tap(find.text('Family'));
    expect(selected, 0);
  });
}
