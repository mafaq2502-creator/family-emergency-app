import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    super.key,
    required this.controller,
    required this.label,
    this.placeholder,
    this.prefixIcon,
    this.prefix,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? placeholder;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? kDarkMuted : kLightMuted;
    return TextFormField(
      autovalidateMode: AutovalidateMode.onUnfocus,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: autofillHints,
      style: TextStyle(
        color: isDark ? Colors.white : kLightText,
        fontSize: AppTypography.fieldText,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder ?? label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        constraints: const BoxConstraints(minHeight: 56),
        labelStyle: TextStyle(
          color: muted,
          fontSize: AppTypography.fieldLabel,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: kLightPrimary,
          fontSize: AppTypography.fieldLabel,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: muted.withValues(alpha: .86),
          fontSize: AppTypography.fieldHint,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon:
            prefix ??
            (prefixIcon == null
                ? null
                : Icon(prefixIcon, color: muted, size: 23)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? kDarkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF233846) : kLightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(
            color: isDark ? kEmerald : kLightPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: kEmergency),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: kEmergency, width: 1.5),
        ),
      ),
    );
  }
}
