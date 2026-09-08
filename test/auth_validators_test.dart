import 'package:family_emergency_app/features/auth/domain/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('name', () {
    test('accepts supported real-world names and trim', () {
      for (final value in [
        'Afaq Khan',
        'Afaq',
        'Muhammad Afaq Khan',
        "O'Connor",
        'Anne-Marie',
        '  Afaq Khan  ',
      ]) {
        expect(AuthValidators.name(value), isNull, reason: value);
      }
    });
    test('rejects missing, whitespace, boundaries and control chars', () {
      for (final value in <String?>[
        null,
        '',
        '   ',
        'A',
        'a' * 81,
        'Afaq\nKhan',
      ]) {
        expect(AuthValidators.name(value), isNotNull, reason: '$value');
      }
    });
  });

  group('email', () {
    test('accepts common valid and trimmed formats', () {
      for (final value in [
        'user@example.com',
        'user.name@example.com',
        'user+test@example.com',
        '  USER@example.com  ',
      ]) {
        expect(AuthValidators.email(value), isNull, reason: value);
      }
    });
    test('rejects missing, malformed, spaced and overlong values', () {
      for (final value in <String?>[
        null,
        '',
        '   ',
        'user',
        'user@',
        '@example.com',
        'user@example',
        'user@@example.com',
        'user name@example.com',
        '${'a' * 245}@example.com',
      ]) {
        expect(AuthValidators.email(value), isNotNull, reason: '$value');
      }
    });
  });

  group('phone', () {
    test('accepts international, local and valid boundaries', () {
      for (final value in [
        '+923001234567',
        '0300 1234567',
        '+1 (212) 555-0100',
        '1234567',
        '123456789012345',
      ]) {
        expect(AuthValidators.phone(value), isNull, reason: value);
      }
    });
    test('rejects missing, boundaries, letters and misplaced plus', () {
      for (final value in <String?>[
        null,
        '',
        '   ',
        '123456',
        '1234567890123456',
        '+92abc',
        '92+3001234567',
        '++923001234567',
      ]) {
        expect(AuthValidators.phone(value), isNotNull, reason: '$value');
      }
    });
  });

  test('relationship accepts supported options and rejects stale values', () {
    for (final value in AuthValidators.relationships) {
      expect(AuthValidators.relationship(value), isNull);
    }
    expect(AuthValidators.relationship(null), isNotNull);
    expect(AuthValidators.relationship(''), isNotNull);
    expect(AuthValidators.relationship('unsupported_value'), isNotNull);
  });

  test('password and confirmation enforce boundaries without trimming', () {
    expect(AuthValidators.password('12345678'), isNull);
    expect(AuthValidators.password('A special password #42'), isNull);
    expect(AuthValidators.password(null), isNotNull);
    expect(AuthValidators.password('       '), isNotNull);
    expect(AuthValidators.password('1234567'), isNotNull);
    expect(AuthValidators.password('a' * 129), isNotNull);
    expect(AuthValidators.confirmPassword('12345678', '12345678'), isNull);
    expect(AuthValidators.confirmPassword('', '12345678'), isNotNull);
    expect(AuthValidators.confirmPassword('1234567X', '12345678'), isNotNull);
    expect(AuthValidators.confirmPassword('12345678 ', '12345678'), isNotNull);
  });

  test('Circle name and join code validate boundaries and normalize', () {
    expect(AuthValidators.circleName('  Khan Family  '), isNull);
    expect(AuthValidators.circleName(null), isNotNull);
    expect(AuthValidators.circleName(' '), isNotNull);
    expect(AuthValidators.circleName('a'), isNotNull);
    expect(AuthValidators.circleName('a' * 61), isNotNull);
    expect(AuthValidators.inviteCode('ab-12 cd'), isNull);
    expect(AuthValidators.normalizeInviteCode(' ab-12 cd '), 'AB12CD');
    expect(AuthValidators.inviteCode(null), isNotNull);
    expect(AuthValidators.inviteCode('ABCDE'), isNotNull);
    expect(AuthValidators.inviteCode('ABC_123'), isNotNull);
    expect(AuthValidators.inviteCode('A' * 13), isNotNull);
  });
}
