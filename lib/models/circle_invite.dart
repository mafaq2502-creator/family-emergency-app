import 'package:cloud_firestore/cloud_firestore.dart';

import 'circle_role.dart';

enum CircleInviteStatus { active, revoked, exhausted }

class CircleInvite {
  const CircleInvite({
    required this.id,
    required this.circleId,
    required this.createdBy,
    required this.code,
    required this.role,
    required this.status,
    required this.expiresAt,
    this.maxUses = 1,
    this.useCount = 0,
  });

  final String id;
  final String circleId;
  final String createdBy;
  final String code;
  final CircleRole role;
  final CircleInviteStatus status;
  final DateTime expiresAt;
  final int maxUses;
  final int useCount;

  bool get isUsable =>
      status == CircleInviteStatus.active &&
      expiresAt.isAfter(DateTime.now()) &&
      useCount < maxUses;

  factory CircleInvite.fromMap(String id, Map<String, dynamic> map) {
    final rawStatus = map['status']?.toString();
    return CircleInvite(
      id: id,
      circleId: map['circleId'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      code: map['code'] as String? ?? '',
      role: CircleRole.fromValue(map['circleRole']),
      status: CircleInviteStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => CircleInviteStatus.active,
      ),
      expiresAt:
          (map['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      maxUses: map['maxUses'] as int? ?? 1,
      useCount: map['useCount'] as int? ?? 0,
    );
  }
}
