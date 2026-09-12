import 'package:family_emergency_app/features/auth/domain/auth_destination.dart';
import 'package:family_emergency_app/features/profile/presentation/account_settings_screen.dart';
import 'package:family_emergency_app/models/user_profile.dart';
import 'package:family_emergency_app/core/widgets/country_name_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('country picker shows names before and after selection', (
    tester,
  ) async {
    String selected = 'PK';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CountryNameField(
              countryIso: selected,
              onChanged: (country) =>
                  setState(() => selected = country.countryCode),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pakistan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Canada');
    await tester.pumpAndSettle();
    final countryRow = find.byWidgetPredicate(
      (w) => w is Text && w.data == 'Canada',
    );
    expect(countryRow, findsOneWidget);
    expect(find.text('+1'), findsNothing);
    await tester.tap(countryRow);
    await tester.pumpAndSettle();
    expect(selected, 'CA');
    expect(find.text('Canada'), findsOneWidget);
    expect(find.text('CA'), findsNothing);
  });

  test('completed provider profile does not require a signup phone number', () {
    final profile = UserProfile.fromData(
      uid: 'provider-user',
      data: {
        'name': 'Test User',
        'email': 'test@example.com',
        'relationship': 'Self',
        'profileCompleted': true,
      },
    );
    expect(
      AuthDestinationResolver.resolve(signedIn: true, profile: profile),
      AuthDestination.circleSetup,
    );
  });

  test('address parsing tolerates missing and malformed data', () {
    expect(UserProfile.fromData(uid: 'u', data: {}).address, isEmpty);
    final profile = UserProfile.fromData(
      uid: 'u',
      data: {
        'address': {'city': ' Lahore ', 'line1': 42, 'countryIso': 'PK'},
      },
    );
    expect(profile.address['city'], 'Lahore');
    expect(profile.address['line1'], '');
    expect(profile.address['countryIso'], 'PK');
  });

  testWidgets(
    'address tab uses country names and retains edits after save failure',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, String>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: AccountSettingsScreen(
            initialName: 'Test User',
            email: 'test@example.com',
            relationship: 'Self',
            relationships: const ['Self'],
            initialAddress: const {'city': 'Lahore', 'countryIso': 'PK'},
            onSave: (_, _) async =>
                throw StateError('Personal details were not changed'),
            onSaveAddress: (address) async {
              submitted = address;
              return false;
            },
            onUpdatePassword: () {},
          ),
        ),
      );
      expect(find.text('Phone Number'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Address'));
      await tester.pumpAndSettle();
      expect(find.text('Pakistan'), findsOneWidget);
      expect(find.text('PK'), findsNothing);
      final city = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'City',
      );
      await tester.enterText(city, ' Islamabad ');
      await tester.tap(find.widgetWithText(TextButton, 'Personal'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Address'));
      await tester.pumpAndSettle();
      expect(find.text(' Islamabad '), findsOneWidget);
      await tester.ensureVisible(find.text('Save Settings'));
      await tester.tap(find.text('Save Settings'));
      await tester.pumpAndSettle();
      expect(submitted?['city'], 'Islamabad');
      expect(submitted?['countryIso'], 'PK');
      expect(
        find.text('Changes could not be saved. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile photo is staged until Save Settings succeeds', (
    tester,
  ) async {
    String? savedPhoto;
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSettingsScreen(
          initialName: 'Test User',
          email: 'test@example.com',
          relationship: 'Self',
          relationships: const ['Self'],
          onSave: (_, _) async => true,
          onSaveAddress: (_) async => true,
          pickProfilePhoto: () async => 'draft-profile-photo',
          onSavePhoto: (photo) async {
            savedPhoto = photo;
            return true;
          },
          onUpdatePassword: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('edit-account-profile-photo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-account-profile-photo')));
    await tester.pump();
    expect(savedPhoto, isNull);
    final save = find.widgetWithText(ElevatedButton, 'Save Settings');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(savedPhoto, 'draft-profile-photo');
  });
}
