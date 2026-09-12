class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.groupId,
    required this.type,
    required this.isRead,
    this.emergencyId,
    this.deviceId,
    this.memberUserId,
  });
  final String id;
  final String title;
  final String body;
  final String groupId;
  final String type;
  final bool isRead;
  final String? emergencyId;
  final String? deviceId;
  final String? memberUserId;
  factory AppNotification.fromMap(String id, Map<String, dynamic> map) =>
      AppNotification(
        id: id,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        groupId: map['groupId'] as String? ?? '',
        type: map['type'] as String? ?? 'general',
        isRead: map['isRead'] as bool? ?? false,
        emergencyId: map['emergencyId'] as String?,
        deviceId: map['deviceId'] as String?,
        memberUserId: map['memberUserId'] as String?,
      );
}
