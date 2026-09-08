import 'package:cloud_firestore/cloud_firestore.dart';

enum DevicePairingStatus { pending, paired, revoked }

class PairedDevice {
  const PairedDevice({
    required this.id,
    required this.userId,
    required this.name,
    required this.model,
    required this.platform,
    required this.pairingStatus,
    this.batteryLevel,
    this.storageUsedPercent,
    this.lastSeenAt,
    this.permissions = const {},
  });

  final String id;
  final String userId;
  final String name;
  final String model;
  final String platform;
  final DevicePairingStatus pairingStatus;
  final int? batteryLevel;
  final int? storageUsedPercent;
  final DateTime? lastSeenAt;
  final Map<String, bool> permissions;

  bool isOnline(
    DateTime now, {
    Duration timeout = const Duration(minutes: 15),
  }) => lastSeenAt != null && now.difference(lastSeenAt!) <= timeout;

  factory PairedDevice.fromMap(String id, Map<String, dynamic> map) {
    final rawStatus = map['pairingStatus']?.toString();
    return PairedDevice(
      id: id,
      userId: map['userId'] as String? ?? '',
      name: map['name'] as String? ?? 'Device',
      model: map['model'] as String? ?? 'Unknown model',
      platform: map['platform'] as String? ?? 'android',
      pairingStatus: DevicePairingStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => DevicePairingStatus.pending,
      ),
      batteryLevel: map['batteryLevel'] as int?,
      storageUsedPercent: map['storageUsedPercent'] as int?,
      lastSeenAt: (map['lastSeenAt'] as Timestamp?)?.toDate(),
      permissions: Map<String, bool>.from(
        map['permissions'] as Map? ?? const {},
      ),
    );
  }
}
