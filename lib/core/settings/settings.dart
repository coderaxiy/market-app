import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/i18n.dart';

const _localeKey = 'locale';
const _themeKey = 'theme';

/// Overridden in `main()` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

@immutable
class Settings {
  const Settings({required this.locale, required this.themeMode});

  final AppLocale locale;

  /// `light | dark | system`, like the storefront's theme cookie.
  final ThemeMode themeMode;
}

/// App-wide locale and theme, persisted. A bad or missing stored value falls back to
/// the default (`uz`, `system`).
class SettingsController extends Notifier<Settings> {
  @override
  Settings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return Settings(
      locale: AppLocale.fromCode(prefs.getString(_localeKey)) ?? defaultLocale,
      themeMode:
          ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
          ThemeMode.system,
    );
  }

  Future<void> setLocale(AppLocale locale) async {
    state = Settings(locale: locale, themeMode: state.themeMode);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_localeKey, locale.code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = Settings(locale: state.locale, themeMode: mode);
    await ref.read(sharedPreferencesProvider).setString(_themeKey, mode.name);
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

/// `ref.watch(tProvider)('cart.title')`. Rebuilds when the locale changes.
final tProvider = Provider<TFunction>(
  (ref) => createT(ref.watch(settingsProvider.select((s) => s.locale))),
);
