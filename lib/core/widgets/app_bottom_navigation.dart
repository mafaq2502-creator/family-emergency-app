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
    final surface = dark ? kDarkSurface : kLightSurface;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const items = [
      (Icons.bar_chart_rounded, 'Progress', 1),
      (Icons.groups_rounded, 'Family', 0),
      (Icons.home_rounded, 'Home', 2),
      (Icons.assignment_outlined, 'Plan', 3),
      (Icons.person_outline_rounded, 'Profile', 4),
    ];

    return SizedBox(
      height: 104 + bottomInset,
      child: CustomPaint(
        painter: _NavigationBarPainter(
          surface: surface,
          accent: active,
          dark: dark,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(4, 22, 4, 8 + bottomInset),
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
                      child: _NavigationItem(
                        icon: item.$1,
                        label: item.$2,
                        selected: selectedIndex == item.$3,
                        raised: item.$3 == 2,
                        active: active,
                        inactive: inactive,
                        surface: surface,
                        textScale: scale,
                        onTap: () => onSelected(item.$3),
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

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.raised,
    required this.active,
    required this.inactive,
    required this.surface,
    required this.textScale,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool raised;
  final Color active;
  final Color inactive;
  final Color surface;
  final double textScale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      key: ValueKey('nav-$label'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Transform.translate(
        offset: Offset(0, raised ? 0 : 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 68,
              height: 44,
              child: Transform.translate(
                offset: Offset(0, raised ? -20 : 0),
                child: OverflowBox(
                  minWidth: raised ? 64 : 0,
                  maxWidth: raised ? 64 : 68,
                  minHeight: raised ? 64 : 0,
                  maxHeight: raised ? 64 : 44,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: raised
                          ? (selected ? active : surface)
                          : selected
                          ? active.withValues(alpha: .13)
                          : Colors.transparent,
                      shape: raised ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: raised ? null : BorderRadius.circular(14),
                      border: raised
                          ? Border.all(
                              color: selected
                                  ? Colors.white
                                  : active.withValues(alpha: .45),
                              width: 3,
                            )
                          : null,
                      boxShadow: raised
                          ? [
                              BoxShadow(
                                color: active.withValues(alpha: .25),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: AppTypography.tabIcon,
                      color: raised && selected
                          ? Colors.white
                          : selected
                          ? active
                          : inactive,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textScaler: TextScaler.linear(textScale),
              maxLines: 1,
              style: TextStyle(
                fontSize: AppTypography.tabLabel,
                height: 1.3,
                color: selected ? active : inactive,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NavigationBarPainter extends CustomPainter {
  const _NavigationBarPainter({
    required this.surface,
    required this.accent,
    required this.dark,
  });

  final Color surface;
  final Color accent;
  final bool dark;

  Path _topPath(Size size) {
    final center = size.width / 2;
    return Path()
      ..moveTo(0, 25)
      ..cubicTo(size.width * .08, 8, size.width * .13, 8, size.width * .21, 22)
      ..cubicTo(size.width * .29, 37, center - 54, 38, center - 30, 14)
      ..cubicTo(center - 13, -2, center + 13, -2, center + 30, 14)
      ..cubicTo(center + 54, 38, size.width * .71, 37, size.width * .79, 22)
      ..cubicTo(size.width * .87, 8, size.width * .92, 8, size.width, 25);
  }

  Path _shapePath(Size size) => Path()
    ..addPath(_topPath(size), Offset.zero)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shapePath(size);
    canvas.drawShadow(
      path,
      dark ? Colors.black : accent.withValues(alpha: .22),
      10,
      false,
    );
    canvas.drawPath(path, Paint()..color = surface);
    canvas.drawPath(
      _topPath(size),
      Paint()
        ..color = accent.withValues(alpha: dark ? .65 : .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _NavigationBarPainter oldDelegate) =>
      surface != oldDelegate.surface ||
      accent != oldDelegate.accent ||
      dark != oldDelegate.dark;
}
