import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key, this.size = 72, this.showGlow = true});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: kPrimaryGradient,
      shape: BoxShape.circle,
      boxShadow: showGlow
          ? [
              BoxShadow(
                color: kLightAccent.withValues(alpha: .24),
                blurRadius: size * .28,
                offset: Offset(0, size * .08),
              ),
            ]
          : null,
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.favorite_rounded, color: Colors.white, size: size * .55),
        Positioned(
          top: size * .16,
          left: size * .19,
          child: _PersonDot(size: size * .15),
        ),
        Positioned(
          top: size * .11,
          right: size * .19,
          child: _PersonDot(size: size * .17),
        ),
      ],
    ),
  );
}

class _PersonDot extends StatelessWidget {
  const _PersonDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
    ),
  );
}
