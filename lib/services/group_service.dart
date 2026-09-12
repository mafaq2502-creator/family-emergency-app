// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/domain/circle_policies.dart';
import '../models/circle_membership.dart';
import '../models/family_group.dart';
import '../models/circle_role.dart';

class GroupService {
  GroupService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _firestore = firestore,
      _functions = functions;
  FirebaseFirestore? _firestore;
  FirebaseFunctions? _functions;
  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;
  FirebaseFunctions get _functionClient =>
      _functions ??= FirebaseFunctions.instance;

  Stream<List<FamilyGroup>> watchGroups(User user) => _client
      .collection('groups')
      .where('memberIds', arrayContains: user.uid)
      .where('status', isEqualTo: 'active')
      .snapshots(includeMetadataChanges: true)
      // A local batch can still be rejected by rules. Keep the last confirmed
      // list until the server acknowledges it (including metadata-only acks).
      .where((snapshot) => !snapshot.metadata.hasPendingWrites)
      .map(
        (snapshot) => snapshot.docs
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
            .toList(),
      );

  Stream<FamilyGroup?> watchGroupForUser(String groupId, String userId) =>
      _client.collection('groups').doc(groupId).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return null;
        final memberIds = _strings(data['memberIds']);
        if (!memberIds.contains(userId)) return null;
        final roles = Map<String, dynamic>.from(data['roles'] as Map? ?? {});
        final group = FamilyGroup.fromMap(snapshot.id, {
          ...data,
          'role': roles[userId],
        });
        return group.isActive ? group : null;
      });

  Stream<List<CircleMembership>> watchMemberships(String groupId) => _client
      .collection('groups')
      .doc(groupId)
      .collection('memberships')
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
          .collection('memberships')
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
    final response = await _functionClient
        .httpsCallable('createCircle')
        .call({'name': trimmedName});
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['circleId'] as String;
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

  // Retained as a migration utility for projects moving existing tombstones.
  // ignore: unused_element
  Future<void> _deleteGroupWithClientBatch(FamilyGroup group) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: 'Please sign in again.',
      );
    }
    final groupRef = _client.collection('groups').doc(group.id);
    final groupSnapshot = await groupRef.get();
    final data = groupSnapshot.data();
    if (!groupSnapshot.exists || data == null || data['status'] != 'active') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'This family Circle is no longer available.',
      );
    }
    if (data['ownerId'] != user.uid ||
        Map<String, dynamic>.from(data['roles'] as Map? ?? {})[user.uid] !=
            CircleRole.owner.value) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Only the Circle owner can delete this Circle.',
      );
    }
    final memberships = await groupRef.collection('memberships').get();
    final invites = await _client
        .collection('circleInvites')
        .where('circleId', isEqualTo: group.id)
        .get();
    final requests = await groupRef
        .collection('joinRequests')
        .where('status', isEqualTo: 'pending')
        .get();
    final devices = await groupRef.collection('devices').get();
    final notifications = await _client
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('groupId', isEqualTo: group.id)
        .get();
    if (memberships.size +
            invites.size +
            requests.size +
            devices.size +
            notifications.size +
            2 >
        450) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'failed-precondition',
        message: 'This Circle requires server cleanup. No data was changed.',
      );
    }
    final profileRef = _client.collection('users').doc(user.uid);
    final profile = await profileRef.get();
    final batch = _client.batch();
    final now = FieldValue.serverTimestamp();
    batch.update(groupRef, {
      'status': 'deleted',
      'deletedAt': now,
      'deletedBy': user.uid,
      'memberIds': <String>[],
      'roles': <String, String>{},
      'emergencyRecipientIds': <String>[],
      'updatedAt': now,
    });
    for (final membership in memberships.docs) {
      batch.update(membership.reference, {
        'status': 'removed',
        'endedAt': now,
        'endedBy': user.uid,
        'updatedAt': now,
      });
    }
    for (final invite in invites.docs) {
      batch.update(invite.reference, {
        'status': 'revoked',
        'revokedAt': now,
        'revokedBy': user.uid,
        'updatedAt': now,
      });
    }
    for (final request in requests.docs) {
      batch.update(request.reference, {
        'status': 'rejected',
        'reviewedAt': now,
        'reviewedBy': user.uid,
        'updatedAt': now,
      });
    }
    for (final device in devices.docs) {
      batch.update(device.reference, {
        'pairingStatus': 'unpaired',
        'removedAt': now,
        'removedBy': user.uid,
        'updatedAt': now,
      });
    }
    for (final notification in notifications.docs) {
      batch.delete(notification.reference);
    }
    batch.set(profileRef, {
      'circleIds': FieldValue.arrayRemove([group.id]),
      if (profile.data()?['activeCircleId'] == group.id)
        'activeCircleId': FieldValue.delete(),
      'updatedAt': now,
    }, SetOptions(merge: true));
    await batch.commit();
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
