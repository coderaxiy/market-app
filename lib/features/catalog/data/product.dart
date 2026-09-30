// Mirrors openapi/api.yaml -> ProductCardRead, ProductPublicRead (+ its nested Product*Read),
// CatalogFacetsRead, BrandFacetRead, PriceRangeRead, CatalogSort.
// Guide: sdk-contract/docs/storefront-catalog-api.md §2, §3.

import 'category.dart';
import 'common.dart';

enum CatalogSort {
  relevance,
  newest,
  priceAsc('price_asc'),
  priceDesc('price_desc');

  const CatalogSort([String? wire]) : _wire = wire;

  final String? _wire;

  String get wire => _wire ?? name;
}

class ProductCardRead {
  const ProductCardRead({
    required this.id,
    required this.slug,
    required this.title,
    required this.priceMin,
    required this.priceMax,
    required this.inStock,
    required this.hasVariants,
    required this.shop,
    required this.categoryId,
    required this.createdAt,
    this.imageUrl,
    this.brand,
  });

  factory ProductCardRead.fromJson(Json json) => ProductCardRead(
    id: json['id'] as int,
    slug: json['slug'] as String,
    title: json['title'] as String,
    priceMin: json['price_min'] as String,
    priceMax: json['price_max'] as String,
    inStock: json['in_stock'] as bool,
    hasVariants: json['has_variants'] as bool,
    imageUrl: json['image_url'] as String?,
    shop: ShopSummaryRead.fromJson(json['shop'] as Json),
    brand: json['brand'] == null
        ? null
        : BrandPublicRead.fromJson(json['brand'] as Json),
    categoryId: json['category_id'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final String slug;
  final String title;
  final Money priceMin;
  final Money priceMax;
  final bool inStock;
  final bool hasVariants;

  /// Primary image, else the lowest sort order.
  final String? imageUrl;
  final ShopSummaryRead shop;
  final BrandPublicRead? brand;
  final int categoryId;
  final DateTime createdAt;
}

class CategoryAncestorRead {
  const CategoryAncestorRead({
    required this.id,
    required this.slug,
    required this.translations,
  });

  factory CategoryAncestorRead.fromJson(Json json) => CategoryAncestorRead(
    id: json['id'] as int,
    slug: json['slug'] as String,
    translations: readList(json['translations'], TranslationRead.fromJson),
  );

  final int id;
  final String slug;
  final List<TranslationRead> translations;
}

class ProductCategoryRead {
  const ProductCategoryRead({
    required this.id,
    required this.slug,
    required this.translations,
    required this.ancestors,
  });

  factory ProductCategoryRead.fromJson(Json json) => ProductCategoryRead(
    id: json['id'] as int,
    slug: json['slug'] as String,
    translations: readList(json['translations'], TranslationRead.fromJson),
    ancestors: readList(json['ancestors'], CategoryAncestorRead.fromJson),
  );

  final int id;
  final String slug;
  final List<TranslationRead> translations;

  /// Root -> parent.
  final List<CategoryAncestorRead> ancestors;
}

class ProductPublicImageRead {
  const ProductPublicImageRead({
    required this.id,
    required this.url,
    required this.sortOrder,
    required this.isPrimary,
  });

  factory ProductPublicImageRead.fromJson(Json json) => ProductPublicImageRead(
    id: json['id'] as int,
    url: json['url'] as String,
    sortOrder: json['sort_order'] as int,
    isPrimary: json['is_primary'] as bool,
  );

  final int id;
  final String url;
  final int sortOrder;
  final bool isPrimary;
}

class ProductPublicVariantRead {
  const ProductPublicVariantRead({
    required this.id,
    required this.platformSku,
    required this.price,
    required this.inStock,
    required this.attributes,
    this.imageIds,
  });

  factory ProductPublicVariantRead.fromJson(Json json) =>
      ProductPublicVariantRead(
        id: json['id'] as int,
        platformSku: json['platform_sku'] as String,
        price: json['price'] as String,
        inStock: json['in_stock'] as bool,
        attributes: Map<String, Object>.from(json['attributes'] as Json),
        imageIds: (json['image_ids'] as List<dynamic>?)?.cast<int>(),
      );

  final int id;
  final String platformSku;
  final Money price;
  final bool inStock;

  /// Values are `String`, `num` or `bool`.
  final Map<String, Object> attributes;

  /// Ids from the product's images.
  final List<int>? imageIds;
}

class ProductPublicAttributeRead {
  const ProductPublicAttributeRead({
    required this.key,
    required this.labelTranslations,
    required this.dataType,
    required this.value,
    required this.isVariantDefining,
    required this.sortOrder,
    this.unit,
  });

  factory ProductPublicAttributeRead.fromJson(Json json) =>
      ProductPublicAttributeRead(
        key: json['key'] as String,
        labelTranslations: readList(
          json['label_translations'],
          AttributeTranslationRead.fromJson,
        ),
        dataType: AttributeDataType.parse(json['data_type'] as String),
        unit: json['unit'] as String?,
        value: json['value'] is List
            ? (json['value'] as List<dynamic>).cast<String>()
            : json['value'] as Object,
        isVariantDefining: json['is_variant_defining'] as bool,
        sortOrder: json['sort_order'] as int,
      );

  final String key;
  final List<AttributeTranslationRead> labelTranslations;
  final AttributeDataType dataType;
  final String? unit;

  /// `String`, `num`, `bool` or `List<String>` (multi_select).
  final Object value;
  final bool isVariantDefining;
  final int sortOrder;
}

class ProductPublicRead {
  const ProductPublicRead({
    required this.id,
    required this.slug,
    required this.title,
    required this.hasVariants,
    required this.priceMin,
    required this.priceMax,
    required this.inStock,
    required this.shop,
    required this.category,
    required this.images,
    required this.variants,
    required this.attributes,
    required this.createdAt,
    this.description,
    this.platformSku,
    this.brand,
  });

  factory ProductPublicRead.fromJson(Json json) => ProductPublicRead(
    id: json['id'] as int,
    slug: json['slug'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    platformSku: json['platform_sku'] as String?,
    hasVariants: json['has_variants'] as bool,
    priceMin: json['price_min'] as String,
    priceMax: json['price_max'] as String,
    inStock: json['in_stock'] as bool,
    shop: ShopSummaryRead.fromJson(json['shop'] as Json),
    brand: json['brand'] == null
        ? null
        : BrandPublicRead.fromJson(json['brand'] as Json),
    category: ProductCategoryRead.fromJson(json['category'] as Json),
    images: readList(json['images'], ProductPublicImageRead.fromJson),
    variants: readList(json['variants'], ProductPublicVariantRead.fromJson),
    attributes: readList(
      json['attributes'],
      ProductPublicAttributeRead.fromJson,
    ),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final String slug;
  final String title;
  final String? description;

  /// Null on variant products; each variant has its own.
  final String? platformSku;
  final bool hasVariants;
  final Money priceMin;
  final Money priceMax;
  final bool inStock;
  final ShopSummaryRead shop;
  final BrandPublicRead? brand;
  final ProductCategoryRead category;

  /// Ordered by `sortOrder`.
  final List<ProductPublicImageRead> images;

  /// Active variants only; empty when [hasVariants] is false.
  final List<ProductPublicVariantRead> variants;

  /// Ordered by `sortOrder`, then `key`.
  final List<ProductPublicAttributeRead> attributes;
  final DateTime createdAt;
}

class BrandFacetRead {
  const BrandFacetRead({
    required this.id,
    required this.name,
    required this.count,
  });

  factory BrandFacetRead.fromJson(Json json) => BrandFacetRead(
    id: json['id'] as int,
    name: json['name'] as String,
    count: json['count'] as int,
  );

  final int id;
  final String name;
  final int count;
}

class CatalogFacetsRead {
  const CatalogFacetsRead({required this.brands, this.priceMin, this.priceMax});

  factory CatalogFacetsRead.fromJson(Json json) {
    final price = json['price'] as Json;
    return CatalogFacetsRead(
      brands: readList(json['brands'], BrandFacetRead.fromJson),
      priceMin: price['min'] as String?,
      priceMax: price['max'] as String?,
    );
  }

  /// By count desc, then name. Ignores the brand filter.
  final List<BrandFacetRead> brands;

  /// Range of `priceMin`; both null when nothing matches.
  final Money? priceMin;
  final Money? priceMax;
}
