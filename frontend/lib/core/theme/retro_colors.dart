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
    background: Color(0xFF1A1A2E),
    surface: Color(0xFF16213E),
    border: Color(0xFF4A5568), // muted slate — visible but not harsh on dark
    borderSubtle: Color(0xFF2D3748),
    text: Color(0xFFF8FAFC),
    textMuted: Color(0xFF94A3B8),
    textSubtle: Color(0xFF64748B),
    shadowColor: Color(0xFF0D0D1A), // near-black offset shadow for depth
    iconDefault: Color(0xFFF8FAFC),
    iconMuted: Color(0xFF94A3B8),
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
