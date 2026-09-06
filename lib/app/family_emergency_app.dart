import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_mode_controller.dart';
import '../features/auth/presentation/login_screen.dart';

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
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: kDarkCard,
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
