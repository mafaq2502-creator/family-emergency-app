// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/domain/circle_policies.dart';
import '../models/circle_membership.dart';
import '../models/family_group.dart';
import '../models/circle_role.dart';

class GroupService {
  static final _unavailable = <String>{};
  static final _invalidations = StreamController<void>.broadcast();
  void invalidate(String userId, String groupId) {
    _unavailable.add('$userId/$groupId');
    _invalidations.add(null);
  }

  GroupService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore,
      _functions = functions;
  FirebaseFirestore? _firestore;
  FirebaseFunctions? _functions;
  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;
  FirebaseFunctions get _functionClient =>
      _functions ??= FirebaseFunctions.instance;

  Stream<List<FamilyGroup>> watchGroups(User user) => Stream.multi((
    controller,
  ) {
    List<FamilyGroup> latest = [];
    void emit() => controller.add(
      latest
          .where((group) => !_unavailable.contains('${user.uid}/${group.id}'))
          .toList(),
    );
    final changes = _invalidations.stream.listen((_) => emit());
    final groups = _confirmedGroups(user).listen((value) {
      latest = value;
      emit();
    }, onError: controller.addError);
    controller.onCancel = () async {
      await changes.cancel();
      await groups.cancel();
    };
  });

  Stream<List<FamilyGroup>> _confirmedGroups(User user) => _client
      .collection('groups')
      .where('memberIds', arrayContains: user.uid)
      .where('status', isEqualTo: 'active')
      .snapshots(includeMetadataChanges: true)
      // A local batch can still be rejected by rules. Keep the last confirmed
      // list until the server acknowledges it (including metadata-only acks).
      .where((snapshot) => !snapshot.metadata.hasPendingWrites)
      .map((snapshot) {
        if (!snapshot.metadata.isFromCache) {
          _unavailable.removeWhere(
            (key) =>
                key.startsWith('${user.uid}/') &&
                !snapshot.docs.any((doc) => key == '${user.uid}/${doc.id}'),
          );
        }
        return snapshot.docs
            .map((doc) {
              final data = doc.data();
              final roles = Map<String, dynamic>.from(
                data['roles'] as Map? ?? {},
              );
              return FamilyGroup.fromMap(doc.id, {
                ...data,
                'role': roles[user.uid] ?? CircleRole.adult.value,
              });
            })
            .where((group) => group.isActive)
            .toList();
      });

  Stream<FamilyGroup?> watchGroupForUser(String groupId, String userId) =>
      _client.collection('groups').doc(groupId).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          invalidate(userId, groupId);
          return null;
        }
        final memberIds = _strings(data['memberIds']);
        if (!memberIds.contains(userId)) {
          invalidate(userId, groupId);
          return null;
        }
        final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {});
        final group = FamilyGroup.fromMap(snapshot.id, {
          ...data,
          'role': roles[userId],
        });
        if (!group.isActive) invalidate(userId, groupId);
        return group.isActive ? group : null;
      });

  Stream<List<CircleMembership>> watchMemberships(String groupId) => _client
      .collection('groups')
      .doc(groupId)
      .collection('publicMembers')
      .snapshots()
      .map((snapshot) {
        final memberships = snapshot.docs
            .map((doc) => CircleMembership.fromMap(doc.id, doc.data()))
            .where((membership) => membership.isActive)
            .toList();
        memberships.sort((left, right) {
          if (left.role == CircleRole.owner) return -1;
          if (right.role == CircleRole.owner) return 1;
          final leftDate =
              left.joinedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate =
              right.joinedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return leftDate.compareTo(rightDate);
        });
        return memberships;
      });

  Stream<CircleMembership?> watchMembership(String groupId, String userId) =>
      _client
          .collection('groups')
          .doc(groupId)
          .collection('publicMembers')
          .doc(userId)
          .snapshots()
          .map((snapshot) {
            final data = snapshot.data();
            if (!snapshot.exists || data == null) return null;
            final membership = CircleMembership.fromMap(snapshot.id, data);
            return membership.isActive ? membership : null;
          });

  Future<bool> hasAnyGroup(User user) async {
    final snapshot = await _client
        .collection('groups')
        .where('memberIds', arrayContains: user.uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<String> createGroup(User owner, String name) async {
    final trimmedName = CircleNamePolicy.normalize(name);
    final validation = CircleNamePolicy.validate(trimmedName);
    if (validation != null) throw ArgumentError(validation);
    final response = await _functionClient.httpsCallable('createCircle').call({
      'name': trimmedName,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['circleId'] as String;
  }

  Future<void> renameGroup(FamilyGroup group, String name) {
    final trimmedName = CircleNamePolicy.normalize(name);
    final validation = CircleNamePolicy.validate(trimmedName);
    if (validation != null) throw ArgumentError(validation);
    if (trimmedName == group.name.trim()) return Future.value();
    return _client.collection('groups').doc(group.id).update({
      'name': trimmedName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeMember(FamilyGroup group, String memberUserId) =>
      _callLifecycle('removeCircleMember', {
        'circleId': group.id,
        'memberUserId': memberUserId,
      });

  Future<void> leaveGroup(FamilyGroup group) =>
      _callLifecycle('leaveCircle', {'circleId': group.id});

  /// Marks the Circle deleted through a trusted server operation. Related
  /// records remain as an auditable tombstone instead of being partially
  /// removed by several client batches.
  Future<void> deleteGroup(FamilyGroup group) async {
    await _callLifecycle('deleteCircle', {'circleId': group.id});
  }

  Future<void> setEmergencyRecipients(FamilyGroup group, List<String> userIds) {
    final uniqueIds = userIds.toSet().toList();
    if (uniqueIds.isEmpty ||
        uniqueIds.any((userId) => !group.memberIds.contains(userId))) {
      throw ArgumentError(
        'Choose at least one active Circle member as an emergency recipient.',
      );
    }
    return _client.collection('groups').doc(group.id).update({
      'emergencyRecipientIds': uniqueIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _callLifecycle(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    await _functionClient.httpsCallable(functionName).call(data);
  }

  static List<String> _strings(Object? value) => value is List
      ? value.whereType<String>().where((item) => item.isNotEmpty).toList()
      : const [];
}
