import 'package:family_emergency_app/features/auth/presentation/login_screen.dart';
import 'package:family_emergency_app/features/auth/presentation/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sign in blocks invalid credentials before contacting Firebase', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Login'));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Minimum 6 characters'), findsOneWidget);
  });

  testWidgets('sign up blocks mismatched passwords before creating an account', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'Afaq');
    await tester.enterText(fields.at(1), 'afaq@example.com');
    await tester.enterText(fields.at(3), 'secret1');
    await tester.enterText(fields.at(4), 'secret2');
    await tester.tap(find.text('Sign Up'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
