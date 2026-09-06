import 'notification_settings.dart';

class FamilyMember {
  const FamilyMember({this.id, this.userId, required this.name, required this.status, this.phone, this.email, this.relation, this.locationAccess = false, this.batteryAccess = false, this.notificationSettings = const NotificationSettings()});

  final String? id;
  final String? userId;
  final String name;
  final String status;
  final String? phone;
  final String? email;
  final String? relation;
  final bool locationAccess;
  final bool batteryAccess;
  final NotificationSettings notificationSettings;

  factory FamilyMember.fromMap(Map<String, dynamic> map, {String? id}) => FamilyMember(
        id: id,
        userId: map['userId'] as String?,
        name: map['name'] as String? ?? '',
        status: map['status'] as String? ?? 'Pending',
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        relation: map['relation'] as String?,
        locationAccess: map['locationAccess'] as bool? ?? false,
        batteryAccess: map['batteryAccess'] as bool? ?? false,
        notificationSettings: NotificationSettings.fromMap(map['notificationSettings'] is Map ? Map<String, dynamic>.from(map['notificationSettings'] as Map) : null),
      );

  Map<String, dynamic> toMap() => {'userId': userId, 'name': name, 'status': status, 'phone': phone, 'email': email, 'relation': relation, 'locationAccess': locationAccess, 'batteryAccess': batteryAccess, 'notificationSettings': notificationSettings.toMap()};
}
