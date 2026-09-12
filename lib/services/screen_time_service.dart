import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/screen_time.dart';
import 'device_service.dart';

const _screenTimeBackgroundTask = 'screen-time-periodic-sync-v1';

@pragma('vm:entry-point')
void screenTimeCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _screenTimeBackgroundTask) return true;
    try {
      await Firebase.initializeApp();
      if (FirebaseAuth.instance.currentUser == null) return true;
      final service = ScreenTimeService();
      await service.retryPending();
      if (await service.hasConsent() &&
          await service.permissionState() ==
              ScreenTimePermissionState.granted) {
        await service.syncCurrentDevice(period: ScreenTimePeriod.today);
      }
      return true;
    } catch (_) {
      // WorkManager retries transient Firebase/native failures with backoff.
      return false;
    }
  });
}

Future<void> initializeScreenTimeBackgroundSync() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await Workmanager().initialize(screenTimeCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _screenTimeBackgroundTask,
    _screenTimeBackgroundTask,
    frequency: const Duration(hours: 6),
    initialDelay: const Duration(minutes: 30),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 15),
  );
}

abstract interface class ScreenTimePlatform {
  Future<ScreenTimePermissionState> permissionState();
  Future<bool> openUsageAccessSettings();
  Future<List<AppScreenTimeUsage>> query(DateTime start, DateTime end);
}

class AndroidScreenTimePlatform implements ScreenTimePlatform {
  const AndroidScreenTimePlatform();
  static const _channel = MethodChannel('com.familyemergency.app/screen_time');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<ScreenTimePermissionState> permissionState() async {
    if (!_isAndroid) return ScreenTimePermissionState.unavailable;
    try {
      final value = await _channel.invokeMethod<String>('getPermissionState');
      return ScreenTimePermissionState.values.firstWhere(
        (state) => state.name == value,
        orElse: () => ScreenTimePermissionState.unknown,
      );
    } on MissingPluginException {
      return ScreenTimePermissionState.unavailable;
    } on PlatformException {
      return ScreenTimePermissionState.unknown;
    }
  }

  @override
  Future<bool> openUsageAccessSettings() async {
    if (!_isAndroid) return false;
    return await _channel.invokeMethod<bool>('openUsageAccessSettings') ??
        false;
  }

  @override
  Future<List<AppScreenTimeUsage>> query(DateTime start, DateTime end) async {
    if (!_isAndroid) return const [];
    final raw = await _channel.invokeListMethod<Object?>('queryUsageStats', {
      'startMs': start.millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
    });
    return (raw ?? const [])
        .whereType<Map>()
        .map((item) => AppScreenTimeUsage.fromMap(item))
        .where((item) => item.totalTime > Duration.zero)
        .toList();
  }
}

