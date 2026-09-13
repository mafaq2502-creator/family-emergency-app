import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SafetyUserService {
  String get uid => FirebaseAuth.instance.currentUser!.uid;
  FirebaseFirestore get db => FirebaseFirestore.instance;
  Stream<List<Map<String, dynamic>>> users() => _active(
    db.collection('users').doc(uid).collection('safetyUsers').snapshots(),
    'pending',
    includeConnected: true,
  );
  Stream<Map<String, dynamic>?> detail(String id) => db
      .collection('users')
      .doc(uid)
      .collection('safetyUsers')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? {'id': doc.id, ...doc.data()!} : null);
  Stream<List<Map<String, dynamic>>> requests({bool circle = false}) => db
      .collection(circle ? 'circleInvites' : 'safetyInvites')
      .where(
        'email',
        isEqualTo: FirebaseAuth.instance.currentUser!.email!.toLowerCase(),
      )
      .snapshots()
      .transform(
        StreamTransformer.fromBind(
          (source) => _active(source, circle ? 'active' : 'pending'),
        ),
      );
  Stream<Map<String, dynamic>> profile() => db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data() ?? {});
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async => Map<String, dynamic>.from(
    (await FirebaseFunctions.instance.httpsCallable(name).call(data)).data
        as Map,
  );
}

Stream<List<Map<String, dynamic>>> _active(
  Stream<QuerySnapshot<Map<String, dynamic>>> source,
  String pending, {
  bool includeConnected = false,
}) => Stream.multi((controller) {
  List<Map<String, dynamic>> data = [];
  Timer? timer;
  void emit() {
    timer?.cancel();
    final now = DateTime.now();
    final live = data
        .where(
          (item) =>
              (includeConnected && item['status'] == 'connected') ||
              (item['status'] == pending &&
                  item['expiresAt'] is Timestamp &&
                  (item['expiresAt'] as Timestamp).toDate().isAfter(now)),
        )
        .toList();
    controller.add(live);
    final expiries =
        live
            .where((item) => item['status'] == pending)
            .map((item) => (item['expiresAt'] as Timestamp).toDate())
            .toList()
          ..sort();
    if (expiries.isNotEmpty) {
      timer = Timer(
        expiries.first.difference(now) + const Duration(milliseconds: 10),
        emit,
      );
    }
  }

  final subscription = source.listen((snapshot) {
    data = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    emit();
  }, onError: controller.addError);
  controller.onCancel = () async {
    timer?.cancel();
    await subscription.cancel();
  };
});
