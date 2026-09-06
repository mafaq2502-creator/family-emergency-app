// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// One-time migration from the original owner-scoped member list to My Family.
/// Safe to call repeatedly: once `legacyMembersMigratedAt` exists it does nothing.
class GroupMigrationService {
  GroupMigrationService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore? _firestore;
  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;

  Future<String?> migrateLegacyMembers(User user) async {
    final userRef = _client.collection('users').doc(user.uid);
    final profile = await userRef.get();
    if (profile.data()?['legacyMembersMigratedAt'] != null) return profile.data()?['primaryGroupId'] as String?;

    final groups = await _client.collection('groups').where('ownerId', isEqualTo: user.uid).limit(1).get();
    final groupRef = groups.docs.isEmpty ? _client.collection('groups').doc() : groups.docs.first.reference;
    final legacyMembers = await userRef.collection('members').get();
    final batch = _client.batch();
    if (groups.docs.isEmpty) {
      batch.set(groupRef, {'name': 'My Family', 'ownerId': user.uid, 'memberIds': [user.uid], 'roles': {user.uid: 'owner'}, 'emergencyRecipientIds': [user.uid], 'createdAt': FieldValue.serverTimestamp()});
    }
    for (final legacy in legacyMembers.docs) {
      batch.set(groupRef.collection('members').doc(legacy.id), {...legacy.data(), 'migratedFromLegacy': true, 'updatedAt': FieldValue.serverTimestamp()});
    }
    batch.set(userRef, {'primaryGroupId': groupRef.id, 'legacyMembersMigratedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await batch.commit();
    return groupRef.id;
  }
}
