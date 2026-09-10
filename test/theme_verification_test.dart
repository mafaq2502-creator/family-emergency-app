import 'dart:io';
import 'dart:ui' as ui;

import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:family_emergency_app/core/theme/app_colors.dart';
import 'package:family_emergency_app/core/theme/theme_mode_controller.dart';
import 'package:family_emergency_app/core/widgets/light_ui.dart';
import 'package:family_emergency_app/core/widgets/app_theme_mode_selector.dart';
import 'package:family_emergency_app/features/auth/presentation/login_screen.dart';
import 'package:family_emergency_app/features/auth/presentation/signup_screen.dart';
import 'package:family_emergency_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:family_emergency_app/features/auth/presentation/onboarding/intro_flow.dart';
import 'package:family_emergency_app/features/auth/presentation/onboarding/circle_onboarding_screen.dart';
import 'package:family_emergency_app/features/devices/presentation/device_screens.dart';
import 'package:family_emergency_app/features/groups/presentation/share_circle_screen.dart';
import 'package:family_emergency_app/features/members/presentation/member_profile_screen.dart';
import 'package:family_emergency_app/features/members/presentation/member_notification_settings_screen.dart';
import 'package:family_emergency_app/features/profile/presentation/account_settings_screen.dart';
import 'package:family_emergency_app/features/profile/presentation/profile_settings_screen.dart';
import 'package:family_emergency_app/features/progress/presentation/progress_detail_screens.dart';
import 'package:family_emergency_app/models/circle_role.dart';
import 'package:family_emergency_app/models/family_group.dart';
import 'package:family_emergency_app/models/family_member.dart';
import 'package:family_emergency_app/services/group_service.dart';
import 'package:family_emergency_app/services/circle_join_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:family_emergency_app/features/shell/presentation/tabs/plan_tab.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_form_test.dart' show FakeAuthActions;

