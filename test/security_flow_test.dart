import 'dart:async';

import 'package:family_emergency_app/features/profile/presentation/profile_settings_screen.dart';
import 'package:family_emergency_app/services/account_security_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_security_service.dart';

void main() {
  testWidgets(
    'security screen shows real supported controls and current session',
    (tester) async {
      final service = FakeSecurityService();
      await tester.pumpWidget(
        MaterialApp(home: ProfileSettingsScreen(securityService: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Change email'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
      expect(
        find.textContaining('Selective device logout is unavailable'),
        findsOneWidget,
      );
      expect(find.textContaining('Demo'), findsNothing);
    },
  );

  testWidgets('provider-only account does not show password controls', (
    tester,
  ) async {
    final service = FakeSecurityService(
      overview: const SecurityOverview(
        email: 'user@example.com',
        emailVerified: true,
        providerIds: ['google.com'],
        createdAt: null,
        lastSignInAt: null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: ProfileSettingsScreen(securityService: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Change password'), findsNothing);
    expect(
      find.textContaining('managed by your sign-in provider'),
      findsOneWidget,
    );
  });

  testWidgets('password change validates and prevents double submission', (
    tester,
  ) async {
    final service = FakeSecurityService()
      ..passwordCompleter = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(home: UpdatePasswordScreen(securityService: service)),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'current-password');
    await tester.enterText(fields.at(1), 'new-password-123');
    await tester.enterText(fields.at(2), 'new-password-123');
    await tester.tap(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(service.passwordCalls, 1);
    service.passwordCompleter!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'wrong current password is mapped without leaking provider detail',
    (tester) async {
      final service = FakeSecurityService()
        ..passwordError = FirebaseAuthException(code: 'wrong-password');
      await tester.pumpWidget(
        MaterialApp(home: UpdatePasswordScreen(securityService: service)),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'wrong-password');
      await tester.enterText(fields.at(1), 'new-password-123');
      await tester.enterText(fields.at(2), 'new-password-123');
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
      expect(find.text('The current password is incorrect.'), findsOneWidget);
      expect(
        (tester.widget<TextFormField>(fields.at(0))).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('email change keeps canonical email until verification', (
    tester,
  ) async {
    final service = FakeSecurityService();
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeEmailScreen(
          securityService: service,
          currentEmail: 'old@example.com',
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NEW@example.com');
    await tester.enterText(fields.at(1), 'current-password');
    await tester.tap(find.text('Send Verification Link'));
    await tester.pumpAndSettle();
    expect(service.emailCalls, 1);
    expect(find.text('Check your new email'), findsOneWidget);
    expect(find.textContaining('current email stays active'), findsOneWidget);
  });

  testWidgets('deletion preparation blocks Circle owners', (tester) async {
    final service = FakeSecurityService(
      readiness: const AccountDeletionReadiness(
        ownedCircleNames: ['My Family'],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionPreparationScreen(securityService: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resolve Circle ownership first'), findsOneWidget);
    expect(find.text('My Family'), findsOneWidget);
    expect(find.textContaining('No data has been deleted'), findsNothing);
  });
}
