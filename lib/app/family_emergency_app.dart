import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_mode_controller.dart';
import '../features/auth/presentation/login_screen.dart';

ButtonStyle _interactiveButtonStyle(Brightness brightness) => ButtonStyle(
      animationDuration: const Duration(milliseconds: 160),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return kEmerald.withValues(alpha: .20);
        if (states.contains(WidgetState.hovered)) return kEmerald.withValues(alpha: brightness == Brightness.dark ? .16 : .10);
        if (states.contains(WidgetState.focused)) return kEmerald.withValues(alpha: .14);
        return null;
      }),
    );

class FamilyEmergencyApp extends StatelessWidget {
  const FamilyEmergencyApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: appThemeMode,
        builder: (context, themeMode, _) => MaterialApp(
          title: 'Family Emergency',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: kEmerald,
            textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme),
            primaryTextTheme: GoogleFonts.manropeTextTheme(ThemeData.light().primaryTextTheme),
            colorScheme: ColorScheme.fromSeed(seedColor: kEmerald, brightness: Brightness.light),
            scaffoldBackgroundColor: const Color(0xFFF8FBFA),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: kNavy, elevation: 0),
            hoverColor: kEmerald.withValues(alpha: .08),
            focusColor: kEmerald.withValues(alpha: .12),
            splashColor: kEmerald.withValues(alpha: .16),
            elevatedButtonTheme: ElevatedButtonThemeData(style: _interactiveButtonStyle(Brightness.light)),
            outlinedButtonTheme: OutlinedButtonThemeData(style: _interactiveButtonStyle(Brightness.light)),
            textButtonTheme: TextButtonThemeData(style: _interactiveButtonStyle(Brightness.light)),
            iconButtonTheme: IconButtonThemeData(style: _interactiveButtonStyle(Brightness.light)),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              focusColor: kEmerald.withValues(alpha: .06),
              hoverColor: kEmerald.withValues(alpha: .05),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kEmerald, width: 1.5)),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: kEmerald,
            textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
            primaryTextTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().primaryTextTheme),
            colorScheme: ColorScheme.fromSeed(seedColor: kEmerald, brightness: Brightness.dark, surface: kDarkCard),
            scaffoldBackgroundColor: kDarkBackground,
            appBarTheme: const AppBarTheme(backgroundColor: kDarkSurface, foregroundColor: Colors.white, elevation: 0),
            cardColor: kDarkCard,
            dividerColor: const Color(0xFF233846),
            hoverColor: kEmerald.withValues(alpha: .14),
            focusColor: kEmerald.withValues(alpha: .18),
            splashColor: kEmerald.withValues(alpha: .20),
            elevatedButtonTheme: ElevatedButtonThemeData(style: _interactiveButtonStyle(Brightness.dark)),
            outlinedButtonTheme: OutlinedButtonThemeData(style: _interactiveButtonStyle(Brightness.dark)),
            textButtonTheme: TextButtonThemeData(style: _interactiveButtonStyle(Brightness.dark)),
            iconButtonTheme: IconButtonThemeData(style: _interactiveButtonStyle(Brightness.dark)),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: kDarkCard,
              focusColor: kEmerald.withValues(alpha: .12),
              hoverColor: kEmerald.withValues(alpha: .10),
              hintStyle: const TextStyle(color: kDarkMuted),
              labelStyle: const TextStyle(color: kDarkMuted),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF233846))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kEmerald)),
            ),
          ),
          home: const LoginScreen(),
        ),
      );
}
