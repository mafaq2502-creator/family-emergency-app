import 'package:flutter/material.dart';

import 'app_bottom_navigation.dart';

/// Normal signed-in routes share one navigator above a single bottom bar.
class AuthenticatedNavigationShell extends StatelessWidget {
  const AuthenticatedNavigationShell({
    super.key,
    required this.navigatorKey,
    required this.selected,
    required this.rootBuilder,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final ValueNotifier<int> selected;
  final WidgetBuilder rootBuilder;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: NavigatorPopHandler<Object?>(
      onPopWithResult: (result) => navigatorKey.currentState?.pop(result),
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: rootBuilder),
      ),
    ),
    bottomNavigationBar: ValueListenableBuilder<int>(
      valueListenable: selected,
      builder: (context, index, _) => AppBottomNavigation(
        selectedIndex: index,
        onSelected: (value) {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
          selected.value = value;
        },
      ),
    ),
  );
}
