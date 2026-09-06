// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/family_group.dart';

class GroupService {
  GroupService({FirebaseFirestore? firestore}) : _firestore = firestore;
  FirebaseFirestore? _firestore;
  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;

  Stream<List<FamilyGroup>> watchGroups(User user) => _client.collection('groups').where('memberIds', arrayContains: user.uid).snapshots().map((snapshot) => snapshot.docs.map((doc) { final data = doc.data(); final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {}); return FamilyGroup.fromMap(doc.id, {...data, 'role': roles[user.uid] ?? 'member'}); }).toList());

  Future<String> createGroup(User owner, String name) async {
    final doc = _client.collection('groups').doc();
    await doc.set({'name': name.trim(), 'ownerId': owner.uid, 'memberIds': [owner.uid], 'roles': {owner.uid: 'owner'}, 'emergencyRecipientIds': [owner.uid], 'createdAt': FieldValue.serverTimestamp()});
    return doc.id;
  }

  Future<void> setEmergencyRecipients(FamilyGroup group, List<String> userIds) => _client.collection('groups').doc(group.id).update({'emergencyRecipientIds': userIds, 'updatedAt': FieldValue.serverTimestamp()});
}
