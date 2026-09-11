import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_settings.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.exists,
    required this.name,
    required this.email,
    required this.phone,
    required this.relationship,
    required this.notificationSettings,
    required this.profileCompleted,
    required this.onboardingCompleted,
    this.address = const {},
    this.phoneCountryIso,
    this.phoneCountryCode,
    this.photoUrl,
    this.providerIds = const [],
    this.lastDailyCheckIn,
    this.createdAt,
    this.updatedAt,
    this.activeCircleId,
    this.circleIds = const [],
    this.pendingJoinCircleId,
    this.pendingJoinInviteId,
  });

  final Map<String, String> address;
  final String uid;
  final bool exists;
  final String name;
  final String email;
  final String phone;
  final String? relationship;
  final String? phoneCountryIso;
  final String? phoneCountryCode;
  final String? photoUrl;
  final List<String> providerIds;
  final NotificationSettings notificationSettings;
  final bool profileCompleted;
  final bool onboardingCompleted;
  final DateTime? lastDailyCheckIn;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? activeCircleId;
  final List<String> circleIds;
  final String? pendingJoinCircleId;
  final String? pendingJoinInviteId;

  bool get needsProfileCompletion => !profileCompleted;

  factory UserProfile.fromFirestore(User user, Map<String, dynamic>? data) {
    return UserProfile.fromData(
      uid: user.uid,
      data: data,
      fallbackName: user.displayName,
      fallbackEmail: user.email,
      fallbackPhone: user.phoneNumber,
      fallbackPhotoUrl: user.photoURL,
    );
  }

  /// Parses persisted profile data without trusting its shape. This is also
  /// useful for deterministic routing tests without a live Firebase user.
  factory UserProfile.fromData({
    required String uid,
    required Map<String, dynamic>? data,
    String? fallbackName,
    String? fallbackEmail,
    String? fallbackPhone,
    String? fallbackPhotoUrl,
  }) {
    final source = data ?? const <String, dynamic>{};
    final name = _string(source['name']) ?? fallbackName?.trim() ?? '';
    final email = _string(source['email']) ?? fallbackEmail?.trim() ?? '';
    final phone = _string(source['phone']) ?? fallbackPhone?.trim() ?? '';
    final relationship =
        _string(source['relationship']) ?? _string(source['role']);
    final safelyComplete =
        name.isNotEmpty && email.isNotEmpty && relationship != null;

    return UserProfile(
      uid: uid,
      exists: data != null,
      name: name,
      email: email,
      phone: phone,
      address: {
        if (source['address'] is Map)
          for (final key in const [
            'line1',
            'line2',
            'city',
            'region',
            'postalCode',
            'countryIso',
          ])
            key: _string((source['address'] as Map)[key]) ?? '',
      },
      relationship: relationship,
      phoneCountryIso: _string(source['phoneCountryIso']),
      phoneCountryCode: _string(source['phoneCountryCode']),
      photoUrl: _string(source['photoUrl']) ?? fallbackPhotoUrl,
      providerIds: _stringList(source['providerIds']),
      notificationSettings: NotificationSettings.fromMap(
        source['notificationSettings'] is Map
            ? Map<String, dynamic>.from(source['notificationSettings'] as Map)
            : null,
      ),
      profileCompleted:
          _bool(source['profileCompleted']) == true && safelyComplete,
      onboardingCompleted: _bool(source['onboardingCompleted']) == true,
      lastDailyCheckIn: _date(source['lastDailyCheckInAt']),
      createdAt: _date(source['createdAt']),
      updatedAt: _date(source['updatedAt']),
      activeCircleId: _string(source['activeCircleId']),
      circleIds: _stringList(source['circleIds']),
      pendingJoinCircleId: _string(source['pendingJoinCircleId']),
      pendingJoinInviteId: _string(source['pendingJoinInviteId']),
    );
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool? _bool(Object? value) => value is bool ? value : null;

  static DateTime? _date(Object? value) =>
      value is Timestamp ? value.toDate() : null;

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().where((item) => item.isNotEmpty).toList();
  }
}
