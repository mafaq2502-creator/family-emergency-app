import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:family_emergency_app/features/auth/presentation/onboarding/intro_flow.dart';
import 'package:family_emergency_app/features/devices/presentation/device_screens.dart';
import 'package:family_emergency_app/features/groups/presentation/share_circle_screen.dart';
import 'package:family_emergency_app/features/profile/presentation/account_settings_screen.dart';
import 'package:family_emergency_app/features/progress/presentation/progress_detail_screens.dart';
import 'package:family_emergency_app/models/circle_role.dart';
import 'package:family_emergency_app/models/family_group.dart';
import 'package:family_emergency_app/models/family_member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Widget screen, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(FamilyEmergencyApp(home: screen));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocaleTestValue();
  });

  testWidgets('intro screens fit compact and large phones', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in const [Size(320, 568), Size(430, 932)]) {
      await pumpAt(
        tester,
        IntroFlow(key: ValueKey(size), onFinished: () {}),
        size,
      );
      expect(find.text('Keep Your Family Close'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Safer Days, Brighter Tomorrows'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('progress and device detail screens fit mobile widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const longName = 'A very long family member name for layout verification';
    for (final size in const [Size(320, 568), Size(430, 932)]) {
      await pumpAt(
        tester,
        const ScreenTimeDetailScreen(memberName: longName),
        size,
      );
      await pumpAt(
        tester,
        const CheckInHistoryScreen(memberName: longName),
        size,
      );
      await pumpAt(
        tester,
        const DeviceDetailScreen(memberName: longName),
        size,
      );
      await pumpAt(
        tester,
        const DevicePairingScreen(
          member: FamilyMember(
            name: longName,
            status: 'Pending',
            relation: 'Child',
          ),
        ),
        size,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('account settings scrolls safely on a compact phone', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpAt(
      tester,
      AccountSettingsScreen(
        initialName: 'Afaq Ahmed',
        email: 'a.very.long.email.address@example.com',
        phone: '+92 300 1234567',
        country: 'PK  +92',
        relationship: 'Self',
        relationships: const ['Self', 'Father', 'Mother'],
        onSave: (_, _) async => true,
        onUpdatePassword: () {},
      ),
      const Size(320, 568),
    );
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'share circle tabs and truthful empty states fit compact phones',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpAt(
        tester,
        const ShareCircleScreen(
          group: FamilyGroup(
            id: 'circle-1',
            name: 'A very long family Circle name used for responsive testing',
            ownerId: 'owner-1',
            role: CircleRole.owner,
          ),
        ),
        const Size(320, 568),
      );
      expect(find.text('QR sharing unavailable'), findsOneWidget);
      await tester.tap(find.text('Invite Code'));
      await tester.pump();
      expect(find.text('Generate an invitation code'), findsOneWidget);
      await tester.tap(find.text('Invite Link'));
      await tester.pump();
      expect(find.text('Joining link unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('progress period selectors include yesterday and change state', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpAt(
      tester,
      const ScreenTimeDetailScreen(memberName: 'Ali'),
      const Size(320, 568),
    );
    expect(find.text('Yesterday'), findsOneWidget);
    await tester.tap(find.text('Yesterday'));
    await tester.pump();
    expect(find.textContaining('Yesterday'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
