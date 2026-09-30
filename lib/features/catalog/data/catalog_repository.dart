import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/endpoints.dart';
import 'category.dart';
import 'common.dart';
import 'product.dart';

class Page<T> {
  const Page({required this.items, this.total});

  final List<T> items;

  /// From the `X-Total-Count` header; null if the server didn't send it.
  final int? total;
}

/// Filters for `GET /products` and `GET /products/facets` (facets ignore paging and sort).
class CatalogQuery {
  const CatalogQuery({
    this.q,
    this.categoryId,
    this.brandIds = const [],
    this.shopId,
    this.priceMin,
    this.priceMax,
    this.inStock,
    this.attrs = const {},
    this.sort,
  });

  final String? q;
  final int? categoryId;
  final List<int> brandIds;
  final int? shopId;
  final Money? priceMin;
  final Money? priceMax;
  final bool? inStock;

  /// Attribute key -> accepted values. OR within a key, AND across keys. Needs
  /// [categoryId], and each key must be filterable in that category.
  final Map<String, List<String>> attrs;
  final CatalogSort? sort;

  Map<String, dynamic> toParams() => {
    if (q != null && q!.trim().isNotEmpty) 'q': q!.trim(),
    'category_id': ?categoryId,
    if (brandIds.isNotEmpty) 'brand_id': brandIds,
    'shop_id': ?shopId,
    'price_min': ?priceMin,
    'price_max': ?priceMax,
    'in_stock': ?inStock,
    if (attrs.isNotEmpty)
      'attr': [
        for (final entry in attrs.entries)
          for (final value in entry.value) '${entry.key}:$value',
      ],
    if (sort != null) 'sort': sort!.wire,
  };
}

/// Public reads, no auth. docs/storefront-catalog-api.md
class CatalogRepository {
  const CatalogRepository(this._dio);

  final Dio _dio;

  Future<Page<ProductCardRead>> products(
    CatalogQuery query, {
    int skip = 0,
    int limit = 50,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      CatalogEndpoints.products,
      queryParameters: {...query.toParams(), 'skip': skip, 'limit': limit},
    );
    return Page(
      items: readList(response.data, ProductCardRead.fromJson),
      total: int.tryParse(response.headers.value('x-total-count') ?? ''),
    );
  }

  Future<CatalogFacetsRead> facets(CatalogQuery query) async {
    final params = {...query.toParams()}..remove('sort');
    final response = await _dio.get<Json>(
      CatalogEndpoints.facets,
      queryParameters: params,
    );
    return CatalogFacetsRead.fromJson(response.data!);
  }

  Future<ProductPublicRead> product(int productId) async {
    final response = await _dio.get<Json>(CatalogEndpoints.product(productId));
    return ProductPublicRead.fromJson(response.data!);
  }

  Future<ProductPublicRead> productBySlug(
    String shopSlug,
    String productSlug,
  ) async {
    final response = await _dio.get<Json>(
      CatalogEndpoints.productBySlug(shopSlug, productSlug),
    );
    return ProductPublicRead.fromJson(response.data!);
  }

  Future<List<CategoryNodeRead>> categories() async {
    final response = await _dio.get<List<dynamic>>(CatalogEndpoints.categories);
    return readList(response.data, CategoryNodeRead.fromJson);
  }

  Future<List<CategoryAttributePublicRead>> categoryAttributes(
    int categoryId,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      CatalogEndpoints.categoryAttributes(categoryId),
    );
    return readList(response.data, CategoryAttributePublicRead.fromJson);
  }

  Future<List<BrandPublicRead>> brands({int? categoryId, String? q}) async {
    final response = await _dio.get<List<dynamic>>(
      CatalogEndpoints.brands,
      queryParameters: {'category_id': ?categoryId, 'q': ?q},
    );
    return readList(response.data, BrandPublicRead.fromJson);
  }

  Future<ShopPublicRead> shopBySlug(String shopSlug) async {
    final response = await _dio.get<Json>(
      CatalogEndpoints.shopBySlug(shopSlug),
    );
    return ShopPublicRead.fromJson(response.data!);
  }
}

/// Override with the app's shared `Dio` (see `createApiClient`).
final dioProvider = Provider<Dio>(
  (ref) => throw UnimplementedError('dioProvider not overridden'),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(dioProvider)),
);
