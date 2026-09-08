import 'dart:async';

import 'package:family_emergency_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:family_emergency_app/features/auth/presentation/login_screen.dart';
import 'package:family_emergency_app/features/auth/presentation/signup_screen.dart';
import 'package:family_emergency_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthActions implements AuthActions {
  int loginCalls = 0;
  int resetCalls = 0;
  int googleCalls = 0;
  int appleCalls = 0;
  int signupCalls = 0;
  Completer<void>? loginCompleter;
  Completer<void>? signupCompleter;
  Object? loginError;
  Object? resetError;
  String? signedUpEmail;
  String? signedUpPhone;

  @override
  Future<void> signIn({required String email, required String password}) async {
    loginCalls++;
    if (loginError case final Object error) throw error;
    await (loginCompleter?.future ?? Future<void>.value());
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetCalls++;
    if (resetError case final Object error) throw error;
  }

  @override
  Future<void> signInWithApple() async => appleCalls++;

  @override
  Future<void> signInWithGoogle() async => googleCalls++;

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String countryIso,
    required String countryCode,
    required String relationship,
  }) async {
    signupCalls++;
    signedUpEmail = email;
    signedUpPhone = phone;
    await (signupCompleter?.future ?? Future<void>.value());
  }
}

void main() {
  testWidgets('login blocks invalid data before contacting Firebase', (
    tester,
  ) async {
    final auth = FakeAuthActions();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(find.text('Please enter your password.'), findsOneWidget);
    expect(auth.loginCalls, 0);
  });

  testWidgets('login prevents rapid duplicate submissions', (tester) async {
    final auth = FakeAuthActions()..loginCompleter = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: auth)));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  user@example.com  ');
    await tester.enterText(fields.at(1), 'correct-password');
    await tester.tap(find.text('Login'));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(auth.loginCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    auth.loginCompleter!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('forgot password validates and shows safe success state', (
    tester,
  ) async {
    final auth = FakeAuthActions();
    await tester.pumpWidget(
      MaterialApp(home: ForgotPasswordScreen(authService: auth)),
    );
    await tester.tap(find.text('Send Reset Link'));
    await tester.pump();
    expect(find.text('Please enter your email address.'), findsOneWidget);
    expect(auth.resetCalls, 0);
    await tester.enterText(find.byType(TextFormField), 'user@example.com');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();
    expect(auth.resetCalls, 1);
    expect(find.text('Send Again'), findsOneWidget);
    expect(find.textContaining('Check your inbox'), findsOneWidget);
  });

  testWidgets('forgot password does not reveal an unknown account', (
    tester,
  ) async {
    final auth = FakeAuthActions()
      ..resetError = FirebaseAuthException(code: 'user-not-found');
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordScreen(
          initialEmail: 'unknown@example.com',
          authService: auth,
        ),
      ),
    );
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();
    expect(auth.resetCalls, 1);
    expect(find.text('Send Again'), findsOneWidget);
    expect(find.textContaining('Check your inbox'), findsOneWidget);
  });

  testWidgets('signup requires terms and guards duplicate account creation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = FakeAuthActions()..signupCompleter = Completer<void>();
    await tester.pumpWidget(MaterialApp(home: SignUpScreen(authService: auth)));
    await tester.pump();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  Afaq Khan  ');
    await tester.enterText(fields.at(1), ' afaq@example.com ');
    await tester.enterText(fields.at(2), '3001234567');
    await tester.enterText(fields.at(3), 'strong-password');
    await tester.enterText(fields.at(4), 'strong-password');
    final relationship = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(relationship);
    await tester.tap(relationship);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Self').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.pump();
    expect(find.text('Please accept the Terms & Conditions.'), findsOneWidget);
    expect(auth.signupCalls, 0);

    await tester.tap(find.byIcon(Icons.check_box_outline_blank_rounded));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(auth.signupCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    auth.signupCompleter!.complete();
    await tester.pumpAndSettle();
    expect(auth.signedUpEmail, 'afaq@example.com');
    // The test locale is US, proving device-locale country detection is used.
    expect(auth.signedUpPhone, '+13001234567');
  });
}
