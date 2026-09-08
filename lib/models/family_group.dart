import 'circle_role.dart';

class FamilyGroup {
  const FamilyGroup({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.role,
    this.emergencyRecipientIds = const [],
  });
  final String id;
  final String name;
  final String ownerId;
  final CircleRole role;
  final List<String> emergencyRecipientIds;
  bool get canManage => role.canManageCircle;
  bool get isOwner => role == CircleRole.owner;

  factory FamilyGroup.fromMap(String id, Map<String, dynamic> map) =>
      FamilyGroup(
        id: id,
        name: map['name'] as String? ?? 'Untitled group',
        ownerId: map['ownerId'] as String? ?? '',
        role: CircleRole.fromValue(map['role']),
        emergencyRecipientIds: List<String>.from(
          map['emergencyRecipientIds'] as List? ?? const [],
        ),
      );
}
