import '../../../core/domain/circle_policies.dart';
import '../../../core/domain/invite_code_policy.dart';

class AuthValidators {
  const AuthValidators._();

  static const relationships = <String>[
    'Self',
    'Father',
    'Mother',
    'Son',
    'Daughter',
    'Husband',
    'Wife',
    'Grandfather',
    'Grandmother',
    'Grandson',
    'Granddaughter',
    'Brother',
    'Sister',
    'Spouse',
    'Child',
    'Relative',
    'Guardian',
    'Other',
  ];

  static final RegExp _emailPattern = RegExp(
    r"^[A-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?(?:\.[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?)+$",
    caseSensitive: false,
  );
  static final RegExp _controlCharacters = RegExp(r'[\x00-\x1F\x7F]');

  static String normalizeEmail(String value) => value.trim();

  static String? name(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Please enter your name.';
    if (normalized.length < 2) {
      return 'Name must contain at least 2 characters.';
    }
    if (normalized.length > 80) {
      return 'Name must be 80 characters or fewer.';
    }
    if (_controlCharacters.hasMatch(normalized)) {
      return 'Please enter a valid name.';
    }
    return null;
  }

  static String? email(String? value) {
    final normalized = normalizeEmail(value ?? '');
    if (normalized.isEmpty) return 'Please enter your email address.';
    if (normalized.length > 254 || !_emailPattern.hasMatch(normalized)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

  static String? phone(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Please enter your phone number.';
    if (!RegExp(r'^\+?[0-9\s()-]+$').hasMatch(raw)) {
      return 'Please enter a valid phone number.';
    }
    if (raw.indexOf('+') > 0 || '+'.allMatches(raw).length > 1) {
      return 'Please enter a valid phone number.';
    }
    final digits = digitsOnly(raw);
    if (digits.length < 7 || digits.length > 15) {
      return 'Phone number must contain 7 to 15 digits.';
    }
    return null;
  }

  static String? relationship(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please select your relationship.';
    }
    if (!relationships.contains(value)) {
      return 'Please select a valid relationship.';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty || password.trim().isEmpty) {
      return 'Please enter your password.';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (password.length > 128) {
      return 'Password must be 128 characters or fewer.';
    }
    if (_controlCharacters.hasMatch(password)) {
      return 'Password contains an unsupported character.';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty || value.trim().isEmpty) {
      return 'Please enter your password.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != password) return 'Passwords do not match.';
    return null;
  }

  static String? circleName(String? value) {
    return CircleNamePolicy.validate(value);
  }

  static String normalizeInviteCode(String value) =>
      InviteCodePolicy.normalize(value);

  static String? inviteCode(String? value) => InviteCodePolicy.validate(value);
}
