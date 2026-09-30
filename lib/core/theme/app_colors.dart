// Generated from emarket `src/styles/global.css` (oklch -> sRGB). Tokens only: widgets read
// colours from `AppColors.of(context)`, never raw values.

import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.foreground,
    required this.muted,
    required this.mutedForeground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.accent,
    required this.accentForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.success,
    required this.successForeground,
    required this.warning,
    required this.warningForeground,
    required this.sale,
    required this.saleForeground,
    required this.border,
    required this.input,
    required this.ring,
  });

  final Color background;
  final Color foreground;
  final Color muted;
  final Color mutedForeground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color accent;
  final Color accentForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color success;
  final Color successForeground;
  final Color warning;
  final Color warningForeground;
  final Color sale;
  final Color saleForeground;
  final Color border;
  final Color input;
  final Color ring;

  static const light = AppColors(
    background: Color(0xFFFCFAF6),
    foreground: Color(0xFF221812),
    muted: Color(0xFFF3F0E9),
    mutedForeground: Color(0xFF61554E),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF221812),
    popover: Color(0xFFFFFFFF),
    popoverForeground: Color(0xFF221812),
    primary: Color(0xFFD24100),
    primaryForeground: Color(0xFFFCFCFC),
    accent: Color(0xFF00747A),
    accentForeground: Color(0xFFFCFCFC),
    secondary: Color(0xFFEDE7DD),
    secondaryForeground: Color(0xFF221812),
    destructive: Color(0xFFD01C29),
    destructiveForeground: Color(0xFFFCFCFC),
    success: Color(0xFF1D7D3E),
    successForeground: Color(0xFFFCFCFC),
    warning: Color(0xFFB07100),
    warningForeground: Color(0xFF1F1306),
    sale: Color(0xFFBF2A82),
    saleForeground: Color(0xFFFCFCFC),
    border: Color(0xFFE2DDD5),
    input: Color(0xFFD6D0C7),
    ring: Color(0xFF00747A),
  );

  static const dark = AppColors(
    background: Color(0xFF110C09),
    foreground: Color(0xFFF1EEE7),
    muted: Color(0xFF1A1511),
    mutedForeground: Color(0xFFB0AAA0),
    card: Color(0xFF241E1A),
    cardForeground: Color(0xFFF1EEE7),
    popover: Color(0xFF29231E),
    popoverForeground: Color(0xFFF1EEE7),
    primary: Color(0xFFF3813F),
    primaryForeground: Color(0xFF190F0A),
    accent: Color(0xFF4FBEC4),
    accentForeground: Color(0xFF061415),
    secondary: Color(0xFF312A24),
    secondaryForeground: Color(0xFFF1EEE7),
    destructive: Color(0xFFFA6863),
    destructiveForeground: Color(0xFF1A0E0D),
    success: Color(0xFF62C37A),
    successForeground: Color(0xFF07150A),
    warning: Color(0xFFEDB345),
    warningForeground: Color(0xFF1F1306),
    sale: Color(0xFFF072B3),
    saleForeground: Color(0xFF1B0C13),
    border: Color(0xFF38322D),
    input: Color(0xFF423C37),
    ring: Color(0xFF4FBEC4),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
      popover: Color.lerp(popover, other.popover, t)!,
      popoverForeground: Color.lerp(
        popoverForeground,
        other.popoverForeground,
        t,
      )!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentForeground: Color.lerp(
        accentForeground,
        other.accentForeground,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground: Color.lerp(
        secondaryForeground,
        other.secondaryForeground,
        t,
      )!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      destructiveForeground: Color.lerp(
        destructiveForeground,
        other.destructiveForeground,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      successForeground: Color.lerp(
        successForeground,
        other.successForeground,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningForeground: Color.lerp(
        warningForeground,
        other.warningForeground,
        t,
      )!,
      sale: Color.lerp(sale, other.sale, t)!,
      saleForeground: Color.lerp(saleForeground, other.saleForeground, t)!,
      border: Color.lerp(border, other.border, t)!,
      input: Color.lerp(input, other.input, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
    );
  }
}
