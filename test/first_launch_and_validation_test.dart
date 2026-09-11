import 'package:family_emergency_app/services/intro_preferences.dart';
import 'package:family_emergency_app/features/auth/presentation/signup_screen.dart';
import 'package:family_emergency_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_form_test.dart' show FakeAuthActions;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('intro is claimed once even when closed before completion', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await IntroPreferences().claimFirstLaunch(), isTrue);
    expect(await IntroPreferences().claimFirstLaunch(), isFalse);
    final stored = (await SharedPreferences.getInstance()).getBool(
      IntroPreferences.seenKey,
    );
    SharedPreferences.setMockInitialValues({IntroPreferences.seenKey: stored!});
    expect(await IntroPreferences().claimFirstLaunch(), isFalse);
  });

  for (final signup in [false, true]) {
    testWidgets(
      '${signup ? 'signup' : 'login'} only validates the edited field before submit',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: signup
                ? SignUpScreen(authService: FakeAuthActions())
                : LoginScreen(authService: FakeAuthActions()),
          ),
        );
        final first = find.byType(TextFormField).first;
        await tester.tap(first);
        await tester.pump();
        expect(find.text('Please enter your password.'), findsNothing);
        final firstFieldError = signup
            ? 'Name must contain at least 2 characters.'
            : 'Please enter a valid email address.';
        await tester.enterText(first, signup ? 'A' : 'invalid-email');
        await tester.pump();
        expect(find.text(firstFieldError), findsNothing);
        expect(find.text('Please enter your password.'), findsNothing);
        expect(find.text('Please enter your email address.'), findsNothing);
        expect(find.text('Please enter your phone number.'), findsNothing);
        await tester.tap(find.byType(TextFormField).at(1));
        await tester.pump();
        expect(find.text(firstFieldError), findsOneWidget);
        expect(find.text('Please enter your password.'), findsNothing);
        expect(find.text('Please enter your phone number.'), findsNothing);
        final top = tester.getRect(first);
        final next = tester.getRect(find.byType(TextFormField).at(1));
        expect(next.top - top.bottom, greaterThanOrEqualTo(16));
      },
    );
  }
}
