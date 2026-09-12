import 'dart:async';

import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:family_emergency_app/core/domain/circle_policies.dart';
import 'package:family_emergency_app/core/theme/app_colors.dart';
import 'package:family_emergency_app/features/groups/presentation/group_members_screen.dart';
import 'package:family_emergency_app/features/groups/presentation/group_settings_screen.dart';
import 'package:family_emergency_app/models/circle_membership.dart';
import 'package:family_emergency_app/models/circle_role.dart';
import 'package:family_emergency_app/models/family_group.dart';
import 'package:family_emergency_app/models/user_profile.dart';
import 'package:family_emergency_app/services/group_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_device_service.dart';

const owner = CircleMembership(
  userId: 'owner-1',
  displayName: 'Circle Owner',
  relationship: 'Self',
  role: CircleRole.owner,
  status: MembershipStatus.active,
);

const adult = CircleMembership(
  userId: 'adult-1',
  displayName: 'A very long registered family member name',
  relationship: 'Brother',
  role: CircleRole.adult,
  status: MembershipStatus.active,
  email: 'adult@example.com',
);

FamilyGroup circle(CircleRole role) => FamilyGroup(
  id: 'circle-1',
  name: 'Khan Family',
  ownerId: 'owner-1',
  role: role,
  memberIds: const ['owner-1', 'adult-1'],
  emergencyRecipientIds: const ['owner-1'],
);

class FakeGroupService extends GroupService {
  FakeGroupService({
    required this.group,
    required this.members,
    this.failDelete = false,
  });

  final FamilyGroup group;
  final List<CircleMembership> members;
  final bool failDelete;
  final membershipController =
      StreamController<List<CircleMembership>>.broadcast();
  int removeCalls = 0;
  int leaveCalls = 0;
  int deleteCalls = 0;
  int renameCalls = 0;

  @override
  Stream<FamilyGroup?> watchGroupForUser(String groupId, String userId) =>
      Stream.value(group);

  @override
  Stream<List<CircleMembership>> watchMemberships(String groupId) async* {
    yield members;
    yield* membershipController.stream;
  }

  @override
  Stream<CircleMembership?> watchMembership(String groupId, String userId) =>
      watchMemberships(groupId).map(
        (items) => items.where((item) => item.userId == userId).firstOrNull,
      );

  @override
  Future<void> removeMember(FamilyGroup group, String memberUserId) async {
    removeCalls++;
    membershipController.add(
      members.where((item) => item.userId != memberUserId).toList(),
    );
  }

  @override
  Future<void> leaveGroup(FamilyGroup group) async => leaveCalls++;

  @override
  Future<void> deleteGroup(FamilyGroup group) async {
    deleteCalls++;
    if (failDelete) throw StateError('delete failed');
  }

  @override
  Future<void> renameGroup(FamilyGroup group, String name) async =>
      renameCalls++;

  @override
  Future<void> setEmergencyRecipients(
    FamilyGroup group,
    List<String> userIds,
  ) async {}

  void dispose() => membershipController.close();
}

