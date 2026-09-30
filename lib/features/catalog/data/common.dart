// Mirrors openapi/api.yaml -> TranslationRead, AttributeTranslationRead, ShopSummaryRead,
// BrandPublicRead, ShopPublicRead. Guide: sdk-contract/docs/storefront-catalog-api.md.
//
// List fields the spec marks optional (they have server defaults) are always sent, so
// they are non-null here; a missing one reads as an empty list.

/// Money is a decimal string, e.g. "120000.00". Format with `formatMoney`, never float math.
typedef Money = String;

typedef Json = Map<String, dynamic>;

List<T> readList<T>(Object? raw, T Function(Json json) fromJson) => [
  for (final item in (raw as List<dynamic>? ?? const <dynamic>[]))
    fromJson(item as Json),
];

class TranslationRead {
  const TranslationRead({
    required this.locale,
    required this.name,
    this.description,
  });

  factory TranslationRead.fromJson(Json json) => TranslationRead(
    locale: json['locale'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
  );

  final String locale;
  final String name;
  final String? description;
}

class AttributeTranslationRead {
  const AttributeTranslationRead({required this.locale, required this.label});

  factory AttributeTranslationRead.fromJson(Json json) =>
      AttributeTranslationRead(
        locale: json['locale'] as String,
        label: json['label'] as String,
      );

  final String locale;
  final String label;
}

class ShopSummaryRead {
  const ShopSummaryRead({
    required this.id,
    required this.slug,
    required this.name,
    this.logoUrl,
  });

  factory ShopSummaryRead.fromJson(Json json) => ShopSummaryRead(
    id: json['id'] as int,
    slug: json['slug'] as String,
    name: json['name'] as String,
    logoUrl: json['logo_url'] as String?,
  );

  final int id;
  final String slug;
  final String name;
  final String? logoUrl;
}

class BrandPublicRead {
  const BrandPublicRead({
    required this.id,
    required this.name,
    required this.isVerified,
    this.logoUrl,
  });

  factory BrandPublicRead.fromJson(Json json) => BrandPublicRead(
    id: json['id'] as int,
    name: json['name'] as String,
    logoUrl: json['logo_url'] as String?,
    isVerified: json['is_verified'] as bool,
  );

  final int id;
  final String name;
  final String? logoUrl;
  final bool isVerified;
}

class ShopPublicRead {
  const ShopPublicRead({
    required this.id,
    required this.slug,
    required this.name,
    required this.ratingCount,
    required this.createdAt,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.ratingAvg,
  });

  factory ShopPublicRead.fromJson(Json json) => ShopPublicRead(
    id: json['id'] as int,
    slug: json['slug'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    logoUrl: json['logo_url'] as String?,
    bannerUrl: json['banner_url'] as String?,
    ratingAvg: json['rating_avg'] as String?,
    ratingCount: json['rating_count'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final String slug;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;

  /// Decimal string; null = no ratings yet.
  final String? ratingAvg;
  final int ratingCount;
  final DateTime createdAt;
}
