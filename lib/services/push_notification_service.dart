import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_service.dart';
import '../core/domain/push_policy.dart';
export '../core/domain/push_policy.dart';

class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  static const _requestedKey = 'notification_permission_requested_v1';
  static const _platform = MethodChannel(
    'com.familyemergency.app/notifications',
  );
  final _local = FlutterLocalNotificationsPlugin();
  final permission = ValueNotifier(PushPermissionState.notRequested);
  bool _initialized = false;
  final pendingTap = ValueNotifier<Map<String, dynamic>?>(null);
  final syncError = ValueNotifier<String?>(null);
  Future<void> _sync = Future.value();
  bool _detaching = false;
  String? _boundUid;
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (_initialized || !_supported) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _local.initialize(
        settings: const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (response) =>
            _emitPayload(response.payload),
      );
      await _createChannels();
      final launch = await _local.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _emitPayload(launch?.notificationResponse?.payload);
      }
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) _emitMessage(initialMessage);
      FirebaseMessaging.onMessage.listen((message) {
        unawaited(_showForeground(message).catchError((Object _) {}));
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_emitMessage);
      FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
      FirebaseAuth.instance.authStateChanges().listen((user) {
        _detaching = user == null;
        if (user != null) unawaited(bindCurrentUser());
      });
      await refreshPermissionState();
      if (FirebaseAuth.instance.currentUser != null) await bindCurrentUser();
    } catch (_) {
      syncError.value =
          'Push setup is unavailable. In-app history still works.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(bindCurrentUser());
  }

  Future<PushPermissionState> refreshPermissionState() async {
    if (!_supported) return permission.value = PushPermissionState.unavailable;
    try {
      final prefs = await SharedPreferences.getInstance();
      final requested = prefs.getBool(_requestedKey) ?? false;
      final status = Map<String, dynamic>.from(
        await _platform.invokeMapMethod<String, dynamic>(
              'getNotificationStatus',
            ) ??
            const {},
      );
      permission.value = PushPolicy.permission(status, requested);
    } catch (_) {
      permission.value = PushPermissionState.unavailable;
    }
    return permission.value;
  }

  Future<PushPermissionState> requestPermission() async {
    final current = await refreshPermissionState();
    if (current != PushPermissionState.notRequested &&
        current != PushPermissionState.denied) {
      return current;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_requestedKey, true);
    try {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {
      syncError.value =
          'Could not request notifications. Please try Android Settings.';
    }
    final state = await refreshPermissionState();
    await bindCurrentUser();
    return state;
  }

  Future<void> openSettings() async {
    try {
      if (await _platform.invokeMethod<bool>('openNotificationSettings') !=
          true) {
        syncError.value =
            'Open Android Settings > Apps > SafeCircle > Notifications.';
      }
    } catch (_) {
      syncError.value = 'Notification settings are unavailable on this device.';
    }
  }

  Future<void> bindCurrentUser({String? refreshedToken}) {
    if (!_supported || _detaching) return Future.value();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _sync = _sync.then((_) async {
      if (_detaching ||
          uid == null ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      try {
        await _bindCurrentUser(refreshedToken: refreshedToken);
        syncError.value = null;
      } catch (_) {
        syncError.value = 'Device push status could not sync. It will retry when the app resumes.';
      }
    });
    return _sync;
  }

  Future<void> _bindCurrentUser({String? refreshedToken}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (_boundUid != user.uid) {
      // Rotate across accounts, including an offline logout followed by relaunch.
      final previous = prefs.getString('push_bound_uid');
      if (previous != null && previous != user.uid) {
        await FirebaseMessaging.instance.deleteToken();
        refreshedToken = null;
      }
      await prefs.setString('push_bound_uid', user.uid);
      _boundUid = user.uid;
    }
    final deviceService = DeviceService();
    final installationId = await deviceService.currentInstallationId();
    await deviceService.registerCurrentDevice();
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final packageInfo = await PackageInfo.fromPlatform();
    final state = await refreshPermissionState();
    String? token;
    if (state == PushPermissionState.granted) {
      token = refreshedToken ?? await FirebaseMessaging.instance.getToken();
    }
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(installationId);
    final metadata = <String, dynamic>{
      'fcmToken': token,
      'notificationPermissionState': state.name,
      'notificationsEnabled': state == PushPermissionState.granted,
      'notificationCapable': true,
      'manufacturer': androidInfo.manufacturer,
      'model': androidInfo.model,
      'osVersion': androidInfo.version.release,
      'androidApiLevel': androidInfo.version.sdkInt,
      'appVersion': packageInfo.version,
      'appBuildNumber': packageInfo.buildNumber,
    };
    final previous = (await ref.get()).data() ?? {};
    if (metadata.entries.any((entry) => previous[entry.key] != entry.value)) {
      await ref.update({
        ...metadata,
        'fcmToken': token ?? FieldValue.delete(),
        'pushUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final circleIds = (profile.data()?['circleIds'] as List? ?? const [])
        .whereType<String>();
    final associationId = '${user.uid}_$installationId';
    for (final circleId in circleIds) {
      final association = FirebaseFirestore.instance
          .collection('groups')
          .doc(circleId)
          .collection('devices')
          .doc(associationId);
      try {
        final existing = (await association.get()).data();
        if (existing == null || existing['pairingStatus'] != 'paired') continue;
        final publicMetadata = {
          'manufacturer': androidInfo.manufacturer,
          'model': androidInfo.model,
          'osVersion': androidInfo.version.release,
          'androidApiLevel': androidInfo.version.sdkInt,
          'appVersion': packageInfo.version,
          'appBuildNumber': packageInfo.buildNumber,
          'notificationPermissionState': state.name,
          'notificationsEnabled': state == PushPermissionState.granted,
          'notificationCapable': true,
        };
        if (publicMetadata.entries.any(
          (entry) => existing[entry.key] != entry.value,
        )) {
          await association.update({
            ...publicMetadata,
            'pushUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied' && error.code != 'not-found') {
          rethrow;
        }
      }
    }
  }

  Future<void> detachCurrentUser() async {
    pendingTap.value = null;
    if (!_supported) return;
    _detaching = true;
    await _sync;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final id = await DeviceService().currentInstallationId();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(id)
          .set({
            'fcmToken': FieldValue.delete(),
            'notificationsEnabled': false,
            'pushUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      // Token invalidation must still run when the Firestore write fails.
    } finally {
      try {
        await FirebaseMessaging.instance.deleteToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('push_bound_uid');
      } catch (_) {
        syncError.value =
            'Push token cleanup will retry before another account is bound.';
      }
      try {
        await _local.cancelAll();
      } catch (_) {}
      _boundUid = null;
      // Keep refresh/resume callbacks suspended until the next sign-in event.
    }
  }

  Future<void> _saveToken(String token) async {
    if (permission.value != PushPermissionState.granted) return;
    await bindCurrentUser(refreshedToken: token);
  }

  Future<void> _createChannels() async {
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    const channels = [
      AndroidNotificationChannel(
        'emergency_sos',
        'Emergency SOS',
        description: 'Urgent family SOS alerts',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'family_activity',
        'Family activity',
        description: 'Circle requests and family updates',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'device_safety',
        'Device safety',
        description: 'Battery, offline and safety alerts',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'general',
        'General',
        description: 'General app notifications',
      ),
    ];
    for (final channel in channels) {
      await android.createNotificationChannel(channel);
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        (message.data['recipientUid'] != null &&
            message.data['recipientUid'] != user.uid)) {
      return;
    }
    if (await refreshPermissionState() != PushPermissionState.granted) return;
    final notification = message.notification;
    if (notification == null) return;
    final channel = _channelFor(message.data['type']?.toString());
    await _local.show(
      id:
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: channel.importance == Importance.max
              ? Priority.max
              : Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  AndroidNotificationChannel _channelFor(String? type) {
    final id = PushPolicy.channel(type);
    if (id == 'emergency_sos') {
      return const AndroidNotificationChannel(
        'emergency_sos',
        'Emergency SOS',
        importance: Importance.max,
      );
    }
    if (id == 'device_safety') {
      return const AndroidNotificationChannel(
        'device_safety',
        'Device safety',
        importance: Importance.high,
      );
    }
    if (id == 'family_activity') {
      return const AndroidNotificationChannel(
        'family_activity',
        'Family activity',
        importance: Importance.high,
      );
    }
    return const AndroidNotificationChannel('general', 'General');
  }

  void _emitMessage(RemoteMessage message) => _emit(message.data);
  void _emitPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      _emit(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (_) {}
  }

  void _emit(Map<String, dynamic> payload) {
    pendingTap.value = Map<String, dynamic>.from(payload);
  }
}
