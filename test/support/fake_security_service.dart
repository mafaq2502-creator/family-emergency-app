import 'dart:async';

import 'package:family_emergency_app/services/account_security_service.dart';

class FakeSecurityService implements AccountSecurityActions {
  FakeSecurityService({
    this.overview = const SecurityOverview(
      email: 'user@example.com',
      emailVerified: true,
      providerIds: ['password'],
      createdAt: null,
      lastSignInAt: null,
    ),
    this.readiness = const AccountDeletionReadiness(ownedCircleNames: []),
  });

  SecurityOverview overview;
  AccountDeletionReadiness readiness;
  Object? passwordError;
  Object? emailError;
  Completer<void>? passwordCompleter;
  int passwordCalls = 0;
  int emailCalls = 0;
  int verificationCalls = 0;

  @override
  Future<SecurityOverview> loadOverview() async => overview;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    passwordCalls++;
    if (passwordError != null) throw passwordError!;
    await (passwordCompleter?.future ?? Future<void>.value());
  }

  @override
  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    emailCalls++;
    if (emailError != null) throw emailError!;
  }

  @override
  Future<void> sendEmailVerification() async => verificationCalls++;

  @override
  Future<AccountDeletionReadiness> inspectDeletionReadiness() async =>
      readiness;
}
