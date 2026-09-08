import 'package:family_emergency_app/models/family_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FamilyMember preserves optional member details through a map', () {
    const member = FamilyMember(
      name: 'Mother',
      status: 'Online',
      phone: '+923001234567',
      email: 'mother@example.com',
      relation: 'Mother',
      locationAccess: true,
      batteryAccess: true,
    );

    expect(FamilyMember.fromMap(member.toMap()).toMap(), member.toMap());
  });

  test('FamilyMember provides safe defaults for incomplete data', () {
    final member = FamilyMember.fromMap({});

    expect(member.name, isEmpty);
    expect(member.status, 'Pending');
    expect(member.locationAccess, isFalse);
  });
}
