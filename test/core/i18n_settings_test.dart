import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/core/i18n/app_translations.dart';
import 'package:market_app/core/i18n/i18n.dart';
import 'package:market_app/core/i18n/translations.dart';
import 'package:market_app/core/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container([
  Map<String, Object> stored = const {},
]) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  test('every locale has exactly the keys of en', () {
    final keys = translations['en']!.keys.toSet();
    expect(keys.length, greaterThan(250));
    for (final code in ['uz', 'ru']) {
      expect(translations[code]!.keys.toSet(), keys, reason: code);
    }
  });

  test('app-only strings: same keys in every locale, none shadowing storefront keys', () {
    final keys = appTranslations['en']!.keys.toSet();
    for (final code in ['uz', 'ru']) {
      expect(appTranslations[code]!.keys.toSet(), keys, reason: code);
    }
    expect(keys.intersection(translations['en']!.keys.toSet()), isEmpty);
    expect(translate(AppLocale.ru, 'auth.sendCode'), 'Отправить код');
    expect(
      translate(AppLocale.en, 'auth.resetCodeSubtitle', {'email': 'a@b.uz'}),
      contains('a@b.uz'),
    );
  });

  test('translate fills params and falls back to the key', () {
    expect(
      translate(AppLocale.en, 'header.searchFor', {'query': 'shoes'}),
      'Search for “shoes”',
    );
    expect(translate(AppLocale.uz, 'nope.missing'), 'nope.missing');
    expect(translate(AppLocale.en, 'header.searchFor'), contains('{query}'));
  });

  test('pickTranslation goes current -> en -> first', () {
    final entries = [
      {'locale': 'ru', 'name': 'Р'},
      {'locale': 'en', 'name': 'E'},
    ];
    String loc(Map<String, String> e) => e['locale']!;
    expect(pickTranslation(entries, loc, AppLocale.ru)!['name'], 'Р');
    expect(pickTranslation(entries, loc, AppLocale.uz)!['name'], 'E');
    expect(pickTranslation([entries.first], loc, AppLocale.uz)!['name'], 'Р');
    expect(pickTranslation(<Map<String, String>>[], loc, AppLocale.uz), isNull);
  });

  test(
    'settings default to uz + system, persist changes, ignore junk',
    () async {
      var c = await _container();
      expect(c.read(settingsProvider).locale, AppLocale.uz);
      expect(c.read(settingsProvider).themeMode, ThemeMode.system);
      await c.read(settingsProvider.notifier).setLocale(AppLocale.ru);
      await c.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);

      final prefs = c.read(sharedPreferencesProvider);
      c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      expect(c.read(settingsProvider).locale, AppLocale.ru);
      expect(c.read(settingsProvider).themeMode, ThemeMode.dark);

      c = await _container({'locale': 'xx', 'theme': 'blue'});
      expect(c.read(settingsProvider).locale, AppLocale.uz);
      expect(c.read(settingsProvider).themeMode, ThemeMode.system);
    },
  );
}