class _FakeUser implements User {
  @override
  String get uid => 'theme-test-user';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCircleJoin implements CircleJoinActions {
  @override
  Future<String> joinWithCode(String code) async => 'unused';
}

const _member = FamilyMember(
  name: 'A very long family member name',
  status: 'Pending',
  relation: 'Daughter',
);
const _group = FamilyGroup(
  id: 'test',
  name: 'Our extended family Circle',
  ownerId: 'owner',
  role: CircleRole.owner,
);

AccountSettingsScreen _account() => AccountSettingsScreen(
  initialName: _member.name,
  email: 'a.long.email.address@example.com',
  phone: '+92 300 1234567',
  country: 'PK +92',
  relationship: 'Self',
  relationships: const ['Self', 'Father', 'Mother'],
  onSave: (_, _) async => true,
  onUpdatePassword: () {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final bytes = ByteData.sublistView(
      await File('build/ui-verification/fonts/Manrope.ttf').readAsBytes(),
    );
    for (final family in [
      'Manrope',
      'Ahem',
      'Manrope_regular',
      for (final weight in [100, 200, 300, 500, 600, 700, 800, 900])
        'Manrope_$weight',
    ]) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  tearDown(() => appThemeMode.value = ThemeMode.system);

  final screens = <String, Widget Function()>{
    'plan': () => const Scaffold(body: PlanSelectionContent()),
    'splash': () => const StartupSplash(),
    'intro': () => IntroFlow(onFinished: () {}),
    'login': () => LoginScreen(authService: FakeAuthActions()),
    'signup': () => SignUpScreen(authService: FakeAuthActions()),
    'reset_password': () =>
        ForgotPasswordScreen(authService: FakeAuthActions()),
    'account': _account,
    'security': () => const ProfileSettingsScreen(),
    'update_password': () => const UpdatePasswordScreen(),
    'member': () => const MemberProfileScreen(member: _member),
    'member_notifications': () =>
        MemberNotificationSettingsScreen(member: _member, onSave: (_) async {}),
    'share': () => const ShareCircleScreen(group: _group),
    'pair_device': () =>
        const DevicePairingScreen(member: _member, group: _group),
    'device': () =>
        const DeviceDetailScreen(memberName: 'A very long family member name'),
    'progress': () => const ProgressDetailsScreen(
      memberName: 'A very long family member name',
    ),
    'screen_time': () => const ScreenTimeDetailScreen(),
    'check_ins': () => const CheckInHistoryScreen(),
  };

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      for (final scale in [1.0, 1.5]) {
        for (final entry in screens.entries) {
          testWidgets('${mode.name} ${entry.key} ${size.width} text $scale', (
            tester,
          ) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            appThemeMode.value = mode;
            final boundaryKey = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundaryKey,
                child: FamilyEmergencyApp(home: entry.value()),
              ),
            );
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull);
            // Capture real widget renders for manual comparison with the masters.
            if (const bool.fromEnvironment('CAPTURE_UI') &&
                scale == 1 &&
                size.width == 430) {
              await tester.runAsync(() async {
                final boundary =
                    boundaryKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final rendered = await boundary.toImage();
                final bytes = await rendered.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final dir = Directory('build/ui-verification')
                  ..createSync(recursive: true);
                File('${dir.path}/${mode.name}_${entry.key}.png')
                    .writeAsBytesSync(bytes!.buffer.asUint8List());
                rendered.dispose();
              });
            }
            // Reach content below the fold as well as the initial viewport.
            final scrollable = find.byType(Scrollable);
            for (final element in scrollable.evaluate().toList()) {
              final state =
                  (element as StatefulElement).state as ScrollableState;
              if (state.position.axis == Axis.vertical) {
                state.position.jumpTo(state.position.maxScrollExtent);
              }
            }
            await tester.pump();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  }

  testWidgets(
    'theme changes update cards and headings, and System follows device',
    (tester) async {
      appThemeMode.value = ThemeMode.light;
      await tester.pumpWidget(
        const FamilyEmergencyApp(
          home: LightPage(
            title: 'Theme check',
            child: LightCard(child: Text('Card')),
          ),
        ),
      );
      BuildContext cardContext() => tester.element(find.byType(LightCard));
      expect(cardContext().appSurface, kLightSurface);
      appThemeMode.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(cardContext().appSurface, kDarkCard);
      expect(cardContext().appHeading, const Color(0xFFF8FAFC));
      final decoration =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(LightCard),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(decoration.color, kDarkCard);
      appThemeMode.value = ThemeMode.system;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await tester.pumpAndSettle();
      expect(cardContext().appSurface, kLightSurface);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(cardContext().appSurface, kDarkCard);
    },
  );

  testWidgets(
    'theme selector keeps every label visible and changes mode safely',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        var selected = ThemeMode.system;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: AppThemeModeSelector(
                  mode: selected,
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        );
        expect(find.text('System'), findsOneWidget);
        expect(find.text('Light'), findsOneWidget);
        expect(find.text('Dark'), findsOneWidget);
        await tester.tap(find.text('Dark'));
        await tester.pump();
        expect(selected, ThemeMode.dark);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Light'));
        await tester.pump();
        expect(selected, ThemeMode.light);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Circle field errors are marked on their own child tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: CircleOnboardingScreen(
          user: _FakeUser(),
          groupService: GroupService(),
          joinService: _FakeCircleJoin(),
          onSignOut: () async {},
          onCompleted: () {},
        ),
      ),
    );

    await tester.tap(find.text('Create Family Circle'));
    await tester.pump();
    expect(find.text('Please enter a family Circle name.'), findsOneWidget);
    expect(find.byKey(const ValueKey('circle-tab-error-0')), findsOneWidget);

    await tester.tap(find.text('Join Circle'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a family Circle name.'), findsNothing);
    await tester.tap(find.text('Join Family Circle'));
    await tester.pump();
    expect(find.text('Please enter an invitation code.'), findsOneWidget);
    expect(find.byKey(const ValueKey('circle-tab-error-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account keyboard and unsaved changes dialog fit both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      appThemeMode.value = mode;
      await tester.pumpWidget(
        FamilyEmergencyApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => _account()),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Changed name');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pump();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Save changes?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Account Settings'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
