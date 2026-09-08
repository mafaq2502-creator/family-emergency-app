import 'package:cloud_firestore/cloud_firestore.dart';

import 'circle_role.dart';

enum MembershipStatus { pending, active, rejected, left, removed }

class CircleMembership {
  const CircleMembership({
    required this.userId,
    required this.displayName,
    required this.relationship,
    required this.role,
    required this.status,
    this.email,
    this.photoUrl,
    this.joinedAt,
  });

  final String userId;
  final String displayName;
  final String relationship;
  final CircleRole role;
  final MembershipStatus status;
  final String? email;
  final String? photoUrl;
  final DateTime? joinedAt;

  bool get isActive => status == MembershipStatus.active;

  factory CircleMembership.fromMap(String id, Map<String, dynamic> map) {
    final statusName = map['status']?.toString();
    return CircleMembership(
      userId: map['userId'] as String? ?? id,
      displayName: map['displayName'] as String? ?? '',
      relationship: map['relationship'] as String? ?? 'Family member',
      role: CircleRole.fromValue(map['circleRole']),
      status: MembershipStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => MembershipStatus.pending,
      ),
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'displayName': displayName,
    'relationship': relationship,
    'circleRole': role.value,
    'status': status.name,
    if (email != null) 'email': email,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };
}
