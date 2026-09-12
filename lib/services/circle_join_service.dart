// ignore_for_file: prefer_initializing_formals

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
    FirebaseFunctions? functions,
    Random? secureRandom,
  }) : _firestore = firestore,
       _auth = auth,
       _functions = functions,
       _random = secureRandom ?? Random.secure();

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  FirebaseFunctions? _functions;
  final Random _random;

  FirebaseFirestore get _client => _firestore ??= FirebaseFirestore.instance;
  FirebaseAuth get _authClient => _auth ??= FirebaseAuth.instance;
  FirebaseFunctions get _functionClient =>
      _functions ??= FirebaseFunctions.instance;

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
    int maxUses = 1,
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
    final response = await _functionClient.httpsCallable('createCircleInvite').call({
      'circleId': group.id,
      'circleRole': circleRole.value,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final code = data['id'] as String;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      data['expiresAtMillis'] as int,
      isUtc: true,
    );
    return CircleInvite(
      id: code,
      circleId: group.id,
      circleName: group.name,
      createdBy: user.uid,
      code: code,
      role: circleRole,
      status: CircleInviteStatus.active,
      expiresAt: expiresAt,
      maxUses: 1,
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
    if (invite.status == CircleInviteStatus.consumed ||
        invite.status == CircleInviteStatus.exhausted) {
      throw const CircleInviteException(
        'invite-consumed',
        'This invitation has already been used.',
      );
    }
    if (invite.status == CircleInviteStatus.revoked) {
      throw const CircleInviteException(
        'invite-revoked',
        'This invitation has been revoked.',
      );
    }
    if (!invite.expiresAt.isAfter(DateTime.now())) {
      throw const CircleInviteException(
        'invite-expired',
        'This invitation has expired.',
      );
    }
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
    _user;
    final normalized = InviteCodePolicy.normalize(value);
    final response = await _functionClient
        .httpsCallable('submitCircleJoinRequest')
        .call({'code': normalized});
    final data = Map<String, dynamic>.from(response.data as Map);
    final status = JoinSubmissionStatus.values.firstWhere(
      (item) => item.name == data['status'],
      orElse: () => JoinSubmissionStatus.pending,
    );
    return JoinSubmissionResult(
      circleId: data['circleId'] as String,
      circleName: data['circleName'] as String? ?? 'Family Circle',
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
    _user;
    if (invite.status != CircleInviteStatus.active) {
      throw const CircleInviteException(
        'failed-precondition',
        'This invitation is no longer active.',
      );
    }
    await _functionClient
        .httpsCallable('revokeCircleInvite')
        .call({'code': invite.id});
  }

  Future<void> cancelRequest(CircleJoinRequest request) async {
    final user = _user;
    if (request.userUid != user.uid || !request.isPending) return;
    await _functionClient
        .httpsCallable('cancelCircleJoinRequest')
        .call({'circleId': request.circleId});
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
    _user;
    if (!group.role.canManageCircle || !request.isPending) {
      throw const CircleInviteException(
        'permission-denied',
        'This join request cannot be reviewed.',
      );
    }
    await _functionClient.httpsCallable('reviewCircleJoinRequest').call({
      'circleId': group.id,
      'userId': request.userUid,
      'approve': approve,
    });
  }

  DocumentReference<Map<String, dynamic>> _profileRef(String userId) =>
      _client.collection('users').doc(userId);

  static const _invalidInvite = CircleInviteException(
    'invalid-invite',
    'This invite code is invalid or no longer available.',
  );

}
