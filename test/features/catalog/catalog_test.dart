import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/features/catalog/data/catalog_repository.dart';
import 'package:market_app/features/catalog/data/category.dart';
import 'package:market_app/features/catalog/data/product.dart';

const _shop = {'id': 1, 'slug': 'silk', 'name': 'Silk', 'logo_url': null};

Map<String, dynamic> _card() => {
  'id': 7,
  'slug': 'suzani',
  'title': 'Suzani',
  'price_min': '120000.00',
  'price_max': '150000.00',
  'in_stock': true,
  'has_variants': true,
  'image_url': null,
  'shop': _shop,
  'brand': {'id': 3, 'name': 'B', 'logo_url': null, 'is_verified': true},
  'category_id': 2,
  'created_at': '2026-09-01T10:00:00Z',
};

/// Captures the request and answers with a canned JSON body.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.headers = const {}});

  final Object body;
  final Map<String, List<String>> headers;
  late Uri uri;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    uri = options.uri;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

CatalogRepository _repo(_Adapter adapter) => CatalogRepository(
  Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = adapter,
);

void main() {
  test('products: parses cards, total header and query string', () async {
    final adapter = _Adapter(
      [_card()],
      headers: {
        'x-total-count': ['1284'],
      },
    );
    final page = await _repo(adapter).products(
      const CatalogQuery(
        q: ' silk ',
        categoryId: 2,
        brandIds: [3, 7],
        inStock: true,
        attrs: {
          'color': ['red', 'blue'],
          'size': ['L'],
        },
        sort: CatalogSort.priceAsc,
      ),
      limit: 20,
    );
    expect(page.total, 1284);
    expect(page.items.single.title, 'Suzani');
    expect(page.items.single.brand!.isVerified, isTrue);
    expect(page.items.single.createdAt.year, 2026);

    final query = adapter.uri.query;
    expect(adapter.uri.path, '/api/v1/products');
    expect(query, contains('q=silk'));
    expect(query, contains('brand_id=3&brand_id=7'));
    expect(query, contains('attr=color%3Ared&attr=color%3Ablue&attr=size%3AL'));
    expect(query, contains('sort=price_asc'));
    expect(query, contains('in_stock=true'));
    expect(query, contains('limit=20'));
    expect(query, isNot(contains('shop_id')));
  });

  test('facets drop the sort param and read the price range', () async {
    final adapter = _Adapter({
      'brands': [
        {'id': 3, 'name': 'B', 'count': 5},
      ],
      'price': {'min': '10.00', 'max': null},
    });
    final facets = await _repo(adapter)
        .facets(const CatalogQuery(sort: CatalogSort.newest));
    expect(facets.brands.single.count, 5);
    expect(facets.priceMin, '10.00');
    expect(facets.priceMax, isNull);
    expect(adapter.uri.query, isNot(contains('sort')));
  });

  test('product page: variants, attributes, category ancestors', () async {
    final adapter = _Adapter({
      ..._card(),
      'description': null,
      'platform_sku': null,
      'category': {
        'id': 2,
        'slug': 'rugs',
        'translations': [
          {'locale': 'en', 'name': 'Rugs', 'description': null},
        ],
        'ancestors': [
          {'id': 1, 'slug': 'home', 'translations': <Object>[]},
        ],
      },
      'images': [
        {
          'id': 10,
          'url': 'http://i/1.jpg',
          'sort_order': 0,
          'is_primary': true,
        },
      ],
      'variants': [
        {
          'id': 5,
          'platform_sku': 'PSK-1',
          'price': '120000.00',
          'in_stock': false,
          'attributes': {'color': 'red', 'size': 2, 'gift': true},
          'image_ids': [10],
        },
      ],
      'attributes': [
        {
          'key': 'tags',
          'label_translations': [
            {'locale': 'uz', 'label': 'Teglar'},
          ],
          'data_type': 'multi_select',
          'unit': null,
          'value': ['a', 'b'],
          'is_variant_defining': false,
          'sort_order': 1,
        },
      ],
    });
    final product = await _repo(adapter).productBySlug('silk', 'suzani');
    expect(adapter.uri.path, '/api/v1/shops/by-slug/silk/products/suzani');
    expect(product.platformSku, isNull);
    expect(product.category.ancestors.single.slug, 'home');
    expect(product.variants.single.attributes['size'], 2);
    expect(product.variants.single.imageIds, [10]);
    expect(product.attributes.single.dataType, AttributeDataType.multiSelect);
    expect(product.attributes.single.value, ['a', 'b']);
  });

  test('category tree nests children; missing lists read as empty', () async {
    final adapter = _Adapter([
      {
        'id': 1,
        'parent_id': null,
        'slug': 'home',
        'icon_url': null,
        'sort_order': 0,
        'is_leaf': false,
        'product_count': 4,
        'children': [
          {
            'id': 2,
            'parent_id': 1,
            'slug': 'rugs',
            'icon_url': null,
            'sort_order': 0,
            'is_leaf': true,
            'product_count': 4,
          },
        ],
      },
    ]);
    final tree = await _repo(adapter).categories();
    expect(tree.single.children.single.parentId, 1);
    expect(tree.single.translations, isEmpty);
    expect(tree.single.children.single.children, isEmpty);
  });

  test('shop by slug parses rating', () async {
    final shop = await _repo(
      _Adapter({
        'id': 1,
        'slug': 'silk',
        'name': 'Silk',
        'description': null,
        'logo_url': null,
        'banner_url': null,
        'rating_avg': '4.50',
        'rating_count': 12,
        'created_at': '2026-01-01T00:00:00Z',
      }),
    ).shopBySlug('silk');
    expect(shop.ratingAvg, '4.50');
    expect(shop.ratingCount, 12);
  });
}
