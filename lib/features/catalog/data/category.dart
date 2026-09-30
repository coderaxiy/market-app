// Mirrors openapi/api.yaml -> CategoryNodeRead, CategoryAttributePublicRead,
// AttributeDataType. Guide: sdk-contract/docs/storefront-catalog-api.md §4.

import 'common.dart';

enum AttributeDataType {
  text,
  number,
  boolean,
  select,
  multiSelect;

  static AttributeDataType parse(String value) => switch (value) {
    'text' => text,
    'number' => number,
    'boolean' => boolean,
    'select' => select,
    'multi_select' => multiSelect,
    _ => throw FormatException('Unknown AttributeDataType: $value'),
  };
}

class CategoryNodeRead {
  const CategoryNodeRead({
    required this.id,
    required this.slug,
    required this.sortOrder,
    required this.isLeaf,
    required this.translations,
    required this.productCount,
    required this.children,
    this.parentId,
    this.iconUrl,
  });

  factory CategoryNodeRead.fromJson(Json json) => CategoryNodeRead(
    id: json['id'] as int,
    parentId: json['parent_id'] as int?,
    slug: json['slug'] as String,
    iconUrl: json['icon_url'] as String?,
    sortOrder: json['sort_order'] as int,
    isLeaf: json['is_leaf'] as bool,
    translations: readList(json['translations'], TranslationRead.fromJson),
    productCount: json['product_count'] as int,
    children: readList(json['children'], CategoryNodeRead.fromJson),
  );

  final int id;
  final int? parentId;

  /// Globally unique.
  final String slug;
  final String? iconUrl;
  final int sortOrder;
  final bool isLeaf;
  final List<TranslationRead> translations;

  /// Visible products, descendants included.
  final int productCount;
  final List<CategoryNodeRead> children;
}

class CategoryAttributePublicRead {
  const CategoryAttributePublicRead({
    required this.id,
    required this.key,
    required this.dataType,
    required this.isFilterable,
    required this.isVariantDefining,
    required this.sortOrder,
    required this.translations,
    this.options,
    this.unit,
  });

  factory CategoryAttributePublicRead.fromJson(Json json) =>
      CategoryAttributePublicRead(
        id: json['id'] as int,
        key: json['key'] as String,
        dataType: AttributeDataType.parse(json['data_type'] as String),
        options: (json['options'] as List<dynamic>?)?.cast<String>(),
        unit: json['unit'] as String?,
        isFilterable: json['is_filterable'] as bool,
        isVariantDefining: json['is_variant_defining'] as bool,
        sortOrder: json['sort_order'] as int,
        translations: readList(
          json['translations'],
          AttributeTranslationRead.fromJson,
        ),
      );

  final int id;
  final String key;
  final AttributeDataType dataType;

  /// Raw values, not localized.
  final List<String>? options;
  final String? unit;

  /// Only these can be used in the `attr` filter.
  final bool isFilterable;
  final bool isVariantDefining;
  final int sortOrder;
  final List<AttributeTranslationRead> translations;
}
