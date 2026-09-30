import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/core/theme/app_colors.dart';
import 'package:market_app/core/theme/app_theme.dart';

void main() {
  test('both themes carry the token extension', () {
    expect(AppTheme.light.extension<AppColors>(), AppColors.light);
    expect(AppTheme.dark.extension<AppColors>(), AppColors.dark);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  test('raised surfaces are lighter than the background in dark mode', () {
    double l(Color c) => c.computeLuminance();
    const d = AppColors.dark;
    expect(l(d.muted), greaterThan(l(d.background)));
    expect(l(d.card), greaterThan(l(d.muted)));
  });

  test('commerce and accent colours differ per theme', () {
    expect(AppColors.light.primary, isNot(AppColors.dark.primary));
    expect(AppColors.light.ring, AppColors.light.accent);
  });
}
