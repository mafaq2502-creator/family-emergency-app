import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyEvent {
  const EmergencyEvent({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.status,
    this.acknowledgedByName,
    this.createdAt,
  });
  final String id;
  final String senderId;
  final String senderName;
  final String status;
  final String? acknowledgedByName;
  final DateTime? createdAt;

  factory EmergencyEvent.fromMap(String id, Map<String, dynamic> map) =>
      EmergencyEvent(
        id: id,
        senderId: map['senderId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? 'A Circle member',
        status: map['status'] as String? ?? 'active',
        acknowledgedByName: map['acknowledgedByName'] as String?,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      );
}
