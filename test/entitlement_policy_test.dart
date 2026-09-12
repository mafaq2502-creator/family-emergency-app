import 'package:family_emergency_app/core/domain/entitlement_policy.dart';
import 'package:family_emergency_app/models/circle_invite.dart';
import 'package:family_emergency_app/models/family_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Free owned and joined limits are independent and reusable', () {
    expect(
      CircleEntitlementPolicy.canCreate(premium: false, owned: 0),
      isTrue,
    );
    expect(
      CircleEntitlementPolicy.canCreate(premium: false, owned: 1),
      isFalse,
    );
    expect(
      CircleEntitlementPolicy.canJoin(premium: false, joined: 0),
      isTrue,
    );
    expect(
      CircleEntitlementPolicy.canJoin(premium: false, joined: 1),
      isFalse,
    );
    expect(
      CircleEntitlementPolicy.canCreate(premium: false, owned: 0),
      isTrue,
      reason: 'deleting the active owned Circle frees the slot',
    );
    expect(
      CircleEntitlementPolicy.canJoin(premium: false, joined: 0),
      isTrue,
      reason: 'leaving the active joined Circle frees the slot',
    );
  });

  test('active members and pending invite reservations share capacity', () {
    expect(
      CircleEntitlementPolicy.canReserveInvite(
        premium: false,
        activeMembers: 2,
        activeInvites: 0,
      ),
      isTrue,
    );
    expect(
      CircleEntitlementPolicy.canReserveInvite(
        premium: false,
        activeMembers: 2,
        activeInvites: 1,
      ),
      isFalse,
    );
    expect(
      CircleEntitlementPolicy.canReserveInvite(
        premium: false,
        activeMembers: 3,
        activeInvites: 0,
      ),
      isFalse,
    );
  });

  test('Circle and invite models expose Free and consumed state safely', () {
    final group = FamilyGroup.fromMap('circle', {
      'name': 'Family',
      'ownerId': 'owner',
      'memberIds': ['owner', 'a', 'b'],
      'role': 'owner',
      'status': 'active',
    });
    expect(group.memberLimit, 3);
    expect(group.isFull, isTrue);

    final invite = CircleInvite.fromMap('code', {
      'circleId': 'circle',
      'createdBy': 'owner',
      'circleName': 'Family',
      'circleRole': 'adult',
      'status': 'consumed',
      'expiresAt': null,
      'maxUses': 1,
      'useCount': 1,
      'requiresApproval': true,
    });
    expect(invite.status, CircleInviteStatus.consumed);
    expect(invite.isUsable, isFalse);
  });
}
