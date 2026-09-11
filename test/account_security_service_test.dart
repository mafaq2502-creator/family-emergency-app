import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:family_emergency_app/services/account_security_service.dart';
import 'package:family_emergency_app/services/auth_service.dart';
import 'package:family_emergency_app/models/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UserInfo implements UserInfo {
  @override
  String get providerId => 'password';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  String? updatedPassword;
  String? pendingEmail;
  int reauthenticationCalls = 0;

  @override
  String get uid => 'current-user';
  @override
  String get email => 'user@example.com';
  @override
  List<UserInfo> get providerData => [_UserInfo()];
  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    reauthenticationCalls++;
    return _Credential();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    updatedPassword = newPassword;
  }

  @override
  Future<void> verifyBeforeUpdateEmail(
    String newEmail, [
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    pendingEmail = newEmail;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth(this.user);
  final User user;
  int signOutCalls = 0;
  @override
  User get currentUser => user;
  @override
  Future<void> signOut() async => signOutCalls++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('password update reauthenticates before Firebase update', () async {
    final user = _User();
    final service = AccountSecurityService(
      auth: _Auth(user),
      firestore: _Firestore(),
    );
    await service.changePassword(
      currentPassword: 'current-password',
      newPassword: 'new-password-123',
    );
    expect(user.reauthenticationCalls, 1);
    expect(user.updatedPassword, 'new-password-123');
  });

  test(
    'identical or weak password is rejected before reauthentication',
    () async {
      final user = _User();
      final service = AccountSecurityService(
        auth: _Auth(user),
        firestore: _Firestore(),
      );
      await expectLater(
        service.changePassword(
          currentPassword: 'same-password',
          newPassword: 'same-password',
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.changePassword(currentPassword: 'current', newPassword: 'weak'),
        throwsArgumentError,
      );
      expect(user.reauthenticationCalls, 0);
    },
  );

  test(
    'email change normalizes, reauthenticates and starts verification',
    () async {
      final user = _User();
      final service = AccountSecurityService(
        auth: _Auth(user),
        firestore: _Firestore(),
      );
      await service.requestEmailChange(
        currentPassword: 'current-password',
        newEmail: ' NEW@Example.com ',
      );
      expect(user.reauthenticationCalls, 1);
      expect(user.pendingEmail, 'new@example.com');
      expect(user.email, 'user@example.com');
    },
  );

  test(
    'logout clears Firebase authentication and local signup draft',
    () async {
      final firebaseAuth = _Auth(_User());
      final auth = AuthService(auth: firebaseAuth, firestore: _Firestore());
      auth.signupDraft = UserProfile.fromData(
        uid: 'current-user',
        data: null,
        fallbackName: 'Temporary Name',
      );
      await auth.signOut();
      expect(firebaseAuth.signOutCalls, 1);
      expect(auth.signupDraft, isNull);
    },
  );
}
