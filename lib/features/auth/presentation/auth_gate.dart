import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/user_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/group_service.dart';
import '../../../services/profile_service.dart';
import '../../shell/presentation/family_shell.dart';
import '../domain/auth_destination.dart';
import 'login_screen.dart';
import 'onboarding/circle_onboarding_screen.dart';
import 'onboarding/intro_flow.dart';
import 'onboarding/profile_setup_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authService,
    this.profileService,
    this.groupService,
  });

  final AuthService? authService;
  final ProfileService? profileService;
  final GroupService? groupService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static bool _introSeenThisRun = false;
  late final AuthService _authService = widget.authService ?? AuthService();
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final GroupService _groupService = widget.groupService ?? GroupService();
  String? _resolvedUid;
  Future<_SessionResolution>? _resolution;

  Future<_SessionResolution> _resolve(User user) async {
    final profile = await _profileService.load(user);
    final hasCircle = profile.profileCompleted
        ? await _groupService.hasAnyGroup(user)
        : false;
    return _SessionResolution(profile: profile, hasCircle: hasCircle);
  }

  Future<_SessionResolution> _resolutionFor(User user) {
    if (_resolvedUid != user.uid || _resolution == null) {
      _resolvedUid = user.uid;
      _resolution = _resolve(user);
    }
    return _resolution!;
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _resolution = null);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const StartupSplash(message: 'Checking your session…');
        }
        if (authSnapshot.hasError) {
          return _StartupErrorScreen(onRetry: _refresh);
        }
        final user = authSnapshot.data;
        if (user == null) {
          _resolvedUid = null;
          _resolution = null;
          if (!_introSeenThisRun) {
            return IntroFlow(
              onFinished: () => setState(() => _introSeenThisRun = true),
            );
          }
          return LoginScreen(authService: _authService);
        }

        return FutureBuilder<_SessionResolution>(
          future: _resolutionFor(user),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const StartupSplash(message: 'Preparing your account…');
            }
            if (profileSnapshot.hasError || profileSnapshot.data == null) {
              return _StartupErrorScreen(
                message: 'We could not load your profile. Check your connection and retry.',
                onRetry: _refresh,
                onSignOut: _authService.signOut,
              );
            }

            final resolution = profileSnapshot.data!;
            final destination = AuthDestinationResolver.resolve(
              signedIn: true,
              profile: resolution.profile,
              hasActiveCircle: resolution.hasCircle,
            );
            switch (destination) {
              case AuthDestination.profileRecovery:
              case AuthDestination.profileSetup:
                return ProfileSetupScreen(
                  user: user,
                  existingProfile: resolution.profile,
                  isRecovery: destination == AuthDestination.profileRecovery,
                  profileService: _profileService,
                  authService: _authService,
                  onCompleted: _refresh,
                );
              case AuthDestination.circleSetup:
                return CircleOnboardingScreen(
                  user: user,
                  groupService: _groupService,
                  onSignOut: _authService.signOut,
                  onCompleted: _refresh,
                );
              case AuthDestination.home:
                return HomeScreen(key: ValueKey(user.uid));
              case AuthDestination.login:
                return LoginScreen(authService: _authService);
            }
          },
        );
      },
    );
  }
}

class _SessionResolution {
  const _SessionResolution({required this.profile, required this.hasCircle});

  final UserProfile profile;
  final bool hasCircle;
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({
    required this.onRetry,
    this.message = 'Firebase could not start. Please try again.',
    this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 52, color: kEmergency),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
              if (onSignOut != null)
                TextButton(
                  onPressed: () => onSignOut!(),
                  child: const Text('Sign out'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
