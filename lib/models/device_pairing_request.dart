import 'package:cloud_firestore/cloud_firestore.dart';

enum DevicePairingRequestStatus { active, used, revoked, expired, unavailable }

class DevicePairingRequest {
  const DevicePairingRequest({
    required this.code,
    required this.ownerUserId,
    required this.installationId,
    required this.deviceName,
    required this.platform,
    required this.status,
    required this.expiresAt,
    this.appVersion,
    this.createdAt,
    this.usedAt,
    this.usedBy,
    this.circleId,
    this.deviceAssociationId,
  });

  final String code;
  final String ownerUserId;
  final String installationId;
  final String deviceName;
  final String platform;
  final String? appVersion;
  final DevicePairingRequestStatus status;
  final DateTime expiresAt;
  final DateTime? createdAt;
  final DateTime? usedAt;
  final String? usedBy;
  final String? circleId;
  final String? deviceAssociationId;

  bool isUsableAt(DateTime now) =>
      status == DevicePairingRequestStatus.active &&
      expiresAt.isAfter(now.toUtc());

  factory DevicePairingRequest.fromMap(String code, Map<String, dynamic> map) =>
      DevicePairingRequest(
        code: code,
        ownerUserId: _string(map['ownerUserId']),
        installationId: _string(map['installationId']),
        deviceName: _string(map['deviceName'], 'Device'),
        platform: _string(map['platform'], 'unknown'),
        appVersion: _nullableString(map['appVersion']),
        status: DevicePairingRequestStatus.values.firstWhere(
          (status) => status.name == map['status']?.toString(),
          orElse: () => DevicePairingRequestStatus.unavailable,
        ),
        expiresAt:
            _date(map['expiresAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        createdAt: _date(map['createdAt']),
        usedAt: _date(map['usedAt']),
        usedBy: _nullableString(map['usedBy']),
        circleId: _nullableString(map['circleId']),
        deviceAssociationId: _nullableString(map['deviceAssociationId']),
      );

  static String _string(Object? value, [String fallback = '']) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  static String? _nullableString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate().toUtc() : null;
}
