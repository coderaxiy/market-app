// Money is a string ("125000.00"). Never do float math on it: sum in integer tiyin.
//
// Money and whole numbers are formatted by hand, not with `NumberFormat`: locale data
// for Uzbek is inconsistent across platforms. Output matches the storefront's
// `src/lib/format.ts`: `15 000 soʻm` / `15 000 сум` / `15,000 UZS`.

const _nbsp = ' ';

/// `uz-Latn-UZ` -> `uz`. Unknown languages format like `en`.
String _language(String locale) =>
    locale.length < 2 ? 'en' : locale.substring(0, 2);

/// Whole number with locale grouping: `1 250 000` (uz, ru) or `1,250,000` (en).
String formatNumber(num value, String locale) {
  final rounded = value.round();
  final separator = _language(locale) == 'en' ? ',' : _nbsp;
  final grouped = rounded.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => separator,
  );
  return rounded < 0 ? '-$grouped' : grouped;
}

/// `"125000.00"` -> `12500000`. Parsed from the string, no floating point.
int toTiyin(String amount) {
  final negative = amount.trim().startsWith('-');
  final parts = amount.trim().replaceFirst('-', '').split('.');
  final whole = int.parse(parts[0].isEmpty ? '0' : parts[0]);
  final fraction = parts.length > 1 ? parts[1].padRight(2, '0') : '00';
  final tiyin = whole * 100 + int.parse(fraction.substring(0, 2));
  return negative ? -tiyin : tiyin;
}

/// Whole soʻm, e.g. `1 250 000 soʻm`. Tiyin are never shown.
String formatTiyin(int tiyin, String locale) {
  final amount = formatNumber(tiyin / 100, locale);
  return switch (_language(locale)) {
    'uz' => '$amount${_nbsp}soʻm',
    'ru' => '$amount$_nbspсум',
    _ => '$amount${_nbsp}UZS',
  };
}

String formatMoney(String amount, String locale) =>
    formatTiyin(toTiyin(amount), locale);

/// Client-side sum before the server confirms a total. Prefer server totals.
int sumMoney(Iterable<String> amounts) =>
    amounts.fold(0, (total, amount) => total + toTiyin(amount));
