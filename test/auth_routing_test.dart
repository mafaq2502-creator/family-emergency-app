import 'package:family_emergency_app/features/auth/domain/auth_destination.dart';
import 'package:family_emergency_app/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile profile(Map<String, dynamic>? data) => UserProfile.fromData(
  uid: 'user-1',
  data: data,
  fallbackEmail: 'user@example.com',
);

void main() {
  test('logged out routes only to login', () {
    expect(
      AuthDestinationResolver.resolve(signedIn: false),
      AuthDestination.login,
    );
  });

  test('missing profile routes to recovery', () {
    expect(
      AuthDestinationResolver.resolve(signedIn: true, profile: profile(null)),
      AuthDestination.profileRecovery,
    );
  });

  test('incomplete and corrupt profiles route to profile setup', () {
    for (final data in <Map<String, dynamic>>[
      {},
      {'profileCompleted': 'true'},
      {
        'name': null,
        'email': 'user@example.com',
        'phone': '+923001234567',
        'relationship': 'Self',
        'profileCompleted': true,
      },
      {
        'name': 'Afaq',
        'email': 'user@example.com',
        'phone': '+923001234567',
        'relationship': 'unsupported_value',
        'profileCompleted': true,
      },
    ]) {
      expect(
        AuthDestinationResolver.resolve(
          signedIn: true,
          profile: profile(data),
          hasActiveCircle: true,
        ),
        AuthDestination.profileSetup,
      );
    }
  });

  test('complete profile without Circle resumes Circle setup', () {
    expect(
      AuthDestinationResolver.resolve(
        signedIn: true,
        profile: profile({
          'name': 'Afaq',
          'email': 'user@example.com',
          'phone': '+923001234567',
          'relationship': 'Self',
          'profileCompleted': true,
          'onboardingCompleted': false,
        }),
      ),
      AuthDestination.circleSetup,
    );
  });

  test('active Circle is source of truth and routes completed user home', () {
    expect(
      AuthDestinationResolver.resolve(
        signedIn: true,
        profile: profile({
          'name': 'Afaq',
          'email': 'user@example.com',
          'phone': '+923001234567',
          'relationship': 'Self',
          'profileCompleted': true,
          'onboardingCompleted': false,
        }),
        hasActiveCircle: true,
      ),
      AuthDestination.home,
    );
  });
}
