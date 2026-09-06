import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_settings.dart';
import '../models/user_profile.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _documentFor(User user) => _firestore.collection('users').doc(user.uid);

  Future<UserProfile> load(User user) async {
    final snapshot = await _documentFor(user).get();
    return UserProfile.fromFirestore(user, snapshot.data());
  }

  Future<void> saveBasicProfile(User user, {required String name, required String? role}) async {
    await _documentFor(user).set({'name': name, 'role': role}, SetOptions(merge: true));
    await user.updateDisplayName(name);
  }

  Future<void> recordDailyCheckIn(User user, {required String timeZone, required String localDate}) => _documentFor(user).set({
        'lastDailyCheckInAt': FieldValue.serverTimestamp(),
        'lastDailyCheckInTimeZone': timeZone,
        'lastDailyCheckInLocalDate': localDate,
      }, SetOptions(merge: true));

  Future<void> saveNotificationSettings(User user, NotificationSettings settings) => _documentFor(user).set({'notificationSettings': settings.toMap()}, SetOptions(merge: true));
}
