import 'dart:async';

import 'package:family_emergency_app/features/devices/presentation/device_screens.dart';
import 'package:family_emergency_app/models/circle_role.dart';
import 'package:family_emergency_app/models/family_group.dart';
import 'package:family_emergency_app/models/paired_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_device_service.dart';

const group = FamilyGroup(
  id: 'circle-1',
  name: 'Extended Family Circle',
  ownerId: 'owner-1',
  role: CircleRole.owner,
  memberIds: ['owner-1', 'member-1'],
);

void main() {
  testWidgets('device list identifies current installation from backend data', (
    tester,
  ) async {
    final service = FakeDeviceService();
    await tester.pumpWidget(
      MaterialApp(home: DeviceListScreen(deviceService: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Android device'), findsOneWidget);
    expect(find.text('This Device • Online'), findsOneWidget);
    expect(find.text('Pair This Device to a Circle'), findsOneWidget);
  });

  testWidgets('pairing code screen shows secure QR, code and expiry', (
    tester,
  ) async {
    final service = FakeDeviceService();
    await tester.pumpWidget(
      MaterialApp(home: DevicePairingCodeScreen(deviceService: service)),
    );
    await tester.pump();
    expect(find.text('ABCD-EFGH-JKLM-NPQR-STUV-WX23'), findsOneWidget);
    expect(find.textContaining('Expires in'), findsOneWidget);
    expect(find.text('Cancel Pairing Code'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pairing validates input and prevents duplicate submission', (
    tester,
  ) async {
    final service = FakeDeviceService()
      ..pairingCompleter = Completer<PairedDevice>();
    await tester.pumpWidget(
      MaterialApp(
        home: DevicePairingScreen(
          group: group,
          memberUserId: 'member-1',
          memberName: 'Member One',
          deviceService: service,
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Pair Device'));
    await tester.pump();
    expect(find.text('Enter a pairing code.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), fakePairingCode);
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Pair Device'));
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Pairing…'),
          )
          .onPressed,
      isNull,
    );
    expect(service.pairingCalls, 1);
    service.pairingCompleter!.complete(
      fakeDevice(current: false, status: DevicePairingStatus.paired),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Device paired'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('non-manager cannot query another member device section', (
    tester,
  ) async {
    final service = FakeDeviceService(
      memberDevices: [fakeDevice(current: false)],
    );
    const memberView = FamilyGroup(
      id: 'circle-1',
      name: 'Family',
      ownerId: 'owner-1',
      role: CircleRole.adult,
      memberIds: ['owner-1', 'member-1', 'viewer-1'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MemberDeviceSection(
            group: memberView,
            memberUserId: 'member-1',
            memberName: 'Member',
            viewerId: 'viewer-1',
            deviceService: service,
          ),
        ),
      ),
    );
    expect(find.textContaining('Visible only'), findsOneWidget);
    expect(find.text('Android device'), findsNothing);
  });
}
