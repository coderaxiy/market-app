import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/app.dart';
import 'package:market_app/core/api/providers.dart';
import 'package:market_app/core/i18n/i18n.dart';
import 'package:market_app/core/routing/router.dart';
import 'package:market_app/core/settings/settings.dart';
import 'package:market_app/features/catalog/application/catalog_providers.dart';
import 'package:market_app/features/catalog/data/catalog_repository.dart';
import 'package:market_app/features/catalog/data/category.dart';
import 'package:market_app/features/catalog/data/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

String t(String key, [Map<String, Object>? params]) =>
    translate(AppLocale.en, key, params);

Map<String, dynamic> _node(
  int id,
  String slug,
  String name,
  int count, [
  List<Map<String, dynamic>> children = const [],
]) => {
  'id': id,
  'parent_id': null,
  'slug': slug,
  'icon_url': null,
  'sort_order': 0,
  'is_leaf': children.isEmpty,
  'product_count': count,
  'translations': [
    {'locale': 'en', 'name': name, 'description': null},
  ],
  'children': children,
};

Map<String, dynamic> _card(
  int id, {
  bool inStock = true,
  String? min,
  String? max,
}) => {
  'id': id,
  'slug': 'p$id',
  'title': 'Product $id',
  'price_min': min ?? '100000.00',
  'price_max': max ?? min ?? '100000.00',
  'in_stock': inStock,
  'has_variants': false,
  'image_url': null,
  'shop': {'id': 1, 'slug': 'silk', 'name': 'Silk', 'logo_url': null},
  'brand': null,
  'category_id': 2,
  'created_at': '2026-09-01T10:00:00Z',
};

class _Adapter implements HttpClientAdapter {
  _Adapter({this.total = 3});

  /// Products the catalog "has"; pages are cut from it by `skip` and `limit`.
  int total;
  final productRequests = <Uri>[];
  var emptyCatalog = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    Object? body = {};
    var status = 200;
    var headers = <String, List<String>>{};
    switch (key) {
      case 'GET /auth/me':
        status = 401;
      case 'GET /cart':
        body = {
          'id': 1,
          'status': 'active',
          'items': <Object>[],
          'item_count': 0,
          'subtotal': '0.00',
          'created_at': '2026-10-01T10:00:00Z',
          'updated_at': '2026-10-01T10:00:00Z',
        };
      case 'GET /categories':
        body = [
          _node(1, 'home', 'Home goods', 5, [_node(2, 'rugs', 'Rugs', 3)]),
          _node(3, 'empty', 'Empty branch', 0),
        ];
      case 'GET /products':
        productRequests.add(options.uri);
        final skip = options.queryParameters['skip'] as int? ?? 0;
        final limit = options.queryParameters['limit'] as int? ?? 50;
        final count = emptyCatalog ? 0 : total;
        final end = (skip + limit).clamp(0, count);
        body = [
          for (var i = skip; i < end; i++)
            _card(
              i + 1,
              inStock: i != 1,
              min: i == 0 ? '100000.00' : null,
              max: i == 0 ? '150000.00' : null,
            ),
        ];
        headers = {
          'x-total-count': ['$count'],
        };
      default:
        status = 404;
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ProviderContainer, _Adapter)> _pump(
  WidgetTester tester,
  String path, {
  int total = 3,
}) async {
  SharedPreferences.setMockInitialValues({'locale': 'en'});
  final adapter = _Adapter(total: total);
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      dioProvider.overrideWithValue(
        Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
          ..httpClientAdapter = adapter,
      ),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const MarketApp()),
  );
  await tester.pumpAndSettle();
  adapter.productRequests.clear(); // the home page asked for its own rows
  c.read(routerProvider).go(path);
  await tester.pumpAndSettle();
  return (c, adapter);
}

