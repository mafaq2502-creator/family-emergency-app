import 'package:family_emergency_app/core/widgets/authenticated_navigation_shell.dart';
import 'package:family_emergency_app/core/widgets/app_bottom_navigation.dart';
import 'package:family_emergency_app/features/shell/presentation/tabs/plan_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('one persistent bar survives detail, settings and Android Back', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final selected = ValueNotifier<int>(0);
    addTearDown(selected.dispose);
    Widget detail(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('User Detail')),
      body: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('User Notification Settings')),
            ),
          ),
        ),
        child: const Text('Settings'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticatedNavigationShell(
          navigatorKey: navigator,
          selected: selected,
          rootBuilder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: detail),
              ),
              child: const Text('Open User'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open User'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNavigation), findsOneWidget);
    expect(selected.value, 0);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomNavigation), findsOneWidget);
    expect(find.text('User Notification Settings'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('User Detail'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open User'), findsOneWidget);
    expect(find.byType(AppBottomNavigation), findsOneWidget);
  });
  testWidgets('monthly and yearly update price and CTA without reloading', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PlanSelectionContent())),
    );
    expect(
      find.textContaining(r'$2.99 / month', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Yearly (20% off)'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'$28.70', findRichText: true), findsWidgets);
    expect(find.text('Choose Yearly'), findsOneWidget);
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('Upgrade Now'), findsOneWidget);
  });
}
