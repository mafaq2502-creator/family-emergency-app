import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthOperationCancelled implements Exception {
  const AuthOperationCancelled();
}

class ProfileCreationException implements Exception {
  const ProfileCreationException(this.cause);

  final Object cause;
}

class AuthErrorMapper {
  const AuthErrorMapper._();

  static bool isCancellation(Object error) {
    if (error is AuthOperationCancelled) return true;
    if (error is GoogleSignInException) {
      return error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted;
    }
    return error is FirebaseAuthException &&
        error.code == 'web-context-cancelled';
  }

  static String message(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is ProfileCreationException) {
      return 'Your account was created, but we could not create your profile. Please retry profile setup.';
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'email-already-in-use':
          return 'This email address is already registered.';
        case 'weak-password':
          return 'Please choose a stronger password.';
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email or password.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        case 'network-request-failed':
          return 'Please check your internet connection and try again.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled yet.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email using another sign-in method.';
        case 'requires-recent-login':
          return 'For security, please sign in again and retry.';
        case 'no-current-user':
          return 'Your session has expired. Please sign in again.';
      }
    }
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'You do not have permission to complete this action.';
      }
      if (error.code == 'unavailable') {
        return 'The service is temporarily unavailable. Please retry.';
      }
    }
    if (error is GoogleSignInException) {
      return 'Google sign-in could not be completed. Please try again.';
    }
    return fallback;
  }
}
