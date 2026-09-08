import 'package:family_emergency_app/features/auth/domain/auth_error_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Firebase Auth failures to readable messages', () {
    expect(
      AuthErrorMapper.message(
        FirebaseAuthException(code: 'invalid-credential'),
      ),
      'Incorrect email or password.',
    );
    expect(
      AuthErrorMapper.message(
        FirebaseAuthException(code: 'email-already-in-use'),
      ),
      'This email address is already registered.',
    );
    expect(
      AuthErrorMapper.message(
        FirebaseAuthException(code: 'network-request-failed'),
      ),
      'Please check your internet connection and try again.',
    );
  });

  test('provider cancellation is silent', () {
    expect(
      AuthErrorMapper.isCancellation(const AuthOperationCancelled()),
      isTrue,
    );
  });

  test('profile write failure explains recovery', () {
    expect(
      AuthErrorMapper.message(const ProfileCreationException('failure')),
      contains('retry profile setup'),
    );
  });
}