void main() {
  group('category helpers', () {
    final tree = [
      CategoryNodeRead.fromJson(
        _node(1, 'home', 'Home goods', 5, [
          _node(2, 'rugs', 'Rugs', 3),
          _node(4, 'dead', 'Dead', 0),
        ]),
      ),
      CategoryNodeRead.fromJson(_node(3, 'empty', 'Empty', 0)),
    ];

    test('empty branches are dropped, recursively', () {
      final pruned = nonEmptyCategories(tree);
      expect(pruned.map((c) => c.slug), ['home']);
      expect(pruned.single.children.map((c) => c.slug), ['rugs']);
    });

    test('find by slug anywhere in the tree', () {
      expect(findCategoryBySlug(tree, 'rugs')!.id, 2);
      expect(findCategoryBySlug(tree, 'nope'), isNull);
    });

    test('name: current locale, then en, then the slug', () {
      final node = tree.first;
      expect(categoryName(node, AppLocale.uz), 'Home goods');
      final bare = CategoryNodeRead.fromJson({
        ..._node(9, 'bare', 'x', 1),
        'translations': <Object>[],
      });
      expect(categoryName(bare, AppLocale.ru), 'bare');
    });
  });

  test('CatalogQuery is a value: equal queries share a provider', () {
    const a = CatalogQuery(q: 'x', categoryId: 2, sort: CatalogSort.newest);
    const b = CatalogQuery(q: 'x', categoryId: 2, sort: CatalogSort.newest);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(a.copyWith(inStock: true)));
    expect(
      a.copyWith(sort: CatalogSort.priceAsc).toParams()['sort'],
      'price_asc',
    );
  });

  testWidgets(
    'catalog: root categories, products, count, price range, sold out',
    (tester) async {
      await _pump(tester, '/catalog');
      expect(find.text('Home goods · 5'), findsOneWidget);
      expect(find.textContaining('Empty branch'), findsNothing);
      expect(find.text('Product 1'), findsOneWidget);
      expect(
        find.text(t('catalog.productCount', {'count': 3})),
        findsOneWidget,
      );
      // Product 1 has a price range, the rest one price.
      expect(find.textContaining('from'), findsOneWidget);
      expect(find.text(t('catalog.outOfStock')), findsOneWidget);
    },
  );

  testWidgets(
    'a category chip opens that category with its own subcategories',
    (tester) async {
      final (_, adapter) = await _pump(tester, '/catalog');
      await tester.tap(find.text('Home goods · 5'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Home goods'),
        ),
        findsOneWidget,
      );
      expect(find.text('Rugs · 3'), findsOneWidget);
      expect(adapter.productRequests.last.queryParameters['category_id'], '1');
    },
  );

  testWidgets('unknown category slug shows not found', (tester) async {
    await _pump(tester, '/catalog/nope');
    expect(find.text(t('notFound.body')), findsOneWidget);
  });

  testWidgets('sort and in-stock restart the list with the right params', (
    tester,
  ) async {
    final (_, adapter) = await _pump(tester, '/catalog');
    await tester.tap(find.text(t('catalog.sortNewest')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('catalog.sortPriceAsc')).last);
    await tester.pumpAndSettle();
    expect(adapter.productRequests.last.queryParameters['sort'], 'price_asc');

    await tester.tap(find.text(t('catalog.inStockOnly')));
    await tester.pumpAndSettle();
    expect(adapter.productRequests.last.queryParameters['in_stock'], 'true');
    expect(adapter.productRequests.last.queryParameters['sort'], 'price_asc');
  });

  testWidgets('scrolling near the end loads the next page, once', (
    tester,
  ) async {
    final (_, adapter) = await _pump(tester, '/catalog', total: 45);
    expect(adapter.productRequests, hasLength(1));
    expect(
      adapter.productRequests.first.queryParameters['limit'],
      '$productPageSize',
    );
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
      await tester.pumpAndSettle();
    }
    final skips = adapter.productRequests
        .map((u) => u.queryParameters['skip'] ?? '0')
        .toList();
    expect(skips, ['0', '20', '40']);
    expect(find.text('Product 45'), findsOneWidget);
  });

  testWidgets('empty catalog shows the empty message', (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final (_, adapter) = await _pump(tester, '/catalog', total: 0);
    adapter.emptyCatalog = true;
    expect(find.text(t('catalog.emptyBody')), findsOneWidget);
  });

  testWidgets('search: prompt without text, results with it', (tester) async {
    final (c, adapter) = await _pump(tester, '/search');
    expect(find.textContaining(t('catalog.searchPromptTitle')), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' suzani ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
      find.text(t('catalog.searchResultsFor', {'query': 'suzani'})),
      findsOneWidget,
    );
    expect(adapter.productRequests.last.queryParameters['q'], 'suzani');
    expect(find.text('Product 1'), findsOneWidget);
    // "Best match" is offered only with a search text.
    expect(find.text(t('catalog.sortRelevance')), findsOneWidget);
    expect(
      c.read(routerProvider).routerDelegate.currentConfiguration.uri.toString(),
      '/search?q=suzani',
    );
  });
}
