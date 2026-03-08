import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'retro_colors.dart';

export 'retro_colors.dart';

class RetroTheme {
  // ── Accent Colors (same in both themes) ─────────────────────
  static const Color pink = Color(0xFFFF9CEE);
  static const Color mint = Color(0xFFA1F1B6);
  static const Color lavender = Color(0xFFC4B5FD);
  static const Color yellow = Color(0xFFFDE047);
  static const Color blue = Color(0xFF93C5FD);
  static const Color orange = Color(0xFFFDBA74);

  // ── Legacy static colors (for non-widget code that can't access context) ──
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color text = Colors.black;
  static const Color textMuted = Color(0xFF475569);
  static const Color textSubtle = Color(0xFF94A3B8);
  static const Color border = Colors.black;
  static const Color borderSubtle = Color(0xFFE2E8F0);

  // ── Border Tokens ─────────────────────────────────────────────
  static const double borderWidthThick = 3.0;
  static const double borderWidthMedium = 2.0;
  static const double borderWidthThin = 1.5;

  // Legacy static borders (light-only, prefer borderOf/mediumBorderOf)
  static final Border thickerBorder = Border.all(color: border, width: borderWidthThick);
  static final Border mediumBorder = Border.all(color: border, width: borderWidthMedium);

  // ── Radius Tokens ─────────────────────────────────────────────
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;

  // ── Shadow Tokens ─────────────────────────────────────────────
  // Legacy static shadows (light-only, prefer shadowOf/shadowSmOf)
  static const List<BoxShadow> sharpShadow = [
    BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0, spreadRadius: 0),
  ];
  static const List<BoxShadow> sharpShadowSm = [
    BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0, spreadRadius: 0),
  ];

  // ── Spacing Tokens ────────────────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ── Responsive Breakpoints ────────────────────────────────────
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopMaxWidth = 720.0;
  static const double contentPaddingMobile = 20.0;
  static const double contentPaddingDesktop = 48.0;

  // ── Typography Sizes ──────────────────────────────────────────
  static const double fontXs = 10.0;
  static const double fontSm = 12.0;
  static const double fontMd = 14.0;
  static const double fontLg = 16.0;
  static const double fontXl = 18.0;
  static const double fontDisplay = 22.0;

  // ── Common Text Styles ────────────────────────────────────────
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'Outfit',
    fontWeight: FontWeight.w800,
    fontSize: fontMd,
    letterSpacing: 1.0,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: fontXs,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
  );

  static const TextStyle badgeStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Colors.black, // always black — badges sit on accent backgrounds
  );

  // ── Score Color ───────────────────────────────────────────────
  static Color scoreColor(double score) {
    if (score >= 75) return mint;
    if (score >= 50) return yellow;
    if (score >= 25) return orange;
    return pink;
  }

  // ── Theme-Aware Helpers ─────────────────────────────────────
  static Border borderOf(BuildContext context) {
    final c = RetroColors.of(context);
    return Border.all(color: c.border, width: borderWidthThick);
  }

  static Border mediumBorderOf(BuildContext context) {
    final c = RetroColors.of(context);
    return Border.all(color: c.border, width: borderWidthMedium);
  }

  static List<BoxShadow> shadowOf(BuildContext context) {
    final c = RetroColors.of(context);
    return [BoxShadow(color: c.shadowColor, offset: const Offset(4, 4))];
  }

  static List<BoxShadow> shadowSmOf(BuildContext context) {
    final c = RetroColors.of(context);
    return [BoxShadow(color: c.shadowColor, offset: const Offset(2, 2))];
  }

  // ── Common Decorations ────────────────────────────────────────
  static BoxDecoration badgeDecoration(Color color, {Color borderColor = Colors.black}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radiusSm),
        border: Border.all(color: borderColor, width: borderWidthThin),
      );

  static BoxDecoration chipDecorationOf(
    BuildContext context, {
    bool selected = false,
    Color? color,
  }) {
    final c = RetroColors.of(context);
    return BoxDecoration(
      color: selected ? (color ?? yellow) : c.surface,
      borderRadius: BorderRadius.circular(radiusMd),
      border: Border.all(
        color: selected ? c.border : c.borderSubtle,
        width: selected ? borderWidthMedium : borderWidthThin,
      ),
      boxShadow: selected ? shadowSmOf(context) : null,
    );
  }

  /// Legacy non-context version — prefer chipDecorationOf
  static BoxDecoration chipDecoration({bool selected = false, Color? color}) => BoxDecoration(
    color: selected ? (color ?? yellow) : surface,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(
      color: selected ? border : Colors.black38,
      width: selected ? borderWidthMedium : borderWidthThin,
    ),
    boxShadow: selected ? sharpShadowSm : null,
  );

  // ── Light Theme ─────────────────────────────────────────────
  static ThemeData get themeData => _buildTheme(Brightness.light, RetroColors.light);

  // ── Dark Theme ──────────────────────────────────────────────
  static ThemeData get darkThemeData => _buildTheme(Brightness.dark, RetroColors.dark);

  static ThemeData _buildTheme(Brightness brightness, RetroColors colors) {
    final headingTextTheme = GoogleFonts.outfitTextTheme();
    final bodyTextTheme = GoogleFonts.spaceGroteskTextTheme();

    return ThemeData(
      brightness: brightness,
      extensions: [colors],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: pink,
        secondary: mint,
        surface: colors.surface,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: colors.text,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: colors.background,
      primaryColor: pink,
      textTheme: bodyTextTheme.copyWith(
        displayLarge: headingTextTheme.displayLarge?.copyWith(
          color: colors.text, fontWeight: FontWeight.w900, letterSpacing: -1.0,
        ),
        headlineMedium: headingTextTheme.headlineMedium?.copyWith(
          color: colors.text, fontWeight: FontWeight.w900, letterSpacing: 0.5,
        ),
        titleLarge: headingTextTheme.titleLarge?.copyWith(
          color: colors.text, fontWeight: FontWeight.bold,
        ),
        titleMedium: bodyTextTheme.titleMedium?.copyWith(
          color: colors.textMuted, fontWeight: FontWeight.w600,
        ),
        bodyLarge: bodyTextTheme.bodyLarge?.copyWith(
          color: colors.text, fontWeight: FontWeight.w500, height: 1.6,
        ),
        bodyMedium: bodyTextTheme.bodyMedium?.copyWith(
          color: colors.text, fontWeight: FontWeight.w500,
        ),
        labelLarge: headingTextTheme.labelLarge?.copyWith(
          color: colors.text, fontWeight: FontWeight.w800, letterSpacing: 1.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.dark ? colors.surface : Colors.black,
        contentTextStyle: bodyTextTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.dark ? colors.text : Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: colors.border, width: 2),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        centerTitle: false,
        titleSpacing: contentPaddingMobile,
        iconTheme: IconThemeData(color: colors.iconDefault, size: 24),
        actionsIconTheme: IconThemeData(color: colors.iconDefault, size: 24),
        titleTextStyle: TextStyle(
          color: colors.text,
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w900,
          fontSize: fontDisplay,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            side: BorderSide(color: colors.border, width: 3.0),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: colors.border, width: 3.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: colors.border, width: 3.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: colors.border, width: 4.0),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        labelStyle: TextStyle(fontWeight: FontWeight.bold, color: colors.textMuted),
        hintStyle: TextStyle(fontWeight: FontWeight.bold, color: colors.textSubtle),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border, width: 3),
        ),
      ),
    );
  }
}
