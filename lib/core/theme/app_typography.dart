import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  const AppTypography._();

  static const double critical = 28;
  static const double pageTitle = 24;
  static const double screenTitle = 21;
  static const double sectionTitle = 18;
  static const double cardTitle = 16;
  static const double bodyLarge = 16;
  static const double body = 15;
  static const double secondary = 14;
  static const double supporting = 13;
  static const double caption = 12;
  static const double fieldText = 16;
  static const double fieldLabel = 14;
  static const double fieldHint = 15;
  static const double button = 16;
  static const double error = 13;

  static TextTheme textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return GoogleFonts.manropeTextTheme(base).copyWith(
      displayLarge: GoogleFonts.manrope(
        fontSize: critical,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontSize: pageTitle,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: screenTitle,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: cardTitle,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: secondary,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: bodyLarge,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: body,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: secondary,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.manrope(
        fontSize: button,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: supporting,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: caption,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
