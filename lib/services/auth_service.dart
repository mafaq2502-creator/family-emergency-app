// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static Future<void>? _googleInitialization;
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth,
        _firestore = firestore;

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseAuth get _authClient => _auth ??= FirebaseAuth.instance;
  FirebaseFirestore get _firestoreClient => _firestore ??= FirebaseFirestore.instance;

  Future<void> signIn({required String email, required String password}) =>
      _authClient.signInWithEmailAndPassword(email: email, password: password);

  Future<void> sendPasswordResetEmail(String email) => _authClient.sendPasswordResetEmail(email: email.trim());

  Future<UserCredential> signInWithGoogle() async {
    await (_googleInitialization ??= GoogleSignIn.instance.initialize());
    final account = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(idToken: account.authentication.idToken);
    return _authClient.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName]);
    final credential = OAuthProvider('apple.com').credential(idToken: appleCredential.identityToken, accessToken: appleCredential.authorizationCode);
    return _authClient.signInWithCredential(credential);
  }

  Future<User> signUp({required String name, required String email, required String password, required String phone, required String countryIso, required String countryCode}) async {
    final credential = await _authClient.createUserWithEmailAndPassword(email: email, password: password);
    final user = credential.user!;
    await user.updateDisplayName(name);
    await _firestoreClient.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': email,
      'phone': phone,
      'phoneCountryIso': countryIso,
      'phoneCountryCode': countryCode,
      'isFamilyOwner': true,
      'notificationSettings': {'missedCheckInAlerts': true, 'emergencyAlerts': true, 'batteryAlerts': false, 'offlineAlerts': false, 'locationSharing': false, 'ownerMissedCheckInAlerts': true},
      'role': 'Self',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return user;
  }
}
