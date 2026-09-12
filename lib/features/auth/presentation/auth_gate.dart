import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/domain/invite_code_policy.dart';
import '../../../models/user_profile.dart';
import '../../../services/auth_service.dart';
import '../../../services/group_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/intro_preferences.dart';
import '../../../services/invite_link_service.dart';
import '../domain/auth_error_mapper.dart';
import '../domain/email_verification_policy.dart';
import '../../shell/presentation/family_shell.dart';
import '../domain/auth_destination.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';
import 'onboarding/circle_onboarding_screen.dart';
import 'onboarding/intro_flow.dart';
import 'onboarding/profile_setup_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authService,
    this.profileService,
    this.groupService,
    this.inviteLinkSource,
  });

  final AuthService? authService;
  final ProfileService? profileService;
  final GroupService? groupService;
  final InviteLinkSource? inviteLinkSource;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _introDismissed = false;
  late Future<bool> _firstLaunch = IntroPreferences().claimFirstLaunch();
  late final AuthService _authService = widget.authService ?? AuthService();
  late final ProfileService _profileService =
      widget.profileService ?? ProfileService();
  late final GroupService _groupService = widget.groupService ?? GroupService();
  String? _resolvedUid;
  Future<_SessionResolution>? _resolution;
  String? _verificationBypassUid;
  late final InviteLinkSource _inviteLinks =
      widget.inviteLinkSource ?? InviteLinkService();
  StreamSubscription<Uri>? _inviteSubscription;
  String? _pendingInviteCode;
  String? _inviteError;

  @override
  void initState() {
    super.initState();
    unawaited(_startInviteLinks());
  }

  Future<void> _startInviteLinks() async {
    try {
      final initial = await _inviteLinks.getInitialLink();
      if (initial != null) _acceptInviteLink(initial);
      _inviteSubscription = _inviteLinks.linkStream.listen(
        _acceptInviteLink,
        onError: (_) {},
      );
    } catch (_) {
      // Deep links remain optional on platforms without an app-link provider.
    }
  }

  void _acceptInviteLink(Uri uri) {
    if (!InviteCodePolicy.isSupportedInviteUri(uri)) return;
    final code = InviteCodePolicy.normalize(uri.toString());
    final error = InviteCodePolicy.validate(code);
    if (!mounted) return;
    setState(() {
      _pendingInviteCode = error == null ? code : null;
      _inviteError = error == null ? null : 'This invitation link is invalid.';
    });
  }

  void _clearInvite() {
    if (!mounted) return;
    setState(() {
      _pendingInviteCode = null;
      _inviteError = null;
    });
  }

  @override
  void dispose() {
    _inviteSubscription?.cancel();
    super.dispose();
  }

  Future<_SessionResolution> _resolve(User user) async {
    await _authService.waitForProfilePreparation();
    var profile = await _profileService.load(user);
    if (!profile.exists && _authService.signupDraft?.uid == user.uid) {
      profile = _authService.signupDraft!;
    }
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
    setState(() {
      _resolution = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _firstLaunch,
      builder: (context, introSnapshot) {
        if (introSnapshot.connectionState != ConnectionState.done) {
          return const StartupSplash();
        }
        if (introSnapshot.hasError) {
          return _StartupErrorScreen(
            message: 'Could not load app preferences. Please retry.',
            onRetry: () => setState(
              () => _firstLaunch = IntroPreferences().claimFirstLaunch(),
            ),
          );
        }
        return StreamBuilder<User?>(
          stream: _authService.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const StartupSplash(message: 'Checking your session…');
            }
            if (authSnapshot.hasError) {
              return _StartupErrorScreen(onRetry: _refresh);
            }
            final user = _authService.currentUser ?? authSnapshot.data;
            if (user == null) {
              _resolvedUid = null;
              _resolution = null;
              _verificationBypassUid = null;
              if (introSnapshot.data == true && !_introDismissed) {
                return IntroFlow(
                  onFinished: () => setState(() => _introDismissed = true),
                );
              }
              return LoginScreen(authService: _authService);
            }

            if (EmailVerificationPolicy.shouldBlock(
              hasEmail: user.email != null,
              emailVerified: user.emailVerified == true,
              bypassedForCurrentSession: _verificationBypassUid == user.uid,
            )) {
              _resolvedUid = null;
              _resolution = null;
              return EmailVerificationScreen(
                key: ValueKey('verify-${user.uid}'),
                email: user.email!,
                verification: _authService,
                allowTestingBypass:
                    EmailVerificationPolicy.autoVerifyForTesting,
                onContinue: (firebaseVerified) {
                  if (!firebaseVerified) {
                    _verificationBypassUid = user.uid;
                  }
                  _refresh();
                },
              );
            }

            return FutureBuilder<_SessionResolution>(
              future: _resolutionFor(user),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState != ConnectionState.done) {
                  return const StartupSplash(
                    message: 'Preparing your account…',
                  );
                }
                if (profileSnapshot.hasError || profileSnapshot.data == null) {
                  return _StartupErrorScreen(
                    message: AuthErrorMapper.message(
                      profileSnapshot.error ??
                          StateError('Missing account data'),
                      fallback:
                          'We could not prepare your account. Please retry.',
                    ),
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
                      isRecovery:
                          destination == AuthDestination.profileRecovery,
                      profileService: _profileService,
                      authService: _authService,
                      onCompleted: _refresh,
                    );
                  case AuthDestination.circleSetup:
                    return CircleOnboardingScreen(
                      user: user,
                      groupService: _groupService,
                      pendingCircleId: resolution.profile.pendingJoinCircleId,
                      profileName: resolution.profile.name,
                      profilePhone: resolution.profile.phone,
                      initialInviteCode: _pendingInviteCode,
                      onInviteHandled: _clearInvite,
                      onSignOut: _authService.signOut,
                      onCompleted: _refresh,
                    );
                  case AuthDestination.home:
                    return HomeScreen(
                      key: ValueKey(user.uid),
                      initialInviteCode: _pendingInviteCode,
                      initialInviteError: _inviteError,
                      onInviteHandled: _clearInvite,
                    );
                  case AuthDestination.login:
                    return LoginScreen(authService: _authService);
                }
              },
            );
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
