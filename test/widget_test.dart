import 'package:flutter_test/flutter_test.dart';
import 'package:family_emergency_app/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FamilyEmergencyApp());

    // Verify that the app title is present
    expect(find.text('Family Emergency'), findsOneWidget);
  });
}
