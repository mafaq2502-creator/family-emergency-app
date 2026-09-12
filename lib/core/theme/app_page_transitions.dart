import 'package:flutter/material.dart';

import '../widgets/app_page_background.dart';

/// Keep each real route opaque, including transparent app bars/scaffolds.
/// Flutter still owns gesture progress, cancellation, and the single route pop.
class AppPageTransitionsBuilder
    extends PredictiveBackFullscreenPageTransitionsBuilder {
  const AppPageTransitionsBuilder({super.fallbackColor});

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => super.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    AppPageBackground(child: child),
  );
}
