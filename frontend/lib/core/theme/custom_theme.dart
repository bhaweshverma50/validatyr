import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RetroTheme {
  // Vibrant, flat retro pastel colors
  static const Color pink = Color(0xFFFF9CEE);
  static const Color mint = Color(0xFFA1F1B6);
  static const Color lavender = Color(0xFFC4B5FD);
  static const Color yellow = Color(0xFFFDE047);
  static const Color blue = Color(0xFF93C5FD);
  static const Color orange = Color(0xFFFDBA74);
  static const Color background = Color(0xFFFAFAFA);
  static const Color text = Colors.black;
  static const Color textMuted = Color(0xFF475569);

  // The distinctive bold border used everywhere
  static final Border thickerBorder = Border.all(color: Colors.black, width: 3.0);

  // Sharp, massive cast shadows instead of blurry drop shadows
  static const List<BoxShadow> sharpShadow = [
    BoxShadow(
      color: Colors.black,
      offset: Offset(4, 4),
      blurRadius: 0,
      spreadRadius: 0,
    )
  ];

  // Score color based on value
  static Color scoreColor(double score) {
    if (score >= 75) return mint;
    if (score >= 50) return yellow;
    if (score >= 25) return orange;
    return pink;
  }

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopMaxWidth = 720.0;

  static ThemeData get themeData {
    final headingTextTheme = GoogleFonts.outfitTextTheme();
    final bodyTextTheme = GoogleFonts.spaceGroteskTextTheme();

    return ThemeData(
      scaffoldBackgroundColor: background,
      primaryColor: pink,
      textTheme: bodyTextTheme.copyWith(
        displayLarge: headingTextTheme.displayLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.0,
        ),
        headlineMedium: headingTextTheme.headlineMedium?.copyWith(
          color: text,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        titleLarge: headingTextTheme.titleLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: bodyTextTheme.titleMedium?.copyWith(
          color: textMuted,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: bodyTextTheme.bodyLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w500,
          height: 1.6,
        ),
        bodyMedium: bodyTextTheme.bodyMedium?.copyWith(
          color: text,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: headingTextTheme.labelLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.black,
        contentTextStyle: bodyTextTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: text,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: const BorderSide(color: Colors.black, width: 3.0),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.black, width: 3.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.black, width: 3.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.black, width: 4.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
        hintStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black38),
      ),
    );
  }
}
