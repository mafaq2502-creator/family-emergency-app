import 'package:family_emergency_app/features/auth/domain/auth_destination.dart';
import 'dart:async';

import 'package:family_emergency_app/features/auth/domain/email_verification_policy.dart';
import 'package:family_emergency_app/features/auth/presentation/email_verification_screen.dart';
import 'package:family_emergency_app/models/user_profile.dart';
import 'package:family_emergency_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Verification implements EmailVerificationActions {
  bool verified = false;
  int checks = 0;
  int sends = 0;
  int signOuts = 0;

  @override
  Future<bool> refreshEmailVerification() async {
    checks++;
    return verified;
  }

  @override
  Future<void> sendEmailVerification() async => sends++;

  @override
  Future<void> signOut() async => signOuts++;
}

class _SlowVerification extends _Verification {
  final pendingCheck = Completer<bool>();

  @override
  Future<bool> refreshEmailVerification() => pendingCheck.future;
}

void main() {
  test('test builds allow an explicit verification-screen bypass', () {
    expect(EmailVerificationPolicy.autoVerifyForTesting, isTrue);
    expect(
      EmailVerificationPolicy.shouldBlock(hasEmail: true, emailVerified: false),
      isTrue,
    );
    expect(
      EmailVerificationPolicy.shouldBlock(
        hasEmail: true,
        emailVerified: false,
        bypassedForCurrentSession: true,
      ),
      isFalse,
    );
  });

  testWidgets(
    'production Next rechecks Firebase and verified users continue automatically',
    (tester) async {
      final verification = _Verification();
      var continued = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationScreen(
            email: 'new.user@example.com',
            verification: verification,
            allowTestingBypass: false,
            onContinue: (verified) {
              expect(verified, isTrue);
              continued++;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Next'))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
      await tester.pump();
      await tester.pump();
      expect(continued, 0);
      expect(find.textContaining('Email is not verified yet'), findsOneWidget);

      verification.verified = true;
      await tester.tap(find.text('Check verification'));
      await tester.pump();
      await tester.pump();
      expect(continued, 1);
    },
  );

  testWidgets('resend and Cancel use the verification service', (tester) async {
    final verification = _Verification();
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'new.user@example.com',
          verification: verification,
          onContinue: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Resend verification email'));
    await tester.pump();
    expect(verification.sends, 1);
    expect(
      find.textContaining('A new verification link was sent'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(verification.signOuts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Cancel works once while automatic verification check is pending',
    (tester) async {
      final verification = _SlowVerification();
      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationScreen(
            email: 'new.user@example.com',
            verification: verification,
            onContinue: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(verification.signOuts, 1);
      verification.pendingCheck.complete(false);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('testing Next continues only the current unverified session', (
    tester,
  ) async {
    final verification = _Verification();
    bool? firebaseVerified;
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'new.user@example.com',
          verification: verification,
          allowTestingBypass: true,
          onContinue: (verified) => firebaseVerified = verified,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final next = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Next'),
    );
    expect(next.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    expect(firebaseVerified, isFalse);
  });

  test('completed onboarding does not reopen when no Circle remains', () {
    final profile = UserProfile.fromData(
      uid: 'user-1',
      fallbackEmail: 'verified@example.com',
      data: const {
        'name': 'Verified User',
        'email': 'verified@example.com',
        'phone': '+923001234567',
        'phoneCountryIso': 'PK',
        'phoneCountryCode': '+92',
        'relationship': 'Self',
        'profileCompleted': true,
        'onboardingCompleted': true,
      },
    );
    expect(
      AuthDestinationResolver.resolve(
        signedIn: true,
        profile: profile,
        hasActiveCircle: false,
      ),
      AuthDestination.home,
    );
  });
}
