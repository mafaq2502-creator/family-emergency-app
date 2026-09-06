class FamilyGroup {
  const FamilyGroup({required this.id, required this.name, required this.ownerId, required this.role, this.emergencyRecipientIds = const []});
  final String id;
  final String name;
  final String ownerId;
  final String role;
  final List<String> emergencyRecipientIds;
  bool get canManage => role == 'owner' || role == 'admin';

  factory FamilyGroup.fromMap(String id, Map<String, dynamic> map) => FamilyGroup(id: id, name: map['name'] as String? ?? 'Untitled group', ownerId: map['ownerId'] as String? ?? '', role: map['role'] as String? ?? 'member', emergencyRecipientIds: List<String>.from(map['emergencyRecipientIds'] as List? ?? const []));
}
