class EmergencyEvent {
  const EmergencyEvent({required this.id, required this.senderId, required this.senderName, required this.status, this.acknowledgedByName});
  final String id;
  final String senderId;
  final String senderName;
  final String status;
  final String? acknowledgedByName;
}
