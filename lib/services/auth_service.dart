import 'dart:async';

import '../models/user_profile.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../features/auth/domain/auth_error_mapper.dart';
import '../features/auth/domain/auth_validators.dart';
import 'profile_service.dart';
import 'push_notification_service.dart';

abstract interface class AuthActions {
  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String countryIso,
    required String countryCode,
  });

  Future<void> signInWithGoogle();

  Future<void> sendPasswordResetEmail(String email);
}

abstract interface class EmailVerificationActions {
  Future<void> sendEmailVerification();
  Future<bool> refreshEmailVerification();
  Future<void> signOut();
}

class AuthService implements AuthActions, EmailVerificationActions {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ProfileService? profileService,
    // Keep the injection parameter public while the client stays private.
    // ignore: prefer_initializing_formals
  }) : _auth = auth,
       _profileService =
           profileService ??
           ProfileService(firestore: firestore ?? FirebaseFirestore.instance);

  static Future<void>? _googleInitialization;
  Completer<void>? _profilePreparation;
  UserProfile? signupDraft;

  Future<void> waitForProfilePreparation() async {
    await _profilePreparation?.future;
  }

  FirebaseAuth? _auth;
  final ProfileService _profileService;

  FirebaseAuth get _authClient => _auth ??= FirebaseAuth.instance;

  // userChanges also emits after reload(), so an email-verification change can
  // move AuthGate forward without requiring a sign-out/sign-in cycle.
  Stream<User?> authStateChanges() => _authClient.userChanges();

  User? get currentUser => _authClient.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _authClient.signInWithEmailAndPassword(
      email: AuthValidators.normalizeEmail(email),
      password: password,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) => _authClient
      .sendPasswordResetEmail(email: AuthValidators.normalizeEmail(email));

  @override
  Future<void> signInWithGoogle() async {
    _profilePreparation = Completer<void>();
    try {
      await (_googleInitialization ??= GoogleSignIn.instance.initialize());
      final account = await GoogleSignIn.instance.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      final result = await _authClient.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Google authentication did not return a user.',
        );
      }
      if (result.additionalUserInfo?.isNewUser == true &&
          user.email != null &&
          user.emailVerified != true) {
        await user.sendEmailVerification();
      }
      try {
        await _profileService.ensureProviderProfile(user);
      } catch (error) {
        throw ProfileCreationException(error);
      }
    } finally {
      _profilePreparation?.complete();
      _profilePreparation = null;
    }
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String countryIso,
    required String countryCode,
  }) async {
    _profilePreparation = Completer<void>();
    try {
      final credential = await _authClient.createUserWithEmailAndPassword(
        email: AuthValidators.normalizeEmail(email),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'missing-user',
          message: 'Account creation did not return a user.',
        );
      }
      signupDraft = UserProfile.fromData(
        uid: user.uid,
        data: null,
        fallbackName: name,
        fallbackEmail: email,
        fallbackPhone: phone,
      );
      await user.updateDisplayName(name.trim());
      if (user.emailVerified != true) {
        await user.sendEmailVerification();
      }
      try {
        await _profileService.createEmailProfile(
          user,
          name: name,
          email: email,
          phone: phone,
          countryIso: countryIso,
          countryCode: countryCode,
        );
      } catch (error) {
        throw ProfileCreationException(error);
      }
    } finally {
      _profilePreparation?.complete();
      _profilePreparation = null;
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    if (user.emailVerified != true) await user.sendEmailVerification();
  }

  @override
  Future<bool> refreshEmailVerification() async {
    final user = currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = currentUser;
    if (refreshed?.emailVerified == true) {
      await refreshed?.getIdToken(true);
      return true;
    }
    return false;
  }

  @override
  Future<void> signOut() async {
    signupDraft = null;
    await PushNotificationService.instance.detachCurrentUser();
    await _authClient.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Firebase local session is already cleared. Provider cleanup is best effort.
    }
  }
}
