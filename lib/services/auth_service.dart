import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../features/auth/domain/auth_error_mapper.dart';
import '../features/auth/domain/auth_validators.dart';
import 'profile_service.dart';

abstract interface class AuthActions {
  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String countryIso,
    required String countryCode,
    required String relationship,
  });

  Future<void> signInWithGoogle();

  Future<void> signInWithApple();

  Future<void> sendPasswordResetEmail(String email);
}

class AuthService implements AuthActions {
  AuthService({
    this._auth,
    FirebaseFirestore? firestore,
    ProfileService? profileService,
  }) : _profileService =
           profileService ??
           ProfileService(firestore: firestore ?? FirebaseFirestore.instance);

  static Future<void>? _googleInitialization;
  FirebaseAuth? _auth;
  final ProfileService _profileService;

  FirebaseAuth get _authClient => _auth ??= FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _authClient.authStateChanges();

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
    try {
      await _profileService.ensureProviderProfile(user);
    } catch (error) {
      throw ProfileCreationException(error);
    }
  }

  @override
  Future<void> signInWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final UserCredential result;
    if (kIsWeb) {
      result = await _authClient.signInWithPopup(provider);
    } else {
      result = await _authClient.signInWithProvider(provider);
    }
    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Apple authentication did not return a user.',
      );
    }
    try {
      await _profileService.ensureProviderProfile(user);
    } catch (error) {
      throw ProfileCreationException(error);
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
    required String relationship,
  }) async {
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
    await user.updateDisplayName(name.trim());
    try {
      await _profileService.createEmailProfile(
        user,
        name: name,
        email: email,
        phone: phone,
        countryIso: countryIso,
        countryCode: countryCode,
        relationship: relationship,
      );
    } catch (error) {
      throw ProfileCreationException(error);
    }
  }

  Future<void> signOut() async {
    await _authClient.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Firebase local session is already cleared. Provider cleanup is best effort.
    }
  }
}
