import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppPageBackground extends StatelessWidget {
  const AppPageBackground({
    super.key,
    required this.child,
    this.showTopDecoration = true,
    this.showBottomDecoration = true,
  });

  final Widget child;
  final bool showTopDecoration;
  final bool showBottomDecoration;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return ColoredBox(color: kDarkBackground, child: child);
    }
    return ColoredBox(
      color: kLightBackground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showTopDecoration) ...[
            const Positioned(
              top: -58,
              right: -54,
              child: _SoftOrb(size: 160, color: Color(0x1F70E8D0)),
            ),
            const Positioned(
              top: 70,
              left: -60,
              child: _SoftOrb(size: 130, color: Color(0x1470E8D0)),
            ),
          ],
          if (showBottomDecoration)
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _HillPainter())),
            ),
          child,
        ],
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _HillPainter extends CustomPainter {
  const _HillPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rear = Paint()..color = const Color(0x237DE3D0);
    final front = Paint()..color = const Color(0x2E3CC9AF);
    final rearPath = Path()
      ..moveTo(0, size.height * .88)
      ..quadraticBezierTo(
        size.width * .30,
        size.height * .81,
        size.width * .55,
        size.height * .89,
      )
      ..quadraticBezierTo(
        size.width * .80,
        size.height * .96,
        size.width,
        size.height * .84,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final frontPath = Path()
      ..moveTo(0, size.height * .95)
      ..quadraticBezierTo(
        size.width * .28,
        size.height * .88,
        size.width * .57,
        size.height * .96,
      )
      ..quadraticBezierTo(
        size.width * .79,
        size.height,
        size.width,
        size.height * .92,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(rearPath, rear);
    canvas.drawPath(frontPath, front);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
