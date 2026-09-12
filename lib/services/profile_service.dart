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
    final data = snapshot.data();
    if (data != null) {
      try {
        // Other members' private profiles are never exposed to a deleting
        // owner. Reconcile this user's references from a server-backed list.
        final groups = await _firestore
            .collection('groups')
            .where('memberIds', arrayContains: user.uid)
            .where('status', isEqualTo: 'active')
            .get(const GetOptions(source: Source.server));
        final active = groups.docs.map((doc) => doc.id).toSet();
        final stale = (data['circleIds'] as List? ?? [])
            .whereType<String>()
            .where((id) => !active.contains(id))
            .toList();
        final updates = <String, dynamic>{};
        if (stale.isNotEmpty) {
          updates['circleIds'] = FieldValue.arrayRemove(stale);
          data['circleIds'] = (data['circleIds'] as List)
              .where((id) => !stale.contains(id))
              .toList();
        }
        if (data['activeCircleId'] != null &&
            !active.contains(data['activeCircleId'])) {
          updates['activeCircleId'] = FieldValue.delete();
          data.remove('activeCircleId');
        }
        final pending = data['pendingJoinCircleId'];
        if (pending is String) {
          final request = await _firestore
              .collection('groups')
              .doc(pending)
              .collection('joinRequests')
              .doc(user.uid)
              .get(const GetOptions(source: Source.server));
          if (request.data()?['status'] != 'pending') {
            updates['pendingJoinCircleId'] = FieldValue.delete();
            updates['pendingJoinInviteId'] = FieldValue.delete();
            data.remove('pendingJoinCircleId');
            data.remove('pendingJoinInviteId');
          }
        }
        if (updates.isNotEmpty) {
          await _documentFor(user)
              .update({...updates, 'updatedAt': FieldValue.serverTimestamp()});
        }
      } on FirebaseException catch (_) {
        // Offline/cache results must not erase references. Retry on next load.
      }
    }
    return UserProfile.fromFirestore(user, data);
  }

  Future<void> syncCanonicalIdentity(User user) async {
    final email = user.email?.trim();
    if (email == null || email.isEmpty) return;
    final reference = _documentFor(user);
    final snapshot = await reference.get();
    if (!snapshot.exists || snapshot.data()?['email'] == email) return;
    await reference.set({
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      'email': user.email?.trim() ?? email.trim().toLowerCase(),
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
    required String relationship,
    String? signupPhone,
  }) async {
    final reference = _documentFor(user);
    final snapshot = await reference.get();
    await reference.set({
      'uid': user.uid,
      'name': name.trim(),
      'email': user.email?.trim() ?? '',
      if ((snapshot.data()?['phone'] == null ||
              snapshot.data()?['phone'] == '') &&
          signupPhone != null &&
          signupPhone.trim().isNotEmpty)
        'phone': signupPhone.trim(),
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
    final groups = await _firestore
        .collection('groups')
        .where('memberIds', arrayContains: user.uid)
        .where('status', isEqualTo: 'active')
        .get();
    final batch = _firestore.batch();
    batch.set(_documentFor(user), {
      'name': name.trim(),
      'relationship': relationship,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    for (final group in groups.docs) {
      final membership = group.reference
          .collection('memberships')
          .doc(user.uid);
      batch.set(membership, {
        'displayName': name.trim(),
        'relationship': relationship,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
    await user.updateDisplayName(name.trim());
  }

  Future<void> saveAddress(User user, Map<String, String> address) =>
      _documentFor(user).set({
        'address': address,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> saveProfilePhoto(User user, String photoUrl) =>
      _documentFor(user).set({
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
