import 'dart:async';

import 'package:family_emergency_app/models/circle_invite.dart';
import 'package:family_emergency_app/models/circle_join_request.dart';
import 'package:family_emergency_app/models/circle_role.dart';
import 'package:family_emergency_app/models/family_group.dart';
import 'package:family_emergency_app/services/circle_join_service.dart';

const fakeInviteCode = 'ABCDEFGHJKLMNPQRSTUV2345';

CircleInvite fakeInvite({
  CircleInviteStatus status = CircleInviteStatus.active,
  DateTime? expiresAt,
}) => CircleInvite(
  id: fakeInviteCode,
  circleId: 'circle-1',
  circleName: 'Khan Family',
  createdBy: 'owner-1',
  code: fakeInviteCode,
  role: CircleRole.adult,
  status: status,
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 7)),
  maxUses: 20,
  requiresApproval: true,
);

class FakeCircleJoinService extends CircleJoinService {
  FakeCircleJoinService({
    CircleInvite? invite,
    this.submissionStatus = JoinSubmissionStatus.pending,
    List<CircleJoinRequest> requests = const [],
    CircleJoinRequest? myRequest,
  }) : invite = invite ?? fakeInvite(),
       requests = List.of(requests),
       myRequest =
           myRequest ??
           const CircleJoinRequest(
             id: 'requester-1',
             circleId: 'circle-1',
             userUid: 'requester-1',
             inviteId: fakeInviteCode,
             displayName: 'Requester',
             relationship: 'Relative',
             email: 'requester@example.test',
             role: CircleRole.adult,
             status: JoinRequestStatus.pending,
           );

  final CircleInvite invite;
  final JoinSubmissionStatus submissionStatus;
  final List<CircleJoinRequest> requests;
  final CircleJoinRequest? myRequest;
  int validateCalls = 0;
  int submitCalls = 0;
  int createCalls = 0;
  int revokeCalls = 0;
  int reviewCalls = 0;

  @override
  Future<CircleInvite> createInvite(
    FamilyGroup group, {
    CircleRole circleRole = CircleRole.adult,
    Duration lifetime = const Duration(days: 7),
    int maxUses = 20,
  }) async {
    createCalls++;
    return invite;
  }

  @override
  Future<CircleInvite> validateInvite(String value) async {
    validateCalls++;
    return invite;
  }

  @override
  Future<JoinSubmissionResult> submitJoinRequest(String value) async {
    submitCalls++;
    return JoinSubmissionResult(
      circleId: invite.circleId,
      circleName: invite.circleName,
      status: submissionStatus,
    );
  }

  @override
  Stream<List<CircleInvite>> watchInvites(String circleId) =>
      Stream.value(const []);

  @override
  Stream<CircleInvite?> watchInvite(String inviteId) => Stream.value(invite);

  @override
  Stream<List<CircleJoinRequest>> watchPendingRequests(String circleId) =>
      Stream.value(requests);

  @override
  Stream<CircleJoinRequest?> watchMyRequest(String circleId) =>
      Stream.value(myRequest);

  @override
  Future<void> revokeInvite(CircleInvite invite) async => revokeCalls++;

  @override
  Future<void> reviewRequest(
    FamilyGroup group,
    CircleJoinRequest request, {
    required bool approve,
  }) async {
    reviewCalls++;
  }

  @override
  Future<void> clearPendingRequestReference() async {}

  @override
  Future<void> cancelRequest(CircleJoinRequest request) async {}
}
