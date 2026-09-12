import 'package:cloud_firestore/cloud_firestore.dart';

enum ScreenTimePermissionState { unknown, notGranted, granted, unavailable }

enum ScreenTimePeriod { today, yesterday, lastWeek, lastMonth }

extension ScreenTimePeriodX on ScreenTimePeriod {
  String get label => switch (this) {
    ScreenTimePeriod.today => 'Today',
    ScreenTimePeriod.yesterday => 'Yesterday',
    ScreenTimePeriod.lastWeek => 'Last week',
    ScreenTimePeriod.lastMonth => 'Last month',
  };

  DateTimeRangeBounds bounds(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ScreenTimePeriod.today => DateTimeRangeBounds(today, now),
      ScreenTimePeriod.yesterday => DateTimeRangeBounds(
        today.subtract(const Duration(days: 1)),
        today,
      ),
      ScreenTimePeriod.lastWeek => DateTimeRangeBounds(
        today.subtract(const Duration(days: 6)),
        now,
      ),
      ScreenTimePeriod.lastMonth => DateTimeRangeBounds(
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month),
      ),
    };
  }

  static ScreenTimePeriod fromLabel(String label) =>
      ScreenTimePeriod.values.firstWhere(
        (value) => value.label == label,
        orElse: () => ScreenTimePeriod.today,
      );
}

class DateTimeRangeBounds {
  const DateTimeRangeBounds(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

class AppScreenTimeUsage {
  const AppScreenTimeUsage({
    required this.packageName,
    required this.appName,
    required this.totalTime,
    this.lastUsedAt,
  });
  final String packageName;
  final String appName;
  final Duration totalTime;
  final DateTime? lastUsedAt;

  factory AppScreenTimeUsage.fromMap(Map<Object?, Object?> map) =>
      AppScreenTimeUsage(
        packageName: map['packageName']?.toString() ?? '',
        appName: map['appName']?.toString() ?? 'Unknown app',
        totalTime: Duration(
          milliseconds: (map['totalTimeMs'] as num?)?.round() ?? 0,
        ),
        lastUsedAt: _dateFromMilliseconds(map['lastTimeUsedMs']),
      );

  Map<String, Object?> toMap() => {
    'packageName': packageName,
    'appName': appName,
    'totalTimeMs': totalTime.inMilliseconds,
    if (lastUsedAt != null)
      'lastTimeUsedMs': lastUsedAt!.millisecondsSinceEpoch,
  };
}

class ScreenTimeDailyRecord {
  const ScreenTimeDailyRecord({
    required this.id,
    required this.userId,
    required this.installationId,
    required this.localDate,
    required this.timeZoneOffsetMinutes,
    required this.totalTime,
    required this.apps,
    required this.collectedAt,
    this.syncedAt,
  });
  final String id;
  final String userId;
  final String installationId;
  final String localDate;
  final int timeZoneOffsetMinutes;
  final Duration totalTime;
  final List<AppScreenTimeUsage> apps;
  final DateTime collectedAt;
  final DateTime? syncedAt;

  factory ScreenTimeDailyRecord.fromMap(String id, Map<String, dynamic> map) =>
      ScreenTimeDailyRecord(
        id: id,
        userId: map['userId'] as String? ?? '',
        installationId: map['installationId'] as String? ?? '',
        localDate: map['localDate'] as String? ?? '',
        timeZoneOffsetMinutes: map['timeZoneOffsetMinutes'] as int? ?? 0,
        totalTime: Duration(
          milliseconds: (map['totalTimeMs'] as num?)?.round() ?? 0,
        ),
        apps: (map['apps'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => AppScreenTimeUsage.fromMap(item))
            .toList(),
        collectedAt:
            _date(map['collectedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        syncedAt: _date(map['syncedAt']),
      );

  Map<String, Object?> toFirestore() => {
    'userId': userId,
    'installationId': installationId,
    'localDate': localDate,
    'timeZoneOffsetMinutes': timeZoneOffsetMinutes,
    'totalTimeMs': totalTime.inMilliseconds,
    'apps': apps.map((item) => item.toMap()).toList(),
    'collectedAt': Timestamp.fromDate(collectedAt.toUtc()),
    'syncedAt': FieldValue.serverTimestamp(),
    'source': 'android_usage_stats',
    'schemaVersion': 1,
  };
}

class ScreenTimeSummary {
  const ScreenTimeSummary({
    required this.totalTime,
    required this.apps,
    required this.deviceCount,
    this.lastSyncedAt,
  });
  final Duration totalTime;
  final List<AppScreenTimeUsage> apps;
  final int deviceCount;
  final DateTime? lastSyncedAt;

  static ScreenTimeSummary aggregate(List<ScreenTimeDailyRecord> records) {
    // A member can have overlapping Android devices. For each local day we use
    // the device with the largest total instead of adding overlapping usage.
    final perDay = <String, ScreenTimeDailyRecord>{};
    final devices = <String>{};
    DateTime? latest;
    for (final record in records) {
      devices.add(record.installationId);
      final existing = perDay[record.localDate];
      if (existing == null || record.totalTime > existing.totalTime) {
        perDay[record.localDate] = record;
      }
      final synced = record.syncedAt;
      if (synced != null && (latest == null || synced.isAfter(latest))) {
        latest = synced;
      }
    }
    final appTotals = <String, AppScreenTimeUsage>{};
    var totalMs = 0;
    for (final record in perDay.values) {
      totalMs += record.totalTime.inMilliseconds;
      for (final app in record.apps) {
        final key = app.packageName.isEmpty ? app.appName : app.packageName;
        final old = appTotals[key];
        final oldLastUsed = old?.lastUsedAt;
        appTotals[key] = AppScreenTimeUsage(
          packageName: app.packageName,
          appName: app.appName,
          totalTime: Duration(
            milliseconds:
                (old?.totalTime.inMilliseconds ?? 0) +
                app.totalTime.inMilliseconds,
          ),
          lastUsedAt:
              oldLastUsed == null ||
                  (app.lastUsedAt?.isAfter(oldLastUsed) ?? false)
              ? app.lastUsedAt
              : oldLastUsed,
        );
      }
    }
    final apps = appTotals.values.toList()
      ..sort((a, b) => b.totalTime.compareTo(a.totalTime));
    return ScreenTimeSummary(
      totalTime: Duration(milliseconds: totalMs),
      apps: apps,
      deviceCount: devices.length,
      lastSyncedAt: latest,
    );
  }
}

DateTime? _date(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime date => date,
  _ => null,
};

DateTime? _dateFromMilliseconds(Object? value) => value is num && value > 0
    ? DateTime.fromMillisecondsSinceEpoch(value.round())
    : null;

String screenTimeLocalDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String formatScreenTime(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}
