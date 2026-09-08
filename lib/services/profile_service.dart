import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_settings.dart';
import '../models/user_profile.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _documentFor(User user) =>
      _firestore.collection('users').doc(user.uid);

  Future<UserProfile> load(User user) async {
    final snapshot = await _documentFor(user).get();
    return UserProfile.fromFirestore(user, snapshot.data());
  }

  Future<void> createEmailProfile(
    User user, {
    required String name,
    required String email,
    required String phone,
    required String countryIso,
    required String countryCode,
    String relationship = 'Self',
  }) {
    final now = FieldValue.serverTimestamp();
    return _documentFor(user).set({
      'uid': user.uid,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'phoneCountryIso': countryIso,
      'phoneCountryCode': countryCode,
      'relationship': relationship,
      'photoUrl': user.photoURL,
      'providerIds': user.providerData
          .map((provider) => provider.providerId)
          .toSet()
          .toList(),
      'profileCompleted': true,
      'onboardingCompleted': false,
      'notificationSettings': const NotificationSettings().toMap(),
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> ensureProviderProfile(User user) async {
    final reference = _documentFor(user);
    final snapshot = await reference.get();
    final providers = user.providerData
        .map((provider) => provider.providerId)
        .where((provider) => provider.isNotEmpty)
        .toSet()
        .toList();
    if (!snapshot.exists) {
      final name = user.displayName?.trim() ?? '';
      final email = user.email?.trim() ?? '';
      await reference.set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'phone': user.phoneNumber?.trim() ?? '',
        'relationship': null,
        'photoUrl': user.photoURL,
        'providerIds': providers,
        'profileCompleted': false,
        'onboardingCompleted': false,
        'notificationSettings': const NotificationSettings().toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final existing = snapshot.data() ?? const <String, dynamic>{};
    final updates = <String, dynamic>{
      'providerIds': FieldValue.arrayUnion(providers),
      'lastSignInAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if ((existing['email'] is! String ||
            (existing['email'] as String).trim().isEmpty) &&
        user.email != null) {
      updates['email'] = user.email!.trim();
    }
    if ((existing['name'] is! String ||
            (existing['name'] as String).trim().isEmpty) &&
        user.displayName != null) {
      updates['name'] = user.displayName!.trim();
    }
    if ((existing['photoUrl'] is! String ||
            (existing['photoUrl'] as String).trim().isEmpty) &&
        user.photoURL != null) {
      updates['photoUrl'] = user.photoURL;
    }
    await reference.set(updates, SetOptions(merge: true));
  }

  Future<void> completeProfile(
    User user, {
    required String name,
    required String phone,
    required String countryIso,
    required String countryCode,
    required String relationship,
  }) async {
    final reference = _documentFor(user);
    final snapshot = await reference.get();
    await reference.set({
      'uid': user.uid,
      'name': name.trim(),
      'email': user.email?.trim() ?? '',
      'phone': phone.trim(),
      'phoneCountryIso': countryIso,
      'phoneCountryCode': countryCode,
      'relationship': relationship,
      if (user.photoURL != null) 'photoUrl': user.photoURL,
      'providerIds': user.providerData
          .map((provider) => provider.providerId)
          .toSet()
          .toList(),
      'profileCompleted': true,
      'onboardingCompleted': false,
      'notificationSettings': const NotificationSettings().toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (user.displayName != name.trim()) {
      await user.updateDisplayName(name.trim());
    }
  }

  Future<void> markOnboardingCompleted(User user) => _documentFor(user).set({
    'onboardingCompleted': true,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> saveBasicProfile(
    User user, {
    required String name,
    required String? relationship,
  }) async {
    await _documentFor(user).set({
      'name': name.trim(),
      'relationship': relationship,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.updateDisplayName(name.trim());
  }

  Future<void> recordDailyCheckIn(
    User user, {
    required String timeZone,
    required String localDate,
  }) => _documentFor(user).set({
    'lastDailyCheckInAt': FieldValue.serverTimestamp(),
    'lastDailyCheckInTimeZone': timeZone,
    'lastDailyCheckInLocalDate': localDate,
  }, SetOptions(merge: true));

  Future<void> saveNotificationSettings(
    User user,
    NotificationSettings settings,
  ) => _documentFor(user).set({
    'notificationSettings': settings.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
