import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({super.key, required this.label, required this.onPressed, this.isLoading = false, this.color = kEmerald});

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: isLoading ? null : onPressed, style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(label, style: const TextStyle(fontWeight: FontWeight.w800))));
}
