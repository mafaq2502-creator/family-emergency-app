import 'package:flutter/material.dart';

const kEmerald = Color(0xFF10B981);
const kNavy = Color(0xFF112A55);
const kEmergency = Color(0xFFEF4444);

// SafeCircle light-theme master palette.
const kLightBackground = Color(0xFFF6FFFD);
const kLightSurface = Color(0xFFFFFFFF);
const kLightSurfaceMuted = Color(0xFFECF9F5);
const kLightPrimary = Color(0xFF008F78);
const kLightAccent = Color(0xFF00D8A3);
const kLightNavy = Color(0xFF071B4A);
const kLightText = Color(0xFF183554);
const kLightMuted = Color(0xFF60798E);
const kLightBorder = Color(0xFFD7E9E5);
const kLightDangerSurface = Color(0xFFFFEFF1);
const kLightSuccessSurface = Color(0xFFE8FFF7);

const kPrimaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kLightAccent, kLightPrimary],
);
const kDarkBackground = Color(0xFF07131D);
const kDarkSurface = Color(0xFF10212D);
const kDarkCard = Color(0xFF132431);
const kDarkCardElevated = Color(0xFF182C3A);
const kDarkMuted = Color(0xFFAFC0CF);

// Semantic colors shared by the reference layouts in both appearances.
extension AppPalette on BuildContext {
  bool get isDarkAppearance => Theme.of(this).brightness == Brightness.dark;
  Color get appHeading =>
      isDarkAppearance ? const Color(0xFFF8FAFC) : kLightNavy;
  Color get appText => isDarkAppearance ? const Color(0xFFF8FAFC) : kLightText;
  Color get appMuted => isDarkAppearance ? kDarkMuted : kLightMuted;
  Color get appSurface => isDarkAppearance ? kDarkCard : kLightSurface;
  Color get appSurfaceMuted =>
      isDarkAppearance ? kDarkCardElevated : kLightSurfaceMuted;
  Color get appBorder =>
      isDarkAppearance ? const Color(0xFF233846) : kLightBorder;
  Color get appPrimary => isDarkAppearance ? kEmerald : kLightPrimary;
  Color get appSuccessSurface =>
      isDarkAppearance ? const Color(0xFF103C34) : kLightSuccessSurface;
  Color get appDangerSurface =>
      isDarkAppearance ? const Color(0xFF3B202B) : kLightDangerSurface;
}
