import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/auth/domain/auth_validators.dart';
import 'profile_service.dart';

class SecurityOverview {
  const SecurityOverview({
    required this.email,
    required this.emailVerified,
    required this.providerIds,
    required this.createdAt,
    required this.lastSignInAt,
  });

  final String email;
  final bool emailVerified;
  final List<String> providerIds;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;

  bool get supportsPassword => providerIds.contains('password');
}

class AccountDeletionReadiness {
  const AccountDeletionReadiness({required this.ownedCircleNames});

  final List<String> ownedCircleNames;
  bool get canRequestDeletion => ownedCircleNames.isEmpty;
}

abstract interface class AccountSecurityActions {
  Future<SecurityOverview> loadOverview();
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  });
  Future<void> sendEmailVerification();
  Future<AccountDeletionReadiness> inspectDeletionReadiness();
}

class AccountSecurityService implements AccountSecurityActions {
  AccountSecurityService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ProfileService? profileService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _profileService =
           profileService ??
           ProfileService(firestore: firestore ?? FirebaseFirestore.instance);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ProfileService _profileService;

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'The signed-in account is no longer available.',
      );
    }
    return user;
  }

  @override
  Future<SecurityOverview> loadOverview() async {
    final user = _requireUser();
    await user.reload();
    final current = _requireUser();
    await current.getIdToken(true);
    await _profileService.syncCanonicalIdentity(current);
    return SecurityOverview(
      email: current.email?.trim() ?? '',
      emailVerified: current.emailVerified,
      providerIds: current.providerData
          .map((provider) => provider.providerId)
          .where((provider) => provider.isNotEmpty)
          .toSet()
          .toList(growable: false),
      createdAt: current.metadata.creationTime,
      lastSignInAt: current.metadata.lastSignInTime,
    );
  }

  Future<User> _reauthenticatePassword(String currentPassword) async {
    final user = _requireUser();
    final email = user.email;
    if (email == null ||
        !user.providerData.any(
          (provider) => provider.providerId == 'password',
        )) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'Password authentication is not linked to this account.',
      );
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    return _requireUser();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final validation = AuthValidators.password(newPassword);
    if (validation != null) throw ArgumentError(validation);
    if (currentPassword == newPassword) {
      throw ArgumentError(
        'New password must be different from the current password.',
      );
    }
    final user = await _reauthenticatePassword(currentPassword);
    await user.updatePassword(newPassword);
  }

  @override
  Future<void> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    final normalized = AuthValidators.normalizeEmail(newEmail).toLowerCase();
    final validation = AuthValidators.email(normalized);
    if (validation != null) throw ArgumentError(validation);
    final user = await _reauthenticatePassword(currentPassword);
    if (user.email?.toLowerCase() == normalized) {
      throw ArgumentError('Enter a different email address.');
    }
    await user.verifyBeforeUpdateEmail(normalized);
  }

  @override
  Future<void> sendEmailVerification() =>
      _requireUser().sendEmailVerification();

  @override
  Future<AccountDeletionReadiness> inspectDeletionReadiness() async {
    final user = _requireUser();
    final snapshot = await _firestore
        .collection('groups')
        .where('memberIds', arrayContains: user.uid)
        .where('status', isEqualTo: 'active')
        .get();
    return AccountDeletionReadiness(
      ownedCircleNames: snapshot.docs
          .where((doc) => doc.data()['ownerId'] == user.uid)
          .map(
            (doc) => (doc.data()['name'] as String?)?.trim() ?? 'Family Circle',
          )
          .toList(growable: false),
    );
  }
}
