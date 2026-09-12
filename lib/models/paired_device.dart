import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/domain/device_policies.dart';

enum DevicePairingStatus { registered, pending, paired, revoked, unpaired }

enum DevicePresence { online, stale, offline, revoked, unpaired }

class PairedDevice {
  const PairedDevice({
    required this.id,
    required this.userId,
    required this.name,
    required this.model,
    required this.platform,
    required this.pairingStatus,
    this.installationId,
    this.circleId,
    this.osVersion,
    this.appVersion,
    this.isCurrentDevice = false,
    this.batteryLevel,
    this.storageUsedPercent,
    this.lastSeenAt,
    this.lastHeartbeatAt,
    this.registeredAt,
    this.pairedAt,
    this.updatedAt,
    this.revokedAt,
    this.removedAt,
    this.lastScreenTimeSyncAt,
    this.screenTimePermissionState,
    this.manufacturer,
    this.androidApiLevel,
    this.appBuildNumber,
    this.notificationPermissionState,
    this.notificationsEnabled = false,
    this.permissions = const {},
  });

  final String id;
  final String userId;
  final String name;
  final String model;
  final String platform;
  final DevicePairingStatus pairingStatus;
  final String? installationId;
  final String? circleId;
  final String? osVersion;
  final String? appVersion;
  final bool isCurrentDevice;
  final int? batteryLevel;
  final int? storageUsedPercent;
  final DateTime? lastSeenAt;
  final DateTime? lastHeartbeatAt;
  final DateTime? registeredAt;
  final DateTime? pairedAt;
  final DateTime? updatedAt;
  final DateTime? revokedAt;
  final DateTime? removedAt;
  final DateTime? lastScreenTimeSyncAt;
  final String? screenTimePermissionState;
  final String? manufacturer;
  final int? androidApiLevel;
  final String? appBuildNumber;
  final String? notificationPermissionState;
  final bool notificationsEnabled;
  final Map<String, bool> permissions;

  bool isOnline(DateTime now, {Duration timeout = DevicePolicy.staleAfter}) {
    final heartbeat = lastHeartbeatAt ?? lastSeenAt;
    return pairingStatus != DevicePairingStatus.revoked &&
        pairingStatus != DevicePairingStatus.unpaired &&
        heartbeat != null &&
        now.toUtc().difference(heartbeat.toUtc()) <= timeout;
  }

  DevicePresence presenceAt(DateTime now) {
    if (pairingStatus == DevicePairingStatus.revoked) {
      return DevicePresence.revoked;
    }
    if (pairingStatus == DevicePairingStatus.unpaired) {
      return DevicePresence.unpaired;
    }
    final heartbeat = lastHeartbeatAt ?? lastSeenAt;
    if (heartbeat == null) return DevicePresence.offline;
    final age = now.toUtc().difference(heartbeat.toUtc());
    if (age <= DevicePolicy.staleAfter) return DevicePresence.online;
    if (age <= DevicePolicy.offlineAfter) return DevicePresence.stale;
    return DevicePresence.offline;
  }

  factory PairedDevice.fromMap(String id, Map<String, dynamic> map) {
    final rawStatus = map['pairingStatus']?.toString();
    return PairedDevice(
      id: id,
      userId: map['ownerUserId'] as String? ?? map['userId'] as String? ?? '',
      name: map['name'] as String? ?? 'Device',
      model: map['model'] as String? ?? 'Unknown model',
      platform: map['platform'] as String? ?? 'android',
      pairingStatus: DevicePairingStatus.values.firstWhere(
        (value) => value.name == (rawStatus ?? map['status']?.toString()),
        orElse: () => map['status'] == 'active'
            ? DevicePairingStatus.registered
            : DevicePairingStatus.pending,
      ),
      installationId: map['installationId'] as String?,
      circleId: map['circleId'] as String?,
      osVersion: map['osVersion'] as String?,
      appVersion: map['appVersion'] as String?,
      batteryLevel: map['batteryLevel'] as int?,
      storageUsedPercent: map['storageUsedPercent'] as int?,
      lastSeenAt: (map['lastSeenAt'] as Timestamp?)?.toDate(),
      lastHeartbeatAt: (map['lastHeartbeatAt'] as Timestamp?)?.toDate(),
      registeredAt: (map['registeredAt'] as Timestamp?)?.toDate(),
      pairedAt: (map['pairedAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      revokedAt: (map['revokedAt'] as Timestamp?)?.toDate(),
      removedAt: (map['removedAt'] as Timestamp?)?.toDate(),
      lastScreenTimeSyncAt: (map['lastScreenTimeSyncAt'] as Timestamp?)
          ?.toDate(),
      screenTimePermissionState: map['screenTimePermissionState'] as String?,
      manufacturer: map['manufacturer'] as String?,
      androidApiLevel: map['androidApiLevel'] as int?,
      appBuildNumber: map['appBuildNumber'] as String?,
      notificationPermissionState:
          map['notificationPermissionState'] as String?,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? false,
      permissions: Map<String, bool>.from(
        map['permissions'] as Map? ?? const {},
      ),
    );
  }
}
