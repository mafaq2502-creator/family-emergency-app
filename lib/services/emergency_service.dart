// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmergencyService {
  EmergencyService({FirebaseFirestore? firestore}) : _firestore = firestore;
  FirebaseFirestore? _firestore;
  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;

  Future<String> create({required String groupId, required User sender, required String senderName, required List<String> recipientIds}) async {
    final document = await _client.collection('groups').doc(groupId).collection('emergencies').add({'senderId': sender.uid, 'senderName': senderName, 'recipientIds': recipientIds, 'status': 'active', 'createdAt': FieldValue.serverTimestamp()});
    return document.id;
  }

  Future<void> acknowledge({required String groupId, required String emergencyId, required User user, required String name}) => _client.collection('groups').doc(groupId).collection('emergencies').doc(emergencyId).update({'status': 'acknowledged', 'acknowledgedById': user.uid, 'acknowledgedByName': name, 'acknowledgedAt': FieldValue.serverTimestamp()});
  Future<void> resolve({required String groupId, required String emergencyId}) => _client.collection('groups').doc(groupId).collection('emergencies').doc(emergencyId).update({'status': 'resolved', 'resolvedAt': FieldValue.serverTimestamp()});
}
