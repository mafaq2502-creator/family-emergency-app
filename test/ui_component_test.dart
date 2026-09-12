import 'dart:typed_data';

import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:family_emergency_app/core/theme/app_typography.dart';
import 'package:family_emergency_app/core/theme/theme_mode_controller.dart';
import 'package:family_emergency_app/core/widgets/bounded_dropdown_form_field.dart';
import 'package:family_emergency_app/core/widgets/light_ui.dart';
import 'package:family_emergency_app/core/widgets/profile_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'profile image data supports stored JPEGs and rejects invalid sources',
    () {
      final encoded = ProfileImageData.encodeJpeg(
        Uint8List.fromList([1, 2, 3]),
      );

      expect(encoded, startsWith('data:image/jpeg;base64,'));
      expect(ProfileImageData.provider(encoded), isA<MemoryImage>());
      expect(ProfileImageData.provider('data:image/jpeg;base64,%%%'), isNull);
      expect(ProfileImageData.provider('file:///private/photo.jpg'), isNull);
      expect(
        ProfileImageData.provider('https://example.com/photo.jpg'),
        isA<NetworkImage>(),
      );
    },
  );

  testWidgets('dropdown popup is constrained to its field width', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: BoundedDropdownFormField<String>(
                initialValue: 'one',
                items: const [
                  DropdownMenuItem(value: 'one', child: Text('One')),
                  DropdownMenuItem(
                    value: 'two',
                    child: Text('A deliberately long second option'),
                  ),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('One'));
    await tester.pumpAndSettle();

    final popup = tester.getRect(find.byType(Scrollable).last);
    expect(popup.width, lessThanOrEqualTo(240));
  });

  testWidgets('field labels use one emphasized theme style', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final themeKey = GlobalKey();
      await tester.pumpWidget(
        FamilyEmergencyApp(
          home: Scaffold(
            body: SizedBox(key: themeKey, child: const TextField()),
          ),
        ),
      );
      appThemeMode.value = mode;
      await tester.pumpAndSettle();
      final style = Theme.of(themeKey.currentContext!)
          .inputDecorationTheme
          .labelStyle!;
      expect(style.fontSize, AppTypography.fieldLabel);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 1.2);
    }
    appThemeMode.value = ThemeMode.system;
  });

  testWidgets('screen titles use one toolbar placement', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final themeKey = GlobalKey();
      await tester.pumpWidget(
        FamilyEmergencyApp(
          home: Scaffold(
            key: themeKey,
            appBar: AppBar(title: const Text('Page')),
          ),
        ),
      );
      appThemeMode.value = mode;
      await tester.pumpAndSettle();
      final appBarTheme = Theme.of(themeKey.currentContext!).appBarTheme;
      expect(appBarTheme.toolbarHeight, 64);
      expect(appBarTheme.titleSpacing, 16);
      expect(appBarTheme.centerTitle, isFalse);
    }
    appThemeMode.value = ThemeMode.system;
  });

  testWidgets('dialog close discards temporary field edits', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var saves = 0;
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AppAlertDialog(
                  title: const Text('Edit value'),
                  content: TextField(controller: controller),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        saves++;
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'unsaved');
    await tester.tap(find.byKey(const Key('dialog-close')));
    await tester.pumpAndSettle();

    expect(saves, 0);
    expect(find.text('Edit value'), findsNothing);
  });
}
