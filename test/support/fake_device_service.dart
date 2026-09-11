import 'dart:async';

import 'package:family_emergency_app/models/device_pairing_request.dart';
import 'package:family_emergency_app/models/family_group.dart';
import 'package:family_emergency_app/models/paired_device.dart';
import 'package:family_emergency_app/services/device_service.dart';

const fakeInstallationId = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const fakePairingCode = 'ABCDEFGHJKLMNPQRSTUVWX23';

PairedDevice fakeDevice({
  String id = fakeInstallationId,
  String userId = 'member-1',
  String name = 'Android device',
  bool current = true,
  DevicePairingStatus status = DevicePairingStatus.registered,
  DateTime? heartbeat,
}) => PairedDevice(
  id: id,
  installationId: fakeInstallationId,
  userId: userId,
  name: name,
  model: 'Not reported',
  platform: 'android',
  appVersion: '1.0.0',
  pairingStatus: status,
  isCurrentDevice: current,
  registeredAt: DateTime.utc(2026, 9, 11, 12),
  lastSeenAt: heartbeat ?? DateTime.now().toUtc(),
  lastHeartbeatAt: heartbeat ?? DateTime.now().toUtc(),
);

class FakeDeviceService implements DeviceActions {
  FakeDeviceService({
    PairedDevice? registration,
    List<PairedDevice>? myDevices,
    List<PairedDevice>? memberDevices,
    DevicePairingRequest? pairingRequest,
  }) : registration = registration ?? fakeDevice(),
       myDevices = myDevices ?? [registration ?? fakeDevice()],
       memberDevices = memberDevices ?? const [],
       pairingRequest =
           pairingRequest ??
           DevicePairingRequest(
             code: fakePairingCode,
             ownerUserId: 'member-1',
             installationId: fakeInstallationId,
             deviceName: 'Android device',
             platform: 'android',
             appVersion: '1.0.0',
             status: DevicePairingRequestStatus.active,
             expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
           );

  final PairedDevice registration;
  final List<PairedDevice> myDevices;
  final List<PairedDevice> memberDevices;
  final DevicePairingRequest pairingRequest;
  Object? registrationError;
  Object? pairingError;
  Completer<PairedDevice>? pairingCompleter;
  final currentDeviceController = StreamController<PairedDevice?>.broadcast();
  int registrationCalls = 0;
  int heartbeatCalls = 0;
  int pairingCalls = 0;
  int renameCalls = 0;
  int revokeCalls = 0;
  int unpairCalls = 0;

  @override
  Future<String> currentInstallationId() async => fakeInstallationId;

  @override
  Future<PairedDevice> registerCurrentDevice() async {
    registrationCalls++;
    if (registrationError != null) throw registrationError!;
    return registration;
  }

  @override
  Stream<List<PairedDevice>> watchMyDevices() => Stream.value(myDevices);

  @override
  Stream<PairedDevice?> watchCurrentDevice() => currentDeviceController.stream;

  @override
  Stream<List<PairedDevice>> watchMemberDevices(
    String circleId,
    String ownerUserId,
  ) => Stream.value(memberDevices);

  @override
  Future<DevicePairingRequest> createPairingRequest() async => pairingRequest;

  @override
  Future<void> revokePairingRequest(String code) async {}

  @override
  Future<PairedDevice> pairDeviceToMember({
    required FamilyGroup group,
    required String targetUserId,
    required String code,
  }) async {
    pairingCalls++;
    if (pairingError != null) throw pairingError!;
    return pairingCompleter?.future ??
        fakeDevice(
          id: 'member-1_$fakeInstallationId',
          current: false,
          status: DevicePairingStatus.paired,
        );
  }

  @override
  Future<void> heartbeat() async => heartbeatCalls++;

  @override
  Future<void> renameMyDevice(PairedDevice device, String name) async =>
      renameCalls++;

  @override
  Future<bool> revokeMyDevice(PairedDevice device) async {
    revokeCalls++;
    return device.isCurrentDevice;
  }

  @override
  Future<void> unpairCircleDevice(String circleId, PairedDevice device) async =>
      unpairCalls++;

  Future<void> dispose() => currentDeviceController.close();
}
