// ignore_for_file: prefer_initializing_formals

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/domain/invite_code_policy.dart';
import '../models/circle_invite.dart';
import '../models/circle_join_request.dart';
import '../models/circle_role.dart';
import '../models/family_group.dart';

abstract interface class CircleJoinActions {
  Future<JoinSubmissionResult> joinWithCode(String code);
}

enum JoinSubmissionStatus { pending, alreadyPending, existingMember }

class JoinSubmissionResult {
  const JoinSubmissionResult({
    required this.circleId,
    required this.circleName,
    required this.status,
  });

  final String circleId;
  final String circleName;
  final JoinSubmissionStatus status;
}

class CircleInviteException implements Exception {
  const CircleInviteException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => message;
}

class CircleJoinService implements CircleJoinActions {
  CircleJoinService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Random? secureRandom,
  }) : _firestore = firestore,
       _auth = auth,
       _random = secureRandom ?? Random.secure();

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  final Random _random;

  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;
  FirebaseAuth get _authClient => _auth ??= FirebaseAuth.instance;

  User get _user {
    final user = _authClient.currentUser;
    if (user == null) {
      throw const CircleInviteException(
        'unauthenticated',
        'Your session expired. Please sign in again.',
      );
    }
    return user;
  }

  String generateCode() => List.generate(
    InviteCodePolicy.length,
    (_) =>
        InviteCodePolicy.alphabet[_random.nextInt(
          InviteCodePolicy.alphabet.length,
        )],
  ).join();

  Future<CircleInvite> createInvite(
    FamilyGroup group, {
    CircleRole circleRole = CircleRole.adult,
    Duration lifetime = const Duration(days: 7),
    int maxUses = 20,
  }) async {
    final user = _user;
    if (!group.role.canManageCircle || !group.isActive) {
      throw const CircleInviteException(
        'permission-denied',
        'Only a Circle owner or parent can create invitations.',
      );
    }
    if (maxUses < 1 || maxUses > 100) {
      throw const CircleInviteException(
        'invalid-argument',
        'The invitation use limit is invalid.',
      );
    }
    final code = generateCode();
    final expiresAt = DateTime.now().toUtc().add(lifetime);
    await _client.collection('circleInvites').doc(code).set({
      'circleId': group.id,
      'circleName': group.name,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'status': CircleInviteStatus.active.name,
      'inviteType': 'multiUse',
      'maxUses': maxUses,
      'useCount': 0,
      'requiresApproval': true,
      'circleRole': circleRole.value,
    });
    return CircleInvite(
      id: code,
      circleId: group.id,
      circleName: group.name,
      createdBy: user.uid,
      code: code,
      role: circleRole,
      status: CircleInviteStatus.active,
      expiresAt: expiresAt,
      maxUses: maxUses,
      requiresApproval: true,
    );
  }

  Future<CircleInvite> validateInvite(String value) async {
    final validation = InviteCodePolicy.validate(value);
    if (validation != null) {
      throw CircleInviteException('invalid-argument', validation);
    }
    final code = InviteCodePolicy.normalize(value);
    final snapshot = await _client.collection('circleInvites').doc(code).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) throw _invalidInvite;
    final invite = CircleInvite.fromMap(snapshot.id, data);
    if (!invite.isUsable ||
        invite.circleId.isEmpty ||
        invite.createdBy.isEmpty ||
        !invite.requiresApproval) {
      throw _invalidInvite;
    }
    return invite;
  }

  @override
  Future<JoinSubmissionResult> joinWithCode(String code) =>
      submitJoinRequest(code);

  Future<JoinSubmissionResult> submitJoinRequest(String value) async {
    final user = _user;
    final invite = await validateInvite(value);
    try {
      final group = await _client
          .collection('groups')
          .doc(invite.circleId)
          .get();
      if (_strings(group.data()?['memberIds']).contains(user.uid)) {
        return JoinSubmissionResult(
          circleId: invite.circleId,
          circleName: invite.circleName,
          status: JoinSubmissionStatus.existingMember,
        );
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
    }

    final profileRef = _client.collection('users').doc(user.uid);
    final requestRef = _client
        .collection('groups')
        .doc(invite.circleId)
        .collection('joinRequests')
        .doc(user.uid);
    final status = await _client.runTransaction<JoinSubmissionStatus>((
      tx,
    ) async {
      final inviteRef = _client.collection('circleInvites').doc(invite.id);
      final inviteSnapshot = await tx.get(inviteRef);
      final requestSnapshot = await tx.get(requestRef);
      final profileSnapshot = await tx.get(profileRef);
      final data = inviteSnapshot.data();
      if (!inviteSnapshot.exists || data == null) throw _invalidInvite;
      final liveInvite = CircleInvite.fromMap(inviteSnapshot.id, data);
      if (!liveInvite.isUsable || liveInvite.circleId != invite.circleId) {
        throw _invalidInvite;
      }
      if (requestSnapshot.exists &&
          requestSnapshot.data()?['status'] == JoinRequestStatus.pending.name) {
        return JoinSubmissionStatus.alreadyPending;
      }
      final profile = profileSnapshot.data() ?? const <String, dynamic>{};
      final now = FieldValue.serverTimestamp();
      tx.set(requestRef, {
        'circleId': invite.circleId,
        'userUid': user.uid,
        'inviteId': invite.id,
        'displayName': _text(
          profile['name'],
          user.displayName ?? 'Family member',
        ),
        'email': _text(profile['email'], user.email ?? ''),
        'relationship': _text(profile['relationship'], 'Family member'),
        'circleRole': invite.role == CircleRole.child ? 'child' : 'adult',
        'status': JoinRequestStatus.pending.name,
        'requestedAt': now,
        'updatedAt': now,
      });
      tx.set(profileRef, {
        'pendingJoinCircleId': invite.circleId,
        'pendingJoinInviteId': invite.id,
        'updatedAt': now,
      }, SetOptions(merge: true));
      return JoinSubmissionStatus.pending;
    });
    return JoinSubmissionResult(
      circleId: invite.circleId,
      circleName: invite.circleName,
      status: status,
    );
  }

  Stream<CircleJoinRequest?> watchMyRequest(String circleId) {
    final user = _user;
    return _client
        .collection('groups')
        .doc(circleId)
        .collection('joinRequests')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data == null
              ? null
              : CircleJoinRequest.fromMap(snapshot.id, data);
        });
  }

  Stream<List<CircleJoinRequest>> watchPendingRequests(String circleId) =>
      _client
          .collection('groups')
          .doc(circleId)
          .collection('joinRequests')
          .where('status', isEqualTo: JoinRequestStatus.pending.name)
          .snapshots()
          .map((snapshot) {
            final requests = snapshot.docs
                .map((doc) => CircleJoinRequest.fromMap(doc.id, doc.data()))
                .where((request) => request.isPending)
                .toList();
            requests.sort(
              (a, b) => (a.requestedAt ?? DateTime(0)).compareTo(
                b.requestedAt ?? DateTime(0),
              ),
            );
            return requests;
          });

  Stream<List<CircleInvite>> watchInvites(String circleId) => _client
      .collection('circleInvites')
      .where('circleId', isEqualTo: circleId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => CircleInvite.fromMap(doc.id, doc.data()))
            .toList(),
      );

  Stream<CircleInvite?> watchInvite(String inviteId) => _client
      .collection('circleInvites')
      .doc(inviteId)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        return data == null ? null : CircleInvite.fromMap(snapshot.id, data);
      });

  Future<void> revokeInvite(CircleInvite invite) async {
    final user = _user;
    if (invite.status != CircleInviteStatus.active) {
      throw const CircleInviteException(
        'failed-precondition',
        'This invitation is no longer active.',
      );
    }
    final now = FieldValue.serverTimestamp();
    await _client.collection('circleInvites').doc(invite.id).update({
      'status': CircleInviteStatus.revoked.name,
      'revokedAt': now,
      'revokedBy': user.uid,
      'updatedAt': now,
    });
  }

  Future<void> cancelRequest(CircleJoinRequest request) async {
    final user = _user;
    if (request.userUid != user.uid || !request.isPending) return;
    final batch = _client.batch();
    batch.update(
      _client
          .collection('groups')
          .doc(request.circleId)
          .collection('joinRequests')
          .doc(request.userUid),
      {
        'status': JoinRequestStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(_profileRef(user.uid), {
      'pendingJoinCircleId': FieldValue.delete(),
      'pendingJoinInviteId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> clearPendingRequestReference() async {
    final user = _user;
    await _profileRef(user.uid).set({
      'pendingJoinCircleId': FieldValue.delete(),
      'pendingJoinInviteId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reviewRequest(
    FamilyGroup group,
    CircleJoinRequest request, {
    required bool approve,
  }) async {
    final reviewer = _user;
    if (!group.role.canManageCircle || !request.isPending) {
      throw const CircleInviteException(
        'permission-denied',
        'This join request cannot be reviewed.',
      );
    }
    final groupRef = _client.collection('groups').doc(group.id);
    final requestRef = groupRef.collection('joinRequests').doc(request.userUid);
    final targetProfileRef = _profileRef(request.userUid);
    await _client.runTransaction((tx) async {
      final groupSnapshot = await tx.get(groupRef);
      final requestSnapshot = await tx.get(requestRef);
      final currentRequest = requestSnapshot.data();
      if (!groupSnapshot.exists ||
          currentRequest == null ||
          currentRequest['status'] != JoinRequestStatus.pending.name) {
        throw const CircleInviteException(
          'failed-precondition',
          'This join request was already reviewed.',
        );
      }
      final now = FieldValue.serverTimestamp();
      if (!approve) {
        tx.update(requestRef, {
          'status': JoinRequestStatus.rejected.name,
          'reviewedBy': reviewer.uid,
          'reviewedAt': now,
          'updatedAt': now,
        });
        return;
      }
      final inviteId = _text(currentRequest['inviteId'], '');
      final inviteRef = _client.collection('circleInvites').doc(inviteId);
      final membershipRef = groupRef
          .collection('memberships')
          .doc(request.userUid);
      final inviteSnapshot = await tx.get(inviteRef);
      final membershipSnapshot = await tx.get(membershipRef);
      final inviteData = inviteSnapshot.data();
      if (!inviteSnapshot.exists || inviteData == null) throw _invalidInvite;
      final invite = CircleInvite.fromMap(inviteSnapshot.id, inviteData);
      if (!invite.isUsable || invite.circleId != group.id) throw _invalidInvite;
      if (membershipSnapshot.data()?['status'] == 'active') {
        throw const CircleInviteException(
          'already-exists',
          'This person is already a Circle member.',
        );
      }
      final groupData = groupSnapshot.data()!;
      if (_strings(groupData['memberIds']).contains(request.userUid)) {
        throw const CircleInviteException(
          'already-exists',
          'This person is already a Circle member.',
        );
      }
      final roles = Map<String, dynamic>.from(groupData['roles'] as Map? ?? {});
      final assignedRole = request.role == CircleRole.child ? 'child' : 'adult';
      roles[request.userUid] = assignedRole;
      final nextUseCount = invite.useCount + 1;
      tx.update(groupRef, {
        'memberIds': FieldValue.arrayUnion([request.userUid]),
        'roles': roles,
        'lastApprovedUserId': request.userUid,
        'updatedAt': now,
      });
      tx.set(membershipRef, {
        'userId': request.userUid,
        'displayName': request.displayName,
        'email': request.email,
        'relationship': request.relationship,
        'circleRole': assignedRole,
        'status': 'active',
        'joinedAt': now,
        'updatedAt': now,
      });
      tx.update(requestRef, {
        'status': JoinRequestStatus.approved.name,
        'reviewedBy': reviewer.uid,
        'reviewedAt': now,
        'updatedAt': now,
      });
      tx.update(inviteRef, {
        'useCount': nextUseCount,
        'status': nextUseCount >= invite.maxUses
            ? CircleInviteStatus.exhausted.name
            : CircleInviteStatus.active.name,
        'updatedAt': now,
      });
      tx.set(targetProfileRef, {
        'onboardingCompleted': true,
        'activeCircleId': group.id,
        'circleIds': FieldValue.arrayUnion([group.id]),
        'pendingJoinCircleId': FieldValue.delete(),
        'pendingJoinInviteId': FieldValue.delete(),
        'updatedAt': now,
      }, SetOptions(merge: true));
    });
  }

  DocumentReference<Map<String, dynamic>> _profileRef(String userId) =>
      _client.collection('users').doc(userId);

  static const _invalidInvite = CircleInviteException(
    'invalid-invite',
    'This invite code is invalid or no longer available.',
  );

  static List<String> _strings(Object? value) => value is List
      ? value.whereType<String>().where((item) => item.isNotEmpty).toList()
      : const [];

  static String _text(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}
