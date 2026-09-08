import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('application shell starts without requiring live Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(
      const FamilyEmergencyApp(home: Scaffold(body: Text('Test home'))),
    );
    expect(find.text('Test home'), findsOneWidget);
  });
}
