import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_emergency_app/core/domain/invite_code_policy.dart';
import 'package:family_emergency_app/models/circle_invite.dart';
import 'package:family_emergency_app/models/circle_join_request.dart';
import 'package:flutter_test/flutter_test.dart';

const validCode = 'ABCDEFGHJKLMNPQRSTUV2345';

void main() {
  group('InviteCodePolicy', () {
    test('normalizes exact, grouped, pasted, lowercase and QR values', () {
      expect(InviteCodePolicy.normalize(validCode), validCode);
      expect(
        InviteCodePolicy.normalize(' abcd-efgh-jklm-npqr-stuv-2345\n'),
        validCode,
      );
      expect(
        InviteCodePolicy.normalize('familyemergency://join?code=$validCode'),
        validCode,
      );
      expect(
        InviteCodePolicy.display(validCode),
        'ABCD-EFGH-JKLM-NPQR-STUV-2345',
      );
      expect(
        InviteCodePolicy.normalize(InviteCodePolicy.qrPayload(validCode)),
        validCode,
      );
      expect(
        InviteCodePolicy.inviteUrl(validCode),
        'https://familyemergencyapp.web.app/join?code=$validCode',
      );
      expect(
        InviteCodePolicy.isSupportedInviteUri(
          Uri.parse('https://familyemergencyapp.web.app/join?code=$validCode'),
        ),
        isTrue,
      );
    });

    test('rejects missing, malformed, short, long and ambiguous values', () {
      for (final value in <String?>[
        null,
        '',
        '   ',
        'ABCDEFGH',
        '${validCode}A',
        'ABCDEFGH_JKLMNPQRSTUV2345',
        'ABCDEFGHIKLMNPQRSTUV2345',
        'https://example.com/?code=$validCode',
        'https://example.com/join?code=$validCode',
      ]) {
        expect(InviteCodePolicy.validate(value), isNotNull, reason: '$value');
      }
      expect(
        InviteCodePolicy.isSupportedInviteUri(
          Uri.parse('https://example.com/join?code=$validCode'),
        ),
        isFalse,
      );
    });
  });

  test('invite parsing fails closed for malformed security fields', () {
    final malformed = CircleInvite.fromMap(validCode, {
      'circleId': null,
      'createdBy': null,
      'circleName': 5,
      'status': 'super_active',
      'expiresAt': 'tomorrow',
      'maxUses': '20',
      'useCount': -1,
      'requiresApproval': false,
      'circleRole': 'owner',
    });
    expect(malformed.status, CircleInviteStatus.unavailable);
    expect(malformed.isUsable, isFalse);
    expect(malformed.maxUses, 0);
    expect(malformed.role.name, 'adult');
  });

  test('expiration and usage limit are evaluated at an explicit time', () {
    final now = DateTime.utc(2026, 9, 11, 12);
    final invite = CircleInvite(
      id: validCode,
      circleId: 'circle-1',
      circleName: 'My Family',
      createdBy: 'owner-1',
      code: validCode,
      role: CircleInvite.fromMap(validCode, const {}).role,
      status: CircleInviteStatus.active,
      expiresAt: now.add(const Duration(seconds: 1)),
      maxUses: 1,
      requiresApproval: true,
    );
    expect(invite.isUsableAt(now), isTrue);
    expect(invite.isUsableAt(now.add(const Duration(seconds: 1))), isFalse);
  });

  test('join request parsing never promotes malformed state or role', () {
    final request = CircleJoinRequest.fromMap('requester-1', {
      'circleId': null,
      'userUid': null,
      'inviteId': null,
      'status': 'super_approved',
      'circleRole': 'owner',
      'requestedAt': Timestamp.fromDate(DateTime.utc(2026)),
    });
    expect(request.status, JoinRequestStatus.unavailable);
    expect(request.role.name, 'adult');
    expect(request.isPending, isFalse);
  });
}
