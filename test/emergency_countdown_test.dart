import 'package:family_emergency_app/app/family_emergency_app.dart';
import 'package:family_emergency_app/features/shell/presentation/family_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Emergency countdown starts at 5 and Cancel prevents completion', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const EmergencyCountdownDialog(groupName: 'Family'),
              );
            },
            child: const Text('SOS'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SOS'));
    await tester.pump();
    expect(find.textContaining('sent in 5 seconds'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('sent in 4 seconds'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('Emergency countdown completes exactly once', (tester) async {
    var completions = 0;
    await tester.pumpWidget(
      FamilyEmergencyApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              if (await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const EmergencyCountdownDialog(groupName: 'Family'),
                  ) ==
                  true) {
                completions++;
              }
            },
            child: const Text('SOS'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SOS'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(completions, 1);
  });
}
