import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = dark ? kEmerald : kLightPrimary;
    final inactive = dark ? kDarkMuted : kLightMuted;
    const items = [
      (Icons.bar_chart_rounded, 'Progress', 1),
      (Icons.groups_rounded, 'Family', 0),
      (Icons.home_rounded, 'Home', 2),
      (Icons.workspace_premium_rounded, 'Plan', 3),
      (Icons.person_rounded, 'Profile', 4),
    ];
    return Material(
      color: dark ? kDarkSurface : kLightSurface,
      elevation: 10,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final requestedScale =
                  MediaQuery.textScalerOf(context)
                      .scale(AppTypography.tabLabel) /
                  AppTypography.tabLabel;
              final measure = TextPainter(
                text: TextSpan(
                  text: 'Progress',
                  style: DefaultTextStyle.of(context).style.copyWith(
                    fontSize: AppTypography.tabLabel,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                textDirection: Directionality.of(context),
              )..layout();
              final scale = requestedScale.clamp(
                0.0,
                (constraints.maxWidth / 5 - 4) / measure.width,
              );
              measure.dispose();
              return Row(
                children: [
                  for (final item in items)
                    Expanded(
                      child: Semantics(
                        selected: selectedIndex == item.$3,
                        button: true,
                        child: InkWell(
                          key: ValueKey('nav-${item.$2}'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onSelected(item.$3),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 48,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selectedIndex == item.$3
                                      ? active.withValues(alpha: .13)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  item.$1,
                                  size: AppTypography.tabIcon,
                                  color: selectedIndex == item.$3
                                      ? active
                                      : inactive,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.$2,
                                textScaler: TextScaler.linear(scale),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: AppTypography.tabLabel,
                                  height: 1.3,
                                  color: selectedIndex == item.$3
                                      ? active
                                      : inactive,
                                  fontWeight: selectedIndex == item.$3
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
