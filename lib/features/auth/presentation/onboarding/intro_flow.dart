import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_brand_mark.dart';
import '../../../../core/widgets/app_primary_button.dart';

class IntroFlow extends StatefulWidget {
  const IntroFlow({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<IntroFlow> createState() => _IntroFlowState();
}

class _IntroFlowState extends State<IntroFlow> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == 1) {
      widget.onFinished();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (value) => setState(() => _page = value),
              children: const [
                _IntroPage(
                  icon: Icons.family_restroom_rounded,
                  title: 'Keep Your Family Close',
                  description: 'Real-time location, smart alerts and a safe place for everyone you trust.',
                  first: true,
                ),
                _IntroPage(
                  icon: Icons.home_work_rounded,
                  title: 'Safer Days, Brighter Tomorrows',
                  description: 'Be there, even when you’re not. The family journey feels safer together.',
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              2,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _page == index ? 22 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _page == index ? kEmerald : kLightBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: AppPrimaryButton(
              label: _page == 1 ? 'Get Started' : 'Continue',
              onPressed: _next,
            ),
          ),
        ],
      ),
    ),
  );
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.description,
    this.first = false,
  });
  final IconData icon;
  final String title;
  final String description;
  final bool first;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewport.maxHeight - 36),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBrandMark(size: 44, showGlow: false),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: kLightNavy,
                  fontSize: 28,
                  height: 1.06,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  color: kLightMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Center(
                child: _FamilyLandscape(icon: icon, first: first),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FamilyLandscape extends StatelessWidget {
  const _FamilyLandscape({required this.icon, required this.first});
  final IconData icon;
  final bool first;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 260,
    width: double.infinity,
    child: Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          left: -45,
          right: -45,
          bottom: -85,
          child: Container(
            height: 240,
            decoration: const BoxDecoration(
              color: Color(0xFFDDF7EF),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          left: -10,
          right: -10,
          bottom: -110,
          child: Container(
            height: 230,
            decoration: const BoxDecoration(
              color: Color(0xFFB9EBDD),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 38,
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kEmerald.withValues(alpha: .18),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Icon(icon, color: kLightPrimary, size: 72),
          ),
        ),
        Positioned(
          left: first ? 30 : null,
          right: first ? null : 28,
          bottom: 34,
          child: const Icon(Icons.park_rounded, color: kEmerald, size: 70),
        ),
      ],
    ),
  );
}

class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key, this.message = 'Keeping your family close…'});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppBrandMark(),
              const SizedBox(height: 36),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kLightMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
