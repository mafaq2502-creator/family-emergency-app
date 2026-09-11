import 'package:family_emergency_app/models/circle_invite.dart';
import 'package:family_emergency_app/models/circle_membership.dart';
import 'package:family_emergency_app/models/circle_role.dart';
import 'package:family_emergency_app/models/paired_device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircleRole', () {
    test('keeps relationship separate from permissions', () {
      expect(CircleRole.fromValue('owner'), CircleRole.owner);
      expect(CircleRole.fromValue('parent').canManageCircle, isTrue);
      expect(CircleRole.fromValue('child').canManageCircle, isFalse);
    });

    test('maps legacy admin to parent during migration', () {
      expect(CircleRole.fromValue('admin'), CircleRole.parent);
    });
  });

  test('membership parses independent relationship and Circle role', () {
    final membership = CircleMembership.fromMap('user-1', {
      'displayName': 'Sara',
      'relationship': 'Daughter',
      'circleRole': 'child',
      'status': 'active',
    });

    expect(membership.relationship, 'Daughter');
    expect(membership.role, CircleRole.child);
    expect(membership.isActive, isTrue);
  });

  test('invite is usable only before expiry and use limit', () {
    final invite = CircleInvite(
      id: 'invite-1',
      circleId: 'circle-1',
      circleName: 'Khan Family',
      createdBy: 'owner-1',
      code: 'ABC123',
      role: CircleRole.adult,
      status: CircleInviteStatus.active,
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );

    expect(invite.isUsable, isTrue);
  });

  test('device online state is derived from last heartbeat', () {
    final now = DateTime(2026, 9, 7, 12);
    final device = PairedDevice(
      id: 'device-1',
      userId: 'user-1',
      name: 'Child phone',
      model: 'Pixel',
      platform: 'android',
      pairingStatus: DevicePairingStatus.paired,
      lastSeenAt: now.subtract(const Duration(minutes: 5)),
    );

    expect(device.isOnline(now), isTrue);
    expect(device.isOnline(now.add(const Duration(minutes: 20))), isFalse);
  });
}