class ScreenTimeException implements Exception {
  const ScreenTimeException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class ScreenTimeService {
  ScreenTimeService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DeviceActions? deviceService,
    ScreenTimePlatform? platform,
    DateTime Function()? clock,
  }) : _providedFirestore = firestore,
       _providedAuth = auth,
       _devices = deviceService ?? DeviceService(),
       _platform = platform ?? const AndroidScreenTimePlatform(),
       _clock = clock ?? DateTime.now;

  static const consentKey = 'screen_time_consent_v1';
  static const _pendingKey = 'screen_time_pending_v1';
  final FirebaseFirestore? _providedFirestore;
  final FirebaseAuth? _providedAuth;
  final DeviceActions _devices;
  final ScreenTimePlatform _platform;
  final DateTime Function() _clock;

  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ScreenTimeException(
        'unauthenticated',
        'Please sign in again.',
      );
    }
    return user;
  }

  Future<bool> hasConsent() async =>
      (await SharedPreferences.getInstance()).getBool(consentKey) ?? false;

  Future<void> recordConsent() async =>
      (await SharedPreferences.getInstance()).setBool(consentKey, true);

  Future<ScreenTimePermissionState> permissionState() =>
      _platform.permissionState();

  Future<bool> openUsageAccessSettings() => _platform.openUsageAccessSettings();

  Future<ScreenTimeSummary> loadCircleSummary({
    required String circleId,
    String? userId,
    required ScreenTimePeriod period,
  }) async {
    final bounds = period.bounds(_clock());
    Query<Map<String, dynamic>> query = _firestore
        .collection('groups')
        .doc(circleId)
        .collection('screenTimeDaily');
    if (userId != null && userId.isNotEmpty) {
      query = query.where('userId', isEqualTo: userId);
    }
    final snapshot = await query.get();
    final startKey = screenTimeLocalDate(bounds.start);
    final inclusiveEnd = bounds.end.subtract(const Duration(milliseconds: 1));
    final endKey = screenTimeLocalDate(inclusiveEnd);
    final records = snapshot.docs
        .map((doc) => ScreenTimeDailyRecord.fromMap(doc.id, doc.data()))
        .where(
          (record) =>
              record.localDate.compareTo(startKey) >= 0 &&
              record.localDate.compareTo(endKey) <= 0,
        )
        .toList();
    return ScreenTimeSummary.aggregate(records);
  }

  Future<ScreenTimeSummary> syncAndLoad({
    required String circleId,
    String? userId,
    required ScreenTimePeriod period,
  }) async {
    final user = _user;
    if (userId == null || userId == user.uid) {
      await syncCurrentDevice(period: period);
    }
    return loadCircleSummary(
      circleId: circleId,
      userId: userId,
      period: period,
    );
  }

  Future<void> syncCurrentDevice({
    ScreenTimePeriod period = ScreenTimePeriod.lastWeek,
  }) async {
    final permission = await permissionState();
    await _publishPermission(permission);
    if (permission != ScreenTimePermissionState.granted) {
      throw ScreenTimeException(
        permission == ScreenTimePermissionState.unavailable
            ? 'unavailable'
            : 'usage-access-denied',
        permission == ScreenTimePermissionState.unavailable
            ? 'Screen time is unavailable on this device.'
            : 'Enable Usage access to sync screen time.',
      );
    }
    if (!await hasConsent()) {
      throw const ScreenTimeException(
        'consent-required',
        'Review and accept screen-time sharing before syncing.',
      );
    }
    final user = _user;
    final device = await _devices.registerCurrentDevice();
    final installationId = device.installationId ?? device.id;
    final bounds = period.bounds(_clock());
    final records = <ScreenTimeDailyRecord>[];
    var cursor = DateTime(
      bounds.start.year,
      bounds.start.month,
      bounds.start.day,
    );
    while (cursor.isBefore(bounds.end)) {
      final nextDay = cursor.add(const Duration(days: 1));
      final dayEnd = nextDay.isBefore(bounds.end) ? nextDay : bounds.end;
      final apps = await _platform.query(cursor, dayEnd);
      final collectedAt = _clock();
      records.add(
        ScreenTimeDailyRecord(
          id: '${user.uid}_${installationId}_${screenTimeLocalDate(cursor)}',
          userId: user.uid,
          installationId: installationId,
          localDate: screenTimeLocalDate(cursor),
          timeZoneOffsetMinutes: cursor.timeZoneOffset.inMinutes,
          totalTime: Duration(
            milliseconds: apps.fold(
              0,
              (total, app) => total + app.totalTime.inMilliseconds,
            ),
          ),
          apps: apps.take(100).toList(),
          collectedAt: collectedAt,
        ),
      );
      cursor = nextDay;
    }
    await _savePending(records);
    await _writeRecords(records);
    await _clearPending();
  }

  Future<void> retryPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final records = decoded
        .whereType<Map>()
        .map((map) {
          final value = Map<String, dynamic>.from(map);
          return ScreenTimeDailyRecord.fromMap(value['id'] as String? ?? '', {
            ...value,
            'collectedAt': DateTime.tryParse(
              value['collectedAt']?.toString() ?? '',
            ),
            'syncedAt': DateTime.tryParse(value['syncedAt']?.toString() ?? ''),
          });
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
    if (records.isEmpty) return;
    await _writeRecords(records);
    await _clearPending();
  }

  Future<void> _writeRecords(List<ScreenTimeDailyRecord> records) async {
    final user = _user;
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final circleIds = (profile.data()?['circleIds'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final installationId = records.first.installationId;
    final associationId = '${user.uid}_$installationId';
    final pairedCircleIds = <String>[];
    for (final circleId in circleIds) {
      final association = await _firestore
          .collection('groups')
          .doc(circleId)
          .collection('devices')
          .doc(associationId)
          .get();
      if (association.data()?['pairingStatus'] == 'paired') {
        pairedCircleIds.add(circleId);
      }
    }
    final batch = _firestore.batch();
    for (final record in records) {
      final own = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(record.installationId)
          .collection('screenTimeDaily')
          .doc(record.localDate);
      batch.set(own, record.toFirestore(), SetOptions(merge: true));
      for (final circleId in pairedCircleIds) {
        final mirror = _firestore
            .collection('groups')
            .doc(circleId)
            .collection('screenTimeDaily')
            .doc(record.id);
        batch.set(mirror, record.toFirestore(), SetOptions(merge: true));
      }
    }
    for (final circleId in pairedCircleIds) {
      batch.set(
        _firestore
            .collection('groups')
            .doc(circleId)
            .collection('devices')
            .doc(associationId),
        {
          'permissions': {'screenTime': true},
          'lastScreenTimeSyncAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    batch.set(
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(installationId),
      {
        'permissions': {'screenTime': true},
        'lastScreenTimeSyncAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    // Firestore accepts offline writes into its durable local queue. Keep our
    // explicit pending payload until a server read confirms this device's most
    // recent deterministic document reached the backend.
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(installationId)
        .collection('screenTimeDaily')
        .doc(records.last.localDate)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
  }

  Future<void> _publishPermission(ScreenTimePermissionState state) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final id = await _devices.currentInstallationId();
    final own = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(id);
    if (!(await own.get()).exists) return;
    final value = state == ScreenTimePermissionState.granted;
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final circleIds = (profile.data()?['circleIds'] as List? ?? const [])
        .whereType<String>();
    final associationId = '${user.uid}_$id';
    final batch = _firestore.batch();
    batch.set(own, {
      'permissions': {'screenTime': value},
      'screenTimePermissionState': state.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    for (final circleId in circleIds) {
      final association = _firestore
          .collection('groups')
          .doc(circleId)
          .collection('devices')
          .doc(associationId);
      if (!(await association.get()).exists) continue;
      batch.set(association, {
        'permissions': {'screenTime': value},
        'screenTimePermissionState': state.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _savePending(List<ScreenTimeDailyRecord> records) async {
    final values = records
        .map(
          (record) => {
            'id': record.id,
            ...record.toFirestore(),
            'collectedAt': record.collectedAt.toIso8601String(),
            'syncedAt': record.syncedAt?.toIso8601String(),
          },
        )
        .toList();
    // FieldValue cannot be encoded. Pending data gets a fresh server timestamp
    // when replayed.
    for (final value in values) {
      value.remove('syncedAt');
    }
    await (await SharedPreferences.getInstance()).setString(
      _pendingKey,
      jsonEncode(values),
    );
  }

  Future<void> _clearPending() async =>
      (await SharedPreferences.getInstance()).remove(_pendingKey);
}
