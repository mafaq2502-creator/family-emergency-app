import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_settings.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isFamilyOwner,
    required this.notificationSettings,
    this.lastDailyCheckIn,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? role;
  final bool isFamilyOwner;
  final NotificationSettings notificationSettings;
  final DateTime? lastDailyCheckIn;

  factory UserProfile.fromFirestore(User user, Map<String, dynamic>? data) {
    final lastCheckIn = data?['lastDailyCheckInAt'];
    final settings = data?['notificationSettings'];
    return UserProfile(
      uid: user.uid,
      name: data?['name'] as String? ?? user.displayName ?? user.email?.split('@').first ?? '',
      email: data?['email'] as String? ?? user.email ?? '',
      phone: data?['phone'] as String? ?? '',
      role: data?['role'] as String?,
      isFamilyOwner: data?['isFamilyOwner'] as bool? ?? true,
      notificationSettings: NotificationSettings.fromMap(settings is Map ? Map<String, dynamic>.from(settings) : null),
      lastDailyCheckIn: lastCheckIn is Timestamp ? lastCheckIn.toDate() : null,
    );
  }
}
