import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material theme built only from `AppColors` tokens. See emarket `DESIGN.md`.
///
/// Elevation order in both themes: background < muted < card/popover. `primary` is for
/// commerce actions only; `accent` for links, selection and focus.
abstract final class AppTheme {
  static const radius = 16.0;
  static const bodyFont = 'Onest';

  /// Hero, section and page titles only.
  static const displayFont = 'Unbounded';

  static ThemeData get light => _build(AppColors.light, Brightness.light);
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.primaryForeground,
      secondary: c.secondary,
      onSecondary: c.secondaryForeground,
      tertiary: c.accent,
      onTertiary: c.accentForeground,
      error: c.destructive,
      onError: c.destructiveForeground,
      surface: c.background,
      onSurface: c.foreground,
      surfaceContainerHighest: c.muted,
      onSurfaceVariant: c.mutedForeground,
      outline: c.input,
      outlineVariant: c.border,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: bodyFont,
      scaffoldBackgroundColor: c.background,
      dividerColor: c.border,
      extensions: [c],
    );
    final text = base.textTheme.apply(
      bodyColor: c.foreground,
      displayColor: c.foreground,
    );
    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(fontFamily: displayFont),
        displayMedium: text.displayMedium?.copyWith(fontFamily: displayFont),
        displaySmall: text.displaySmall?.copyWith(fontFamily: displayFont),
        headlineMedium: text.headlineMedium?.copyWith(fontFamily: displayFont),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shape.copyWith(side: BorderSide(color: c.border)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.popover,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.popover,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.primaryForeground,
          shape: shape,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.foreground,
          side: BorderSide(color: c.input),
          shape: shape,
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent, shape: shape),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.input),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.input),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c.ring, width: 2),
        ),
        hintStyle: TextStyle(color: c.mutedForeground),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.secondary,
        selectedColor: c.accent,
        labelStyle: TextStyle(color: c.secondaryForeground),
        secondaryLabelStyle: TextStyle(color: c.accentForeground),
        side: BorderSide(color: c.border),
        shape: shape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.foreground,
        contentTextStyle: TextStyle(color: c.background),
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1),
    );
  }
}
