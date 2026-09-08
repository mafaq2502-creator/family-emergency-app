// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';

class AppNotificationService {
  AppNotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore;
  FirebaseFirestore? _firestore;
  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;
  Stream<List<AppNotification>> watch(User user) => _client
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
            .toList(),
      );
  Future<void> markRead(User user, String id) => _client
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .doc(id)
      .update({'isRead': true});
  Future<void> markAllRead(User user) async {
    final unread = await _client
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _client.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
