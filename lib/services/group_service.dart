// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/family_group.dart';
import '../models/circle_role.dart';

class GroupService {
  GroupService({FirebaseFirestore? firestore}) : _firestore = firestore;
  FirebaseFirestore? _firestore;
  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;

  Stream<List<FamilyGroup>> watchGroups(User user) => _client
      .collection('groups')
      .where('memberIds', arrayContains: user.uid)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {});
          return FamilyGroup.fromMap(doc.id, {
            ...data,
            'role': roles[user.uid] ?? CircleRole.adult.value,
          });
        }).toList(),
      );

  Future<bool> hasAnyGroup(User user) async {
    final snapshot = await _client
        .collection('groups')
        .where('memberIds', arrayContains: user.uid)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<String> createGroup(User owner, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('A group name is required.');
    final doc = _client.collection('groups').doc();
    final profile = await _client.collection('users').doc(owner.uid).get();
    final profileData = profile.data() ?? const <String, dynamic>{};
    final groupData = {
      'name': trimmedName,
      'ownerId': owner.uid,
      'memberIds': [owner.uid],
      'roles': {owner.uid: CircleRole.owner.value},
      'emergencyRecipientIds': [owner.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _client.batch();
    batch.set(doc, groupData);
    batch.set(doc.collection('memberships').doc(owner.uid), {
      'userId': owner.uid,
      'displayName': profileData['name'] as String? ?? owner.displayName ?? '',
      'email': owner.email,
      'relationship':
          profileData['relationship'] as String? ??
          profileData['role'] as String? ??
          'Self',
      'circleRole': CircleRole.owner.value,
      'status': 'active',
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_client.collection('users').doc(owner.uid), {
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Keep group, owner membership, and onboarding state atomic. A failure
    // must not leave a group that the owner cannot see or resume.
    await batch.commit();
    return doc.id;
  }

  Future<String> ensureDefaultGroup(User owner) async {
    final existing = await _client
        .collection('groups')
        .where('ownerId', isEqualTo: owner.uid)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;
    return createGroup(owner, 'My Family');
  }

  Future<void> renameGroup(FamilyGroup group, String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) throw ArgumentError('A group name is required.');
    return _client.collection('groups').doc(group.id).update({
      'name': trimmedName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes group-owned records in batches before deleting the group.
  Future<void> deleteGroup(FamilyGroup group) async {
    final groupRef = _client.collection('groups').doc(group.id);
    for (final subcollection in ['members', 'emergencies']) {
      while (true) {
        final documents = await groupRef
            .collection(subcollection)
            .limit(400)
            .get();
        if (documents.docs.isEmpty) break;
        final batch = _client.batch();
        for (final document in documents.docs) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }
    }
    await groupRef.delete();
  }

  Future<void> setEmergencyRecipients(
    FamilyGroup group,
    List<String> userIds,
  ) => _client.collection('groups').doc(group.id).update({
    'emergencyRecipientIds': userIds,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
