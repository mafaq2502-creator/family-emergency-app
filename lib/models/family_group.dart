import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/domain/circle_policies.dart';
import 'circle_role.dart';

class FamilyGroup {
  const FamilyGroup({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.role,
    this.emergencyRecipientIds = const [],
    this.memberIds = const [],
    this.status = CircleLifecycleStatus.active,
    this.createdAt,
    this.updatedAt,
  });
  final String id;
  final String name;
  final String ownerId;
  final CircleRole role;
  final List<String> emergencyRecipientIds;
  final List<String> memberIds;
  final CircleLifecycleStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  bool get canManage => role.canManageCircle;
  bool get isOwner => role == CircleRole.owner;
  bool get isActive => status == CircleLifecycleStatus.active;
  int get memberCount => memberIds.length;

  factory FamilyGroup.fromMap(String id, Map<String, dynamic> map) =>
      FamilyGroup(
        id: id,
        name: _string(map['name']) ?? 'Unavailable Circle',
        ownerId: _string(map['ownerId']) ?? '',
        role: CircleRole.fromValue(map['role']),
        emergencyRecipientIds: _stringList(map['emergencyRecipientIds']),
        memberIds: _stringList(map['memberIds']),
        status: _status(map['status']),
        createdAt: _date(map['createdAt']),
        updatedAt: _date(map['updatedAt']),
      );

  static String? _string(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static List<String> _stringList(Object? value) => value is List
      ? value.whereType<String>().where((item) => item.isNotEmpty).toList()
      : const [];

  static CircleLifecycleStatus _status(Object? value) {
    if (value == null) return CircleLifecycleStatus.active;
    return CircleLifecycleStatus.values.firstWhere(
      (status) => status.name == value.toString().toLowerCase(),
      orElse: () => CircleLifecycleStatus.unavailable,
    );
  }

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
