import 'package:flutter/material.dart';

class RetroColors extends ThemeExtension<RetroColors> {
  final Color background;
  final Color surface;
  final Color border;
  final Color borderSubtle;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color shadowColor;
  final Color iconDefault;
  final Color iconMuted;

  const RetroColors({
    required this.background,
    required this.surface,
    required this.border,
    required this.borderSubtle,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.shadowColor,
    required this.iconDefault,
    required this.iconMuted,
  });

  static const light = RetroColors(
    background: Color(0xFFFAFAFA),
    surface: Colors.white,
    border: Colors.black,
    borderSubtle: Color(0xFFE2E8F0),
    text: Colors.black,
    textMuted: Color(0xFF475569),
    textSubtle: Color(0xFF94A3B8),
    shadowColor: Colors.black,
    iconDefault: Colors.black,
    iconMuted: Color(0x61000000), // Colors.black38
  );

  static const dark = RetroColors(
    background: Color(0xFF0F0F1A),   // deep inky black with violet tint
    surface: Color(0xFF1A1A2E),      // lifted card surface — richer navy
    border: Color(0xFF3B3B5C),       // muted slate-purple — visible but calm
    borderSubtle: Color(0xFF2A2A42), // soft purple-gray divider
    text: Color(0xFFF1F5F9),         // crisp near-white
    textMuted: Color(0xFFA5B4CF),    // cool blue-gray, warmer than before
    textSubtle: Color(0xFF6B7A94),   // dimmed but still readable
    shadowColor: Color(0xFF000000),  // true black shadow for bold retro offset
    iconDefault: Color(0xFFE2E8F0),  // bright icons
    iconMuted: Color(0xFF7C8DB5),    // visible muted icons, not washed out
  );

  static RetroColors of(BuildContext context) {
    return Theme.of(context).extension<RetroColors>()!;
  }

  @override
  RetroColors copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? borderSubtle,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? shadowColor,
    Color? iconDefault,
    Color? iconMuted,
  }) {
    return RetroColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      shadowColor: shadowColor ?? this.shadowColor,
      iconDefault: iconDefault ?? this.iconDefault,
      iconMuted: iconMuted ?? this.iconMuted,
    );
  }

  @override
  RetroColors lerp(RetroColors? other, double t) {
    if (other is! RetroColors) return this;
    return RetroColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      iconDefault: Color.lerp(iconDefault, other.iconDefault, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
    );
  }
}
