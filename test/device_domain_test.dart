import 'dart:math';

import 'package:family_emergency_app/core/domain/device_policies.dart';
import 'package:family_emergency_app/models/paired_device.dart';
import 'package:family_emergency_app/services/device_heartbeat_controller.dart';
import 'package:family_emergency_app/services/device_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_device_service.dart';

class _MemoryInstallationStore implements InstallationIdStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'installation identity is stable and survives service recreation',
    () async {
      final store = _MemoryInstallationStore();
      final first = DeviceService(
        installationStore: store,
        random: Random(7),
        metadata: const DeviceMetadata(
          name: 'Test device',
          platform: 'android',
          appVersion: '1.0.0',
        ),
      );
      final id = await first.currentInstallationId();
      final second = DeviceService(
        installationStore: store,
        random: Random(99),
        metadata: const DeviceMetadata(
          name: 'Test device',
          platform: 'android',
          appVersion: '1.0.0',
        ),
      );
      expect(id, hasLength(DevicePolicy.installationIdLength));
      expect(await second.currentInstallationId(), id);
      expect(RegExp(r'^[A-Z2-9]{32}$').hasMatch(id), isTrue);
    },
  );

  test('pairing code parsing accepts only the device pairing flow', () {
    expect(DevicePairingCodePolicy.validate(fakePairingCode), isNull);
    expect(
      DevicePairingCodePolicy.extract(
        'familyemergency://pair-device?code=$fakePairingCode',
      ),
      fakePairingCode,
    );
    expect(
      DevicePairingCodePolicy.extract(
        'familyemergency://join?code=$fakePairingCode',
      ),
      isNull,
    );
    expect(DevicePairingCodePolicy.validate('PAIR-1234'), isNotNull);
  });

  test('presence transitions use one heartbeat policy and revocation wins', () {
    final now = DateTime.utc(2026, 9, 11, 12);
    PairedDevice at(Duration age, {DevicePairingStatus? status}) => fakeDevice(
      current: false,
      status: status ?? DevicePairingStatus.paired,
      heartbeat: now.subtract(age),
    );
    expect(
      at(const Duration(minutes: 5)).presenceAt(now),
      DevicePresence.online,
    );
    expect(
      at(const Duration(minutes: 30)).presenceAt(now),
      DevicePresence.stale,
    );
    expect(
      at(const Duration(minutes: 90)).presenceAt(now),
      DevicePresence.offline,
    );
    expect(
      at(
        const Duration(minutes: 1),
        status: DevicePairingStatus.revoked,
      ).presenceAt(now),
      DevicePresence.revoked,
    );
  });

  test('heartbeat controller registers once and pulses on resume', () async {
    final service = FakeDeviceService();
    final controller = DeviceHeartbeatController(service: service);
    await controller.start();
    await controller.start();
    expect(service.registrationCalls, 1);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(service.heartbeatCalls, 1);
    await controller.dispose().timeout(const Duration(seconds: 1));
    await service.dispose().timeout(const Duration(seconds: 1));
  });

  test(
    'remote current-device revocation invokes the logout callback',
    () async {
      final service = FakeDeviceService();
      final controller = DeviceHeartbeatController(service: service);
      var logoutCalls = 0;
      await controller.start(onCurrentDeviceRevoked: () async => logoutCalls++);
      service.currentDeviceController.add(
        fakeDevice(status: DevicePairingStatus.revoked),
      );
      await Future<void>.delayed(Duration.zero);
      expect(logoutCalls, 1);
      await controller.dispose();
      await service.dispose();
    },
  );
}
