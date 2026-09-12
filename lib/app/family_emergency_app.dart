import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/theme_mode_controller.dart';
import '../core/widgets/app_page_background.dart';
import '../features/auth/presentation/auth_gate.dart';

ButtonStyle _interactiveButtonStyle(Brightness brightness) => ButtonStyle(
  animationDuration: const Duration(milliseconds: 160),
  overlayColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return kEmerald.withValues(alpha: .20);
    }
    if (states.contains(WidgetState.hovered)) {
      return kEmerald.withValues(
        alpha: brightness == Brightness.dark ? .16 : .10,
      );
    }
    if (states.contains(WidgetState.focused)) {
      return kEmerald.withValues(alpha: .14);
    }
    return null;
  }),
);

class FamilyEmergencyApp extends StatelessWidget {
  const FamilyEmergencyApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appThemeMode,
    builder: (context, themeMode, _) => MaterialApp(
      title: 'Family Emergency',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        primaryColor: kLightPrimary,
        textTheme: AppTypography.textTheme(Brightness.light)
            .apply(bodyColor: kLightText, displayColor: kLightNavy),
        primaryTextTheme: GoogleFonts.manropeTextTheme(
          ThemeData.light().primaryTextTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: kLightPrimary,
          brightness: Brightness.light,
          primary: kLightPrimary,
          secondary: kLightAccent,
          surface: kLightSurface,
          error: kEmergency,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: kLightNavy,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.manrope(
            color: kLightNavy,
            fontSize: AppTypography.screenTitle,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: kLightSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: kLightBorder),
          ),
        ),
        dividerColor: kLightBorder,
        hoverColor: kLightAccent.withValues(alpha: .08),
        focusColor: kLightAccent.withValues(alpha: .12),
        splashColor: kLightAccent.withValues(alpha: .16),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: _interactiveButtonStyle(Brightness.light).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(52, 54)),
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? const Color(0xFFBBDDD5)
                  : kLightPrimary,
            ),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            textStyle: WidgetStatePropertyAll(
              GoogleFonts.manrope(
                fontSize: AppTypography.button,
                fontWeight: FontWeight.w600,
              ),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: _interactiveButtonStyle(Brightness.light).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(50, 50)),
            foregroundColor: const WidgetStatePropertyAll(kLightPrimary),
            side: const WidgetStatePropertyAll(BorderSide(color: kLightBorder)),
            textStyle: WidgetStatePropertyAll(
              GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: _interactiveButtonStyle(Brightness.light).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            textStyle: WidgetStatePropertyAll(
              GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: _interactiveButtonStyle(Brightness.light),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 80,
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: kLightAccent,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFF789088),
              size: AppTypography.tabIcon,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => GoogleFonts.manrope(
              color: states.contains(WidgetState.selected)
                  ? kLightPrimary
                  : kLightMuted,
              fontSize: AppTypography.tabLabel,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: kLightPrimary,
          unselectedLabelColor: kLightMuted,
          labelStyle: GoogleFonts.manrope(
            fontSize: AppTypography.tabLabel,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: AppTypography.tabLabel,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: kLightPrimary,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: kLightPrimary,
          unselectedItemColor: Color(0xFF789088),
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: GoogleFonts.manrope(
            color: kLightNavy,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: GoogleFonts.manrope(
            color: kLightText,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          focusColor: kLightAccent.withValues(alpha: .06),
          hoverColor: kLightAccent.withValues(alpha: .05),
          labelStyle: const TextStyle(
            color: kLightMuted,
            fontSize: AppTypography.fieldLabel,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: const TextStyle(
            color: kLightMuted,
            fontSize: AppTypography.fieldHint,
            fontWeight: FontWeight.w400,
          ),
          errorStyle: const TextStyle(
            fontSize: AppTypography.error,
            fontWeight: FontWeight.w400,
          ),
          prefixIconColor: kLightMuted,
          suffixIconColor: kLightMuted,
          floatingLabelStyle: const TextStyle(
            color: kLightPrimary,
            fontWeight: FontWeight.w700,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kLightBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kLightPrimary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kEmergency),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kEmergency, width: 1.5),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        primaryColor: kEmerald,
        textTheme: AppTypography.textTheme(Brightness.dark).apply(
          bodyColor: const Color(0xFFF8FAFC),
          displayColor: const Color(0xFFF8FAFC),
        ),
        primaryTextTheme: GoogleFonts.manropeTextTheme(
          ThemeData.dark().primaryTextTheme,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: kEmerald,
          brightness: Brightness.dark,
          primary: kEmerald,
          onPrimary: Colors.white,
          secondary: kLightAccent,
          surface: kDarkCard,
          onSurface: const Color(0xFFF8FAFC),
          onSurfaceVariant: kDarkMuted,
          outline: const Color(0xFF233846),
          error: kEmergency,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.manrope(
            fontSize: AppTypography.screenTitle,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardColor: kDarkCard,
        cardTheme: CardThemeData(
          color: kDarkCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF233846)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: kDarkCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          contentTextStyle: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: kDarkCard,
          surfaceTintColor: Colors.transparent,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: kDarkCard,
          surfaceTintColor: Colors.transparent,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: kDarkCardElevated,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        dividerColor: const Color(0xFF233846),
        hoverColor: kEmerald.withValues(alpha: .14),
        focusColor: kEmerald.withValues(alpha: .18),
        splashColor: kEmerald.withValues(alpha: .20),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: _interactiveButtonStyle(Brightness.dark).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(52, 54)),
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? kDarkCardElevated
                  : kLightPrimary,
            ),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? kDarkMuted
                  : Colors.white,
            ),
            textStyle: WidgetStatePropertyAll(
              GoogleFonts.manrope(
                fontSize: AppTypography.button,
                fontWeight: FontWeight.w600,
              ),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: _interactiveButtonStyle(Brightness.dark).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(50, 50)),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) =>
                  states.contains(WidgetState.disabled) ? kDarkMuted : kEmerald,
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xFF233846)),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: _interactiveButtonStyle(Brightness.dark).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            textStyle: WidgetStatePropertyAll(
              GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: _interactiveButtonStyle(Brightness.dark),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: kEmerald,
          unselectedLabelColor: kDarkMuted,
          labelStyle: GoogleFonts.manrope(
            fontSize: AppTypography.tabLabel,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: AppTypography.tabLabel,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: kEmerald,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kDarkCard,
          focusColor: kEmerald.withValues(alpha: .12),
          hoverColor: kEmerald.withValues(alpha: .10),
          hintStyle: const TextStyle(
            color: kDarkMuted,
            fontSize: AppTypography.fieldHint,
            fontWeight: FontWeight.w400,
          ),
          labelStyle: const TextStyle(
            color: kDarkMuted,
            fontSize: AppTypography.fieldLabel,
            fontWeight: FontWeight.w500,
          ),
          errorStyle: const TextStyle(
            fontSize: AppTypography.error,
            fontWeight: FontWeight.w400,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          floatingLabelStyle: const TextStyle(
            color: kEmerald,
            fontWeight: FontWeight.w700,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF233846)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kEmerald),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kEmergency),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kEmergency, width: 1.5),
          ),
        ),
      ),
      builder: (context, child) =>
          AppPageBackground(child: child ?? const SizedBox.shrink()),
      home: home ?? const AuthGate(),
    ),
  );
}
