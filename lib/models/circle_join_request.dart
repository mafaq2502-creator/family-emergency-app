import 'package:cloud_firestore/cloud_firestore.dart';

import 'circle_role.dart';

enum JoinRequestStatus { pending, approved, rejected, cancelled, unavailable }

class CircleJoinRequest {
  const CircleJoinRequest({
    required this.id,
    required this.circleId,
    required this.userUid,
    required this.inviteId,
    required this.displayName,
    required this.relationship,
    required this.email,
    required this.role,
    required this.status,
    this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  final String id;
  final String circleId;
  final String userUid;
  final String inviteId;
  final String displayName;
  final String relationship;
  final String email;
  final CircleRole role;
  final JoinRequestStatus status;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;

  bool get isPending => status == JoinRequestStatus.pending;

  factory CircleJoinRequest.fromMap(String id, Map<String, dynamic> map) {
    final status = JoinRequestStatus.values.firstWhere(
      (value) => value.name == map['status']?.toString().toLowerCase(),
      orElse: () => JoinRequestStatus.unavailable,
    );
    return CircleJoinRequest(
      id: id,
      circleId: _string(map['circleId']),
      userUid: _string(map['userUid']),
      inviteId: _string(map['inviteId']),
      displayName: _string(map['displayName'], 'Family member'),
      relationship: _string(map['relationship'], 'Not specified'),
      email: _string(map['email']),
      role: CircleRole.fromValue(map['circleRole']) == CircleRole.child
          ? CircleRole.child
          : CircleRole.adult,
      status: status,
      requestedAt: _date(map['requestedAt']),
      reviewedAt: _date(map['reviewedAt']),
      reviewedBy: _nullableString(map['reviewedBy']),
    );
  }

  static String _string(Object? value, [String fallback = '']) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  static String? _nullableString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;
}
