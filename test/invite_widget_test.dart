import 'dart:async';

import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:family_emergency_app/features/groups/presentation/join_circle_screen.dart';
import 'package:family_emergency_app/features/groups/presentation/join_requests_screen.dart';
import 'package:family_emergency_app/features/groups/presentation/share_circle_screen.dart';
import 'package:family_emergency_app/models/circle_invite.dart';
import 'package:family_emergency_app/models/circle_join_request.dart';
import 'package:family_emergency_app/models/circle_role.dart';
import 'package:family_emergency_app/models/family_group.dart';
import 'package:family_emergency_app/services/circle_join_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_circle_join_service.dart';

const ownerGroup = FamilyGroup(
  id: 'circle-1',
  name: 'Khan Family',
  ownerId: 'owner-1',
  role: CircleRole.owner,
  memberIds: ['owner-1'],
);

const pendingRequest = CircleJoinRequest(
  id: 'requester-1',
  circleId: 'circle-1',
  userUid: 'requester-1',
  inviteId: fakeInviteCode,
  displayName: 'A very long registered requester name for layout verification',
  relationship: 'Relative',
  email: 'requester@example.test',
  role: CircleRole.adult,
  status: JoinRequestStatus.pending,
);

class SlowSubmitService extends FakeCircleJoinService {
  final completer = Completer<JoinSubmissionResult>();

  @override
  Future<JoinSubmissionResult> submitJoinRequest(String value) {
    submitCalls++;
    return completer.future;
  }
}

void main() {
  testWidgets('invalid invite field blocks network validation', (tester) async {
    final service = FakeCircleJoinService();
    await tester.pumpWidget(
      FamilyEmergencyApp(home: JoinCircleScreen(joinService: service)),
    );
    await tester.enterText(find.byType(TextFormField), 'ABC');
    await tester.tap(find.text('Check Invitation'));
    await tester.pump();
    expect(find.textContaining('24-character'), findsOneWidget);
    expect(service.validateCalls, 0);
  });

  testWidgets('valid code previews Circle and creates pending request', (
    tester,
  ) async {
    final service = FakeCircleJoinService();
    await tester.pumpWidget(
      FamilyEmergencyApp(home: JoinCircleScreen(joinService: service)),
    );
    await tester.enterText(find.byType(TextFormField), fakeInviteCode);
    await tester.tap(find.text('Check Invitation'));
    await tester.pumpAndSettle();
    expect(find.text('Khan Family'), findsWidgets);
    expect(find.text('Request to Join'), findsOneWidget);
    await tester.tap(find.text('Request to Join'));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(service.submitCalls, 1);
  });

  testWidgets('join submission prevents duplicate rapid taps', (tester) async {
    final service = SlowSubmitService();
    await tester.pumpWidget(
      FamilyEmergencyApp(home: JoinCircleScreen(joinService: service)),
    );
    await tester.enterText(find.byType(TextFormField), fakeInviteCode);
    await tester.tap(find.text('Check Invitation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request to Join'));
    await tester.tap(find.text('Request to Join'));
    await tester.pump();
    expect(service.submitCalls, 1);
    service.completer.complete(
      const JoinSubmissionResult(
        circleId: 'circle-1',
        circleName: 'Khan Family',
        status: JoinSubmissionStatus.pending,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('real QR invitation renders and exposes exact code and link', (
    tester,
  ) async {
    final service = FakeCircleJoinService();
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: ShareCircleScreen(group: ownerGroup, joinService: service),
      ),
    );
    await tester.tap(find.text('Generate Invitation'));
    await tester.pumpAndSettle();
    expect(
      find.text('Scan to preview this Circle and request approval.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Invite Code'));
    await tester.pump();
    expect(find.text('ABCD-EFGH-JKLM-NPQR-STUV-2345'), findsOneWidget);
    await tester.tap(find.text('Invite Link'));
    await tester.pump();
    expect(
      find.text('familyemergency://join?code=$fakeInviteCode'),
      findsOneWidget,
    );
  });

  testWidgets('revoked and expiring invitations disable sharing', (
    tester,
  ) async {
    for (final invite in [
      fakeInvite(status: CircleInviteStatus.revoked),
      fakeInvite(
        expiresAt: DateTime.now().add(const Duration(milliseconds: 50)),
      ),
    ]) {
      await tester.pumpWidget(
        FamilyEmergencyApp(
          home: ShareCircleScreen(
            key: ValueKey(invite.status.name + invite.expiresAt.toString()),
            group: ownerGroup,
            joinService: FakeCircleJoinService(invite: invite),
          ),
        ),
      );
      await tester.tap(find.text('Generate Invitation'));
      await tester.pump();
      if (invite.status == CircleInviteStatus.active) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.text('Expired'), findsOneWidget);
      } else {
        expect(find.text('Revoked'), findsOneWidget);
      }
      final share = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Share Invitation'),
      );
      expect(share.onPressed, isNull);
    }
  });

  testWidgets('manager can approve once and member sees no review controls', (
    tester,
  ) async {
    final managerService = FakeCircleJoinService(
      requests: const [pendingRequest],
    );
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: JoinRequestsScreen(
          group: ownerGroup,
          joinService: managerService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    expect(managerService.reviewCalls, 1);

    const adultGroup = FamilyGroup(
      id: 'circle-1',
      name: 'Khan Family',
      ownerId: 'owner-1',
      role: CircleRole.adult,
    );
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: JoinRequestsScreen(
          group: adultGroup,
          joinService: FakeCircleJoinService(requests: const [pendingRequest]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manager access required'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
  });
}
