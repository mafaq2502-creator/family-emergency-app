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
    this.updatedAt,
    this.endedAt,
  });

  final String userId;
  final String displayName;
  final String relationship;
  final CircleRole role;
  final MembershipStatus status;
  final String? email;
  final String? photoUrl;
  final DateTime? joinedAt;
  final DateTime? updatedAt;
  final DateTime? endedAt;

  bool get isActive => status == MembershipStatus.active;

  factory CircleMembership.fromMap(String id, Map<String, dynamic> map) {
    final statusName = map['status']?.toString();
    return CircleMembership(
      userId: _string(map['userId']) ?? id,
      displayName: _string(map['displayName']) ?? 'Family member',
      relationship: _string(map['relationship']) ?? 'Not specified',
      role: CircleRole.fromValue(map['circleRole']),
      status: MembershipStatus.values.firstWhere(
        (value) => value.name == statusName,
        orElse: () => MembershipStatus.pending,
      ),
      email: _string(map['email']),
      photoUrl: _string(map['photoUrl']),
      joinedAt: _date(map['joinedAt']),
      updatedAt: _date(map['updatedAt']),
      endedAt: _date(map['endedAt']),
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

  static String? _string(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
