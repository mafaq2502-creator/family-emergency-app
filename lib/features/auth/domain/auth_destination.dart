import '../../../models/user_profile.dart';
import 'auth_validators.dart';

enum AuthDestination { login, profileRecovery, profileSetup, circleSetup, home }

class AuthDestinationResolver {
  const AuthDestinationResolver._();

  static AuthDestination resolve({
    required bool signedIn,
    UserProfile? profile,
    bool hasActiveCircle = false,
  }) {
    if (!signedIn) return AuthDestination.login;
    if (profile == null || !profile.exists) {
      return AuthDestination.profileRecovery;
    }
    if (!profile.profileCompleted ||
        AuthValidators.relationship(profile.relationship) != null) {
      return AuthDestination.profileSetup;
    }
    if (!hasActiveCircle) return AuthDestination.circleSetup;
    return AuthDestination.home;
  }
}
