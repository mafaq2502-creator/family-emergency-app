import 'package:flutter/foundation.dart';

class EmailVerificationPolicy {
  const EmailVerificationPolicy._();

  static const _autoVerifyForTesting = bool.fromEnvironment(
    'AUTO_VERIFY_EMAIL_FOR_TESTING',
    defaultValue: !kReleaseMode,
  );

  static bool get autoVerifyForTesting => _autoVerifyForTesting;

  static bool shouldBlock({
    required bool hasEmail,
    required bool emailVerified,
    bool bypassedForCurrentSession = false,
  }) => hasEmail && !emailVerified && !bypassedForCurrentSession;
}
