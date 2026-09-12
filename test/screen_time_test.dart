import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_emergency_app/models/screen_time.dart';
import 'package:family_emergency_app/services/screen_time_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screen-time periods', () {
    final now = DateTime(2026, 9, 12, 15, 30);

    test('Today and Yesterday use local calendar boundaries', () {
      final today = ScreenTimePeriod.today.bounds(now);
      final yesterday = ScreenTimePeriod.yesterday.bounds(now);
      expect(today.start, DateTime(2026, 9, 12));
      expect(today.end, now);
      expect(yesterday.start, DateTime(2026, 9, 11));
      expect(yesterday.end, DateTime(2026, 9, 12));
    });

    test('Last week is seven local days and Last month is previous month', () {
      final week = ScreenTimePeriod.lastWeek.bounds(now);
      final month = ScreenTimePeriod.lastMonth.bounds(now);
      expect(week.start, DateTime(2026, 9, 6));
      expect(week.end, now);
      expect(month.start, DateTime(2026, 8));
      expect(month.end, DateTime(2026, 9));
    });
  });

  test(
    'aggregation avoids overlapping multi-device double counting per day',
    () {
      ScreenTimeDailyRecord record(String id, String device, int minutes) =>
          ScreenTimeDailyRecord(
            id: id,
            userId: 'user-1',
            installationId: device,
            localDate: '2026-09-12',
            timeZoneOffsetMinutes: 300,
            totalTime: Duration(minutes: minutes),
            apps: [
              AppScreenTimeUsage(
                packageName: 'example.app',
                appName: 'Example',
                totalTime: Duration(minutes: minutes),
              ),
            ],
            collectedAt: DateTime(2026, 9, 12, 15),
          );

      final summary = ScreenTimeSummary.aggregate([
        record('a', 'device-a', 60),
        record('b', 'device-b', 90),
      ]);
      expect(summary.totalTime, const Duration(minutes: 90));
      expect(summary.apps.single.totalTime, const Duration(minutes: 90));
      expect(summary.deviceCount, 2);
    },
  );

  group('Android platform bridge', () {
    const channel = MethodChannel('com.familyemergency.app/screen_time');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getPermissionState') return 'granted';
        if (call.method == 'openUsageAccessSettings') return true;
        if (call.method == 'queryUsageStats') {
          return <Map<String, Object>>[
            {
              'packageName': 'com.example.reader',
              'appName': 'Reader',
              'totalTimeMs': 120000,
              'lastTimeUsedMs': 1789200000000,
            },
          ];
        }
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('reads permission and real native usage payload', () async {
      const platform = AndroidScreenTimePlatform();
      expect(
        await platform.permissionState(),
        ScreenTimePermissionState.granted,
      );
      expect(await platform.openUsageAccessSettings(), isTrue);
      final apps = await platform.query(
        DateTime(2026, 9, 12),
        DateTime(2026, 9, 13),
      );
      expect(apps.single.appName, 'Reader');
      expect(apps.single.totalTime, const Duration(minutes: 2));
    });
  });
}
