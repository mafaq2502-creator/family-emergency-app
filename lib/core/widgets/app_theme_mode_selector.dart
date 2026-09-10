import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppThemeModeSelector extends StatelessWidget {
  const AppThemeModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static const _choices = [
    (ThemeMode.system, 'System', Icons.brightness_auto_rounded),
    (ThemeMode.light, 'Light', Icons.light_mode_rounded),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabledText = isDark ? Colors.white : kLightNavy;
    final mutedText = isDark ? kDarkMuted : kLightMuted;
    return Material(
      color: isDark ? kDarkCard : kLightSurface,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF233846) : kLightBorder,
          ),
        ),
        child: Row(
          children: _choices.map((choice) {
            final selected = mode == choice.$1;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: '${choice.$2} theme',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onChanged(choice.$1),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected ? kPrimaryGradient : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          choice.$3,
                          size: 19,
                          color: selected ? Colors.white : mutedText,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          choice.$2,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : enabledText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
