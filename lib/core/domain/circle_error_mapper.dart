import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CircleErrorMapper {
  const CircleErrorMapper._();

  static String message(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final code = switch (error) {
      FirebaseFunctionsException value => value.code,
      FirebaseException value => value.code,
      _ => '',
    };
    return switch (code) {
      'unauthenticated' => 'Your session expired. Please sign in again.',
      'permission-denied' =>
        'You do not have permission to perform this action.',
      'not-found' => 'This family Circle is no longer available.',
      'already-exists' => 'This action was already completed.',
      'failed-precondition' => switch (error) {
        FirebaseFunctionsException value
            when value.message?.isNotEmpty == true =>
          value.message!,
        FirebaseException value when value.message?.isNotEmpty == true => value.message!,
        _ => 'This action is no longer available.',
      },
      'unavailable' || 'deadline-exceeded' =>
        'Please check your internet connection and try again.',
      _ => error is ArgumentError ? error.message.toString() : fallback,
    };
  }
}
