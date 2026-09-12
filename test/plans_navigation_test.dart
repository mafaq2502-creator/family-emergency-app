import 'package:family_emergency_app/features/shell/presentation/tabs/plan_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pushed Plans screen returns to its caller', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const PlansScreen()),
              ),
              child: const Text('Open Plans'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Plans'));
    await tester.pumpAndSettle();
    expect(find.text('Plans'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open Plans'), findsOneWidget);
  });

  testWidgets('Plan tab content does not create a parent back route', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlanSelectionContent())),
    );
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Choose Your Plan'), findsOneWidget);
  });
}
