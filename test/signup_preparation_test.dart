import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:family_emergency_app/services/auth_service.dart';
import 'package:family_emergency_app/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:family_emergency_app/models/user_profile.dart';
import 'package:family_emergency_app/features/auth/presentation/onboarding/profile_setup_screen.dart';

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  int verificationEmails = 0;
  @override
  bool get emailVerified => false;
  @override
  String? get photoURL => null;
  @override
  String get email => 'test@example.com';
  @override
  String get uid => 'signup-user';
  @override
  Future<void> updateDisplayName(String? displayName) async {}
  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async => verificationEmails++;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  _Credential(this.testUser);
  final _User testUser;
  @override
  User get user => testUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  final testUser = _User();
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => _Credential(testUser);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles extends ProfileService {
  _Profiles() : super(firestore: _Firestore());
  final started = Completer<void>();
  final save = Completer<void>();
  @override
  Future<void> createEmailProfile(
    User user, {
    required String name,
    required String email,
    required String phone,
    required String countryIso,
    required String countryCode,
    String relationship = 'Self',
  }) async {
    started.complete();
    await save.future;
  }
}

void main() {
  testWidgets(
    'profile onboarding prefills signup name and displays the saved phone',
    (tester) async {
      final profiles = _Profiles();
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileSetupScreen(
            user: _User(),
            existingProfile: UserProfile.fromData(
              uid: 'signup-user',
              data: {
                'name': 'Test User',
                'email': 'test@example.com',
                'phone': '+923001234567',
                'relationship': 'Self',
              },
            ),
            isRecovery: false,
            profileService: profiles,
            authService: AuthService(auth: _Auth(), profileService: profiles),
            onCompleted: () {},
          ),
        ),
      );
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('+923001234567'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.keyboardType == TextInputType.phone,
        ),
        findsNothing,
      );
    },
  );

  test('routing waits for signup profile write and retains name and phone for recovery', () async {
    final profiles = _Profiles();
    final firebaseAuth = _Auth();
    final auth = AuthService(auth: firebaseAuth, profileService: profiles);
    final signup = auth.signUp(
      name: 'Test User',
      email: 'test@example.com',
      password: 'unused-test',
      phone: '+923001234567',
      countryIso: 'PK',
      countryCode: '+92',
      relationship: 'Self',
    );
    await profiles.started.future;
    var ready = false;
    final preparation = auth.waitForProfilePreparation().then(
      (_) => ready = true,
    );
    await Future<void>.delayed(Duration.zero);
    expect(ready, isFalse);
    expect(auth.signupDraft?.name, 'Test User');
    expect(auth.signupDraft?.phone, '+923001234567');
    expect(firebaseAuth.testUser.verificationEmails, 1);
    profiles.save.complete();
    await signup;
    await preparation;
    expect(ready, isTrue);
  });
}
