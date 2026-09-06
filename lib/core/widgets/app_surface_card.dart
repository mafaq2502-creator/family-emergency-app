import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.radius = 16});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: isDark ? kDarkCard : Colors.white, borderRadius: BorderRadius.circular(radius), border: Border.all(color: isDark ? const Color(0xFF233846) : const Color(0xFFE7EDF0))),
      child: child,
    );
  }
}
