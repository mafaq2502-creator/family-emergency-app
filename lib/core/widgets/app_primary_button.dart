import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color = kEmerald,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;
    final usePrimaryGradient = color == kEmerald || color == kLightPrimary;
    return AnimatedOpacity(
      opacity: enabled || isLoading ? 1 : .55,
      duration: const Duration(milliseconds: 160),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: usePrimaryGradient ? null : color,
          gradient: usePrimaryGradient ? kPrimaryGradient : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: .2),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
