import 'package:cloud_firestore/cloud_firestore.dart';

import 'circle_role.dart';

enum CircleInviteStatus { active, expired, revoked, exhausted, unavailable }

class CircleInvite {
  const CircleInvite({
    required this.id,
    required this.circleId,
    required this.createdBy,
    required this.code,
    required this.circleName,
    required this.role,
    required this.status,
    required this.expiresAt,
    this.maxUses = 1,
    this.useCount = 0,
    this.requiresApproval = true,
    this.createdAt,
    this.revokedAt,
    this.revokedBy,
  });

  final String id;
  final String circleId;
  final String createdBy;
  final String code;
  final String circleName;
  final CircleRole role;
  final CircleInviteStatus status;
  final DateTime expiresAt;
  final int maxUses;
  final int useCount;
  final bool requiresApproval;
  final DateTime? createdAt;
  final DateTime? revokedAt;
  final String? revokedBy;

  bool isUsableAt(DateTime now) =>
      status == CircleInviteStatus.active &&
      expiresAt.isAfter(now) &&
      useCount < maxUses;

  bool get isUsable => isUsableAt(DateTime.now());

  factory CircleInvite.fromMap(String id, Map<String, dynamic> map) {
    final rawStatus = map['status']?.toString().toLowerCase();
    final rawMaxUses = map['maxUses'];
    final rawUseCount = map['useCount'];
    return CircleInvite(
      id: id,
      circleId: _string(map['circleId']),
      createdBy: _string(map['createdBy']),
      code: id,
      circleName: _string(map['circleName'], fallback: 'Family Circle'),
      role: CircleRole.fromValue(map['circleRole']) == CircleRole.child
          ? CircleRole.child
          : CircleRole.adult,
      status: CircleInviteStatus.values.firstWhere(
        (value) => value.name == rawStatus,
        orElse: () => CircleInviteStatus.unavailable,
      ),
      expiresAt: _date(map['expiresAt']),
      maxUses: rawMaxUses is int && rawMaxUses > 0 ? rawMaxUses : 0,
      useCount: rawUseCount is int && rawUseCount >= 0 ? rawUseCount : 0,
      requiresApproval: map['requiresApproval'] == true,
      createdAt: _nullableDate(map['createdAt']),
      revokedAt: _nullableDate(map['revokedAt']),
      revokedBy: _nullableString(map['revokedBy']),
    );
  }

  static String _string(Object? value, {String fallback = ''}) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  static String? _nullableString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static DateTime _date(Object? value) => value is Timestamp
      ? value.toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime? _nullableDate(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
