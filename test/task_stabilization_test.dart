import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:family_emergency_app/app/notification_navigation.dart';
import 'package:family_emergency_app/core/domain/push_policy.dart';
import 'package:family_emergency_app/core/theme/theme_mode_controller.dart';
import 'package:family_emergency_app/core/widgets/app_bottom_navigation.dart';
import 'package:family_emergency_app/core/widgets/app_page_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notification permission distinguishes denial, settings and unsupported',
    () {
      Map<String, dynamic> status({
        bool runtime = false,
        bool enabled = false,
        bool required = true,
        bool rationale = false,
      }) => {
        'runtimeGranted': runtime,
        'notificationsEnabled': enabled,
        'requiresRuntimePermission': required,
        'canShowRationale': rationale,
      };
      expect(
        PushPolicy.permission(status(), false),
        PushPermissionState.notRequested,
      );
      expect(
        PushPolicy.permission(status(rationale: true), true),
        PushPermissionState.denied,
      );
      expect(
        PushPolicy.permission(status(), true),
        PushPermissionState.settingsRequired,
      );
      expect(
        PushPolicy.permission(status(required: false, runtime: true), false),
        PushPermissionState.settingsRequired,
      );
      expect(
        PushPolicy.permission(status(runtime: true, enabled: true), false),
        PushPermissionState.granted,
      );
      expect(PushPolicy.permission({}, false), PushPermissionState.unavailable);
    },
  );

  test('notification categories use the four existing Android channels', () {
    expect(PushPolicy.channel('emergencyAcknowledged'), 'emergency_sos');
    expect(PushPolicy.channel('deviceOffline'), 'device_safety');
    expect(PushPolicy.channel('joinRequest'), 'family_activity');
    expect(PushPolicy.channel(null), 'general');
  });

  testWidgets(
    'all five nav icons and labels align without selection jumps or inset overlap',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        for (final inset in [0.0, 24.0, 48.0]) {
          for (final selected in [0, 1, 2, 3, 4]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: dark ? ThemeData.dark() : ThemeData.light(),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(320, 568),
                    padding: EdgeInsets.only(bottom: inset),
                    textScaler: TextScaler.linear(1.5),
                  ),
                  child: Scaffold(
                    bottomNavigationBar: AppBottomNavigation(
                      selectedIndex: selected,
                      onSelected: (_) {},
                    ),
                  ),
                ),
              ),
            );
            final positions = [
              'Progress',
              'Family',
              'Home',
              'Plan',
              'Profile',
            ].map((label) => tester.getTopLeft(find.text(label)).dy).toList();
            expect(
              positions.every((value) => (value - positions.first).abs() < .01),
              isTrue,
            );
            final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
            expect(icons.map((icon) => icon.size).toSet().length, 1);
            final iconY = find
                .byType(Icon)
                .evaluate()
                .map(
                  (element) =>
                      tester.getCenter(find.byWidget(element.widget)).dy,
                )
                .toList();
            expect(
              iconY.every((value) => (value - iconY.first).abs() < .01),
              isTrue,
            );
            expect(
              tester.getBottomRight(find.text('Home')).dy,
              lessThanOrEqualTo(568 - inset),
            );
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets(
    'slow native back cancels and commits once with opaque route backgrounds',
    (tester) async {
      Future<void> gesture(String method, [Map<String, dynamic>? args]) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/backgesture',
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, args),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        appThemeMode.value = mode;
        await tester.pumpWidget(
          const FamilyEmergencyApp(
            home: Scaffold(body: Text('Profile parent')),
          ),
        );
        appNavigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(
              backgroundColor: Colors.transparent,
              body: Text('Account child'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await gesture('startBackGesture', {
          'touchOffset': <double>[5, 300],
          'progress': 0.0,
          'swipeEdge': 0,
        });
        await gesture('updateBackGestureProgress', {
          'touchOffset': <double>[100, 300],
          'progress': .5,
          'swipeEdge': 0,
        });
        expect(
          find.ancestor(
            of: find.text('Account child'),
            matching: find.byType(AppPageBackground),
          ),
          findsWidgets,
        );
        await gesture('cancelBackGesture');
        expect(find.text('Account child'), findsOneWidget);
        expect(appNavigatorKey.currentState!.canPop(), isTrue);
        await gesture('startBackGesture', {
          'touchOffset': <double>[5, 300],
          'progress': 0.0,
          'swipeEdge': 0,
        });
        await gesture('updateBackGestureProgress', {
          'touchOffset': <double>[200, 300],
          'progress': .8,
          'swipeEdge': 0,
        });
        await gesture('commitBackGesture');
        expect(find.text('Profile parent'), findsOneWidget);
        expect(find.text('Account child'), findsNothing);
        expect(appNavigatorKey.currentState!.canPop(), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      appThemeMode.value = ThemeMode.system;
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
