import 'app_translations.dart';
import 'translations.dart';

enum AppLocale {
  uz('uz', 'Oʻzbekcha', 'uz-Latn-UZ'),
  ru('ru', 'Русский', 'ru-RU'),
  en('en', 'English', 'en-US');

  const AppLocale(this.code, this.nativeName, this.intlTag);

  final String code;

  /// Shown in the language switcher, never translated. Uzbek is Latin script.
  final String nativeName;

  /// BCP 47 tag for number and date formatting (`format.dart` takes this).
  final String intlTag;

  static AppLocale? fromCode(String? code) {
    for (final locale in values) {
      if (locale.code == code) return locale;
    }
    return null;
  }
}

/// Decided by the owner for the storefront; the app follows it.
const defaultLocale = AppLocale.uz;

typedef TFunction = String Function(String key, [Map<String, Object>? params]);

/// `translate(AppLocale.en, 'header.searchFor', {'query': 'shoes'})`.
/// An unknown key returns the key itself, so a gap is visible rather than a crash.
String translate(AppLocale locale, String key, [Map<String, Object>? params]) {
  final template =
      translations[locale.code]?[key] ??
      appTranslations[locale.code]?[key] ??
      key;
  if (params == null) return template;
  return template.replaceAllMapped(
    RegExp(r'\{(\w+)\}'),
    (match) => params[match[1]]?.toString() ?? match[0]!,
  );
}

/// Bind `translate` to a locale.
TFunction createT(AppLocale locale) =>
    (key, [params]) => translate(locale, key, params);

/// Pick a localized entry from API `translations: [{ locale, name }]`
/// (current -> en -> first), like the storefront's `pickTranslation`.
T? pickTranslation<T>(
  List<T> entries,
  String Function(T entry) localeOf,
  AppLocale locale,
) {
  for (final code in [locale.code, AppLocale.en.code]) {
    for (final entry in entries) {
      if (localeOf(entry) == code) return entry;
    }
  }
  return entries.isEmpty ? null : entries.first;
}