void main() {
  group('Circle name policy', () {
    test('accepts normal, Unicode, punctuation, and exact boundaries', () {
      for (final value in [
        'My Family',
        'Khan Family',
        'Home',
        'Ali & Sara’s Family',
        'خاندان',
        'ab',
        'a' * CircleNamePolicy.maxLength,
      ]) {
        expect(CircleNamePolicy.validate(value), isNull, reason: value);
      }
      expect(CircleNamePolicy.normalize('  Khan Family  '), 'Khan Family');
    });

    test('rejects missing, boundary, and control-character values', () {
      expect(CircleNamePolicy.validate(null), isNotNull);
      expect(CircleNamePolicy.validate(''), isNotNull);
      expect(CircleNamePolicy.validate('   '), isNotNull);
      expect(CircleNamePolicy.validate('a'), isNotNull);
      expect(
        CircleNamePolicy.validate('a' * (CircleNamePolicy.maxLength + 1)),
        isNotNull,
      );
      expect(CircleNamePolicy.validate('Family\u0000Name'), isNotNull);
    });
  });

  group('Circle permissions', () {
    test('owner, parent, adult and malformed roles use least privilege', () {
      expect(CirclePermissionPolicy.canDelete(CircleRole.owner), isTrue);
      expect(CirclePermissionPolicy.canDelete(CircleRole.parent), isFalse);
      expect(CirclePermissionPolicy.canLeave(CircleRole.owner), isFalse);
      expect(CirclePermissionPolicy.canLeave(CircleRole.adult), isTrue);
      expect(
        CirclePermissionPolicy.canRemove(
          actorRole: CircleRole.owner,
          target: adult,
          actorUserId: owner.userId,
        ),
        isTrue,
      );
      expect(
        CirclePermissionPolicy.canRemove(
          actorRole: CircleRole.parent,
          target: owner,
          actorUserId: 'parent-1',
        ),
        isFalse,
      );
      expect(CircleRole.fromValue('super_owner'), CircleRole.adult);
      expect(CircleRole.fromValue(null), CircleRole.adult);
    });
  });

  test('malformed Circle and membership data parse without privilege gain', () {
    final malformedCircle = FamilyGroup.fromMap('bad', {
      'name': null,
      'ownerId': null,
      'memberIds': '5',
      'role': 'super_owner',
      'status': 'corrupt',
    });
    expect(malformedCircle.name, 'Unavailable Circle');
    expect(malformedCircle.memberCount, 0);
    expect(malformedCircle.role, CircleRole.adult);
    expect(malformedCircle.isActive, isFalse);

    final malformedMember = CircleMembership.fromMap('member-1', {
      'displayName': null,
      'relationship': null,
      'circleRole': 'super_owner',
      'status': null,
    });
    expect(malformedMember.displayName, 'Family member');
    expect(malformedMember.relationship, 'Not specified');
    expect(malformedMember.role, CircleRole.adult);
    expect(malformedMember.isActive, isFalse);
  });

  test('user profile safely parses multi-Circle references', () {
    final profile = UserProfile.fromData(
      uid: 'adult-1',
      data: const {
        'name': 'Adult',
        'email': 'adult@example.com',
        'phone': '+923001234567',
        'relationship': 'Brother',
        'profileCompleted': true,
        'onboardingCompleted': true,
        'activeCircleId': 'circle-1',
        'circleIds': ['circle-1', 5, '', 'circle-2'],
      },
    );
    expect(profile.activeCircleId, 'circle-1');
    expect(profile.circleIds, ['circle-1', 'circle-2']);
  });

  test('emergency recipients must be active embedded Circle members', () {
    final service = GroupService();
    expect(
      () => service.setEmergencyRecipients(circle(CircleRole.owner), const []),
      throwsArgumentError,
    );
    expect(
      () => service.setEmergencyRecipients(circle(CircleRole.owner), const [
        'outsider-1',
      ]),
      throwsArgumentError,
    );
  });

  testWidgets(
    'Circle Detail renders real memberships and opens Member Detail',
    (tester) async {
      final service = FakeGroupService(
        group: circle(CircleRole.owner),
        members: const [owner, adult],
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(
        FamilyEmergencyApp(
          home: GroupMembersScreen(
            group: service.group,
            viewerId: owner.userId,
            groupService: service,
            deviceService: FakeDeviceService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 members'), findsOneWidget);
      expect(find.text(adult.displayName), findsOneWidget);
      await tester.tap(find.text(adult.displayName));
      await tester.pumpAndSettle();
      expect(find.text('Member Detail'), findsOneWidget);
      expect(
        find.text('No screen-time or location data is available in Phase 5'),
        findsOneWidget,
      );
      expect(find.text('Remove Member'), findsOneWidget);
    },
  );

  testWidgets('normal member sees Leave and no owner actions', (tester) async {
    final service = FakeGroupService(
      group: circle(CircleRole.adult),
      members: const [owner, adult],
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: GroupSettingsScreen(
          group: service.group,
          memberships: service.members,
          viewerId: adult.userId,
          groupService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leave Circle'), findsOneWidget);
    expect(find.text('Rename Circle'), findsNothing);
    expect(find.text('Delete Circle'), findsNothing);

    await tester.tap(find.text('Leave Circle'));
    await tester.pumpAndSettle();
    expect(find.text('Leave Circle?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Leave Circle'));
    await tester.pumpAndSettle();
    expect(service.leaveCalls, 1);
  });

  testWidgets('owner removal requires confirmation and submits once', (
    tester,
  ) async {
    final service = FakeGroupService(
      group: circle(CircleRole.owner),
      members: const [owner, adult],
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: GroupMembersScreen(
          group: service.group,
          viewerId: owner.userId,
          groupService: service,
          deviceService: FakeDeviceService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(adult.displayName));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Remove Member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Member'));
    await tester.pumpAndSettle();
    expect(find.text('Remove member?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(service.removeCalls, 1);
  });

  testWidgets('Circle Detail owns the delete confirmation flow', (
    tester,
  ) async {
    final service = FakeGroupService(
      group: circle(CircleRole.owner),
      members: const [owner, adult],
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: GroupMembersScreen(
          group: service.group,
          viewerId: owner.userId,
          groupService: service,
          deviceService: FakeDeviceService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byTooltip('Delete Circle');
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Delete Circle?'), findsOneWidget);
    expect(
      find.text(
        'Are you sure you want to permanently delete this Circle? This action cannot be undone.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(service.deleteCalls, 0);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(service.deleteCalls, 1);
  });

  testWidgets('non-owner cannot see Circle delete', (tester) async {
    final service = FakeGroupService(
      group: circle(CircleRole.adult),
      members: const [owner, adult],
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: GroupMembersScreen(
          group: service.group,
          viewerId: adult.userId,
          groupService: service,
          deviceService: FakeDeviceService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete Circle'), findsNothing);
  });

  testWidgets('failed Circle delete remains on Circle Detail', (tester) async {
    final service = FakeGroupService(
      group: circle(CircleRole.owner),
      members: const [owner, adult],
      failDelete: true,
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: GroupMembersScreen(
          group: service.group,
          viewerId: owner.userId,
          groupService: service,
          deviceService: FakeDeviceService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Circle'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(service.deleteCalls, 1);
    expect(find.text('Khan Family'), findsWidgets);
    expect(find.byTooltip('Delete Circle'), findsOneWidget);
    expect(find.textContaining('could not be deleted'), findsOneWidget);
  });

  testWidgets('Circle lifecycle actions precede invite and Leave is red', (
    tester,
  ) async {
    final service = FakeGroupService(
      group: circle(CircleRole.owner),
      members: const [owner, adult],
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: GroupSettingsScreen(
          group: service.group,
          memberships: service.members,
          viewerId: owner.userId,
          groupService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList();
    expect(
      labels.indexOf('Leave Circle'),
      lessThan(labels.indexOf('Transfer Ownership')),
    );
    expect(
      labels.indexOf('Transfer Ownership'),
      lessThan(labels.indexOf('Invite registered member')),
    );
    expect(find.text('Delete Circle'), findsNothing);
    expect(
      tester.widget<Text>(find.text('Leave Circle')).style?.color,
      kEmergency,
    );
  });

  testWidgets('rename dialog blocks invalid Circle names without a write', (
    tester,
  ) async {
    final service = FakeGroupService(
      group: circle(CircleRole.owner),
      members: const [owner, adult],
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: GroupSettingsScreen(
          group: service.group,
          memberships: service.members,
          viewerId: owner.userId,
          groupService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename Circle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, ' ');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pump();
    expect(find.text('Please enter a family Circle name.'), findsOneWidget);
    expect(service.renameCalls, 0);
  });
}
