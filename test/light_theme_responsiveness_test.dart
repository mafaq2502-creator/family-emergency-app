import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:family_emergency_app/features/auth/presentation/onboarding/intro_flow.dart';
import 'package:family_emergency_app/features/devices/presentation/device_screens.dart';
import 'package:family_emergency_app/features/groups/presentation/share_circle_screen.dart';
import 'package:family_emergency_app/features/groups/presentation/join_circle_screen.dart';
import 'package:family_emergency_app/features/groups/presentation/join_requests_screen.dart';
import 'package:family_emergency_app/features/profile/presentation/account_settings_screen.dart';
import 'package:family_emergency_app/features/progress/presentation/progress_detail_screens.dart';
import 'package:family_emergency_app/models/circle_role.dart';
import 'package:family_emergency_app/models/circle_join_request.dart';
import 'package:family_emergency_app/models/family_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_circle_join_service.dart';
import 'support/fake_device_service.dart';

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
    addTearDown(tester.view.resetViewInsets);
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
    addTearDown(tester.view.resetViewInsets);
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
        DeviceDetailScreen(
          memberName: longName,
          device: fakeDevice(name: longName),
          deviceService: FakeDeviceService(),
          accountDevice: true,
        ),
        size,
      );
      await pumpAt(
        tester,
        DevicePairingScreen(
          group: const FamilyGroup(
            id: 'circle-device-test',
            name: 'Family',
            ownerId: 'owner-1',
            role: CircleRole.owner,
            memberIds: ['owner-1', 'member-1'],
          ),
          memberUserId: 'member-1',
          memberName: longName,
          deviceService: FakeDeviceService(),
        ),
        size,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pump();
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
        onSaveAddress: (_) async => true,
        relationship: 'Self',
        relationships: const ['Self', 'Father', 'Mother'],
        onSave: (_, _) async => true,
        onUpdatePassword: () {},
      ),
      const Size(320, 568),
    );
    expect(find.text('Save Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share circle QR and invite tabs fit compact phones', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpAt(
      tester,
      ShareCircleScreen(
        joinService: FakeCircleJoinService(),
        group: const FamilyGroup(
          id: 'circle-1',
          name: 'A very long family Circle name used for responsive testing',
          ownerId: 'owner-1',
          role: CircleRole.owner,
        ),
      ),
      const Size(320, 568),
    );
    expect(find.text('Create a secure invitation'), findsOneWidget);
    await tester.tap(find.text('Generate Invitation'));
    await tester.pumpAndSettle();
    expect(
      find.text('Scan to preview this Circle and request approval.'),
      findsOneWidget,
    );
    expect(find.text(fakeInviteCode), findsNothing);
    expect(find.text('ABCD-EFGH-JKLM-NPQR-STUV-2345'), findsNothing);
    await tester.tap(find.text('Share Link'));
    await tester.pump();
    expect(
      find.text('https://familyemergencyapp.web.app/join?code=$fakeInviteCode'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Phase 6 join and review screens fit with larger text', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    const group = FamilyGroup(
      id: 'circle-1',
      name: 'A very long family Circle name used for responsive testing',
      ownerId: 'owner-1',
      role: CircleRole.owner,
    );
    const request = CircleJoinRequest(
      id: 'requester-1',
      circleId: 'circle-1',
      userUid: 'requester-1',
      inviteId: fakeInviteCode,
      displayName:
          'A very long registered requester name for layout verification',
      relationship: 'A very long relationship description',
      email: 'requester.with.a.long.address@example.test',
      role: CircleRole.adult,
      status: JoinRequestStatus.pending,
    );
    for (final size in const [Size(320, 568), Size(430, 932)]) {
      await pumpAt(
        tester,
        JoinCircleScreen(
          key: ValueKey('join-$size'),
          joinService: FakeCircleJoinService(),
        ),
        size,
      );
      await pumpAt(
        tester,
        JoinRequestsScreen(
          key: ValueKey('requests-$size'),
          group: group,
          joinService: FakeCircleJoinService(requests: const [request]),
        ),
        size,
      );
      expect(tester.takeException(), isNull);
    }
  });

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
