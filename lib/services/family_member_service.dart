// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/family_member.dart';

class FamilyMemberService {
  FamilyMemberService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore? _firestore;
  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _members(User owner) => _client.collection('users').doc(owner.uid).collection('members');

  Stream<List<FamilyMember>> watchMembers(User owner) => _members(owner).orderBy('createdAt').snapshots().map((snapshot) => snapshot.docs.map((document) => FamilyMember.fromMap(document.data(), id: document.id)).toList());

  Future<FamilyMember> create(User owner, FamilyMember member) async {
    final document = await _members(owner).add({...member.toMap(), 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    return FamilyMember.fromMap(member.toMap(), id: document.id);
  }

  Future<void> update(User owner, FamilyMember member) {
    if (member.id == null) throw ArgumentError('A member id is required to update a member.');
    return _members(owner).doc(member.id).update({...member.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> delete(User owner, String memberId) => _members(owner).doc(memberId).delete();
}
