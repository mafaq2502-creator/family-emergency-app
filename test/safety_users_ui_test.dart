import 'dart:async';

import 'package:family_emergency_app/features/members/presentation/safety_users_screen.dart';
import 'package:family_emergency_app/models/notification_settings.dart';
import 'package:family_emergency_app/services/safety_user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSafety extends SafetyUserService {
  @override
  String get uid => 'owner';
  bool premium = false;
  final calls = <String>[];
  final changes = StreamController<Map<String, dynamic>?>.broadcast();
  final incoming = StreamController<List<Map<String, dynamic>>>.broadcast();
  Map<String, dynamic>? value = {
    'id': 'one',
    'ownerId': 'owner',
    'name': 'Afaq',
    'email': 'a@example.test',
    'phone': '+923001234567',
    'relationship': 'Brother',
    'status': 'connected',
    'notificationPreferences': {
      for (final key in safetyNotificationCategories.keys)
        key: key == 'emergencyAlerts',
    },
  };
  @override
  Stream<Map<String, dynamic>?> detail(String id) async* {
    yield value;
    yield* changes.stream;
  }

  @override
  Stream<Map<String, dynamic>> profile() => Stream.value({
    'planTier': premium ? 'premium' : 'free',
    'subscriptionStatus': premium ? 'active' : 'inactive',
  });
  @override
  Stream<List<Map<String, dynamic>>> users() => Stream.value([value!]);
  @override
  Stream<List<Map<String, dynamic>>> requests({bool circle = false}) async* {
    yield [
      {'id': 'request', 'senderName': 'Afaq'},
    ];
    yield* incoming.stream;
  }

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> data,
  ) async {
    calls.add(name);
    if (name == 'respondSafetyInvite') incoming.add([]);
    if (name == 'updateSafetyPreferences') {
      value = {...value!, 'notificationPreferences': data['preferences']};
      changes.add(value);
    }
    return {};
  }

  void dispose() {
    changes.close();
    incoming.close();
  }
}

void main() {
  testWidgets(
    'Users contains list and incoming requests without mixing Circles',
    (tester) async {
      final service = FakeSafety();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(home: SafetyUsersScreen(service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Users List'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Add New User'), findsOneWidget);
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.text('Wants to add you'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(service.calls, ['respondSafetyInvite']);
      expect(find.text('No pending requests.'), findsOneWidget);
    },
  );
  testWidgets(
    'removal requires confirmation and Cancel/X do not call backend',
    (tester) async {
      final service = FakeSafety();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SafetyUserDetailScreen(id: 'one', service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove User'));
      await tester.pumpAndSettle();
      expect(find.text('Remove User?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);
      await tester.tap(find.byTooltip('Remove User'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);
      await tester.tap(find.byTooltip('Remove User'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(service.calls, ['removeSafetyUser']);
    },
  );
  testWidgets('non-owner has no Remove User control', (tester) async {
    final service = FakeSafety();
    addTearDown(service.dispose);
    service.value = {...service.value!, 'ownerId': 'another-owner'};
    await tester.pumpWidget(
      MaterialApp(
        home: SafetyUserDetailScreen(id: 'one', service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove User'), findsNothing);
  });
  testWidgets('Premium preferences save against selected relationship', (
    tester,
  ) async {
    final service = FakeSafety()..premium = true;
    addTearDown(service.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: SafetyPreferencesScreen(id: 'one', service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Battery'));
    await tester.pumpAndSettle();
    expect(service.calls, ['updateSafetyPreferences']);
    expect(
      (service.value!['notificationPreferences'] as Map)['batteryAlerts'],
      true,
    );
    expect(
      (service.value!['notificationPreferences'] as Map)['emergencyAlerts'],
      true,
    );
  });
  for (final brightness in Brightness.values) {
    testWidgets('Add User form fits compact $brightness with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: AddSafetyUserScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('User Name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
