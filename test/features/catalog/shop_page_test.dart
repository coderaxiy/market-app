import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/app.dart';
import 'package:market_app/core/api/providers.dart';
import 'package:market_app/core/format.dart';
import 'package:market_app/core/i18n/i18n.dart';
import 'package:market_app/core/routing/router.dart';
import 'package:market_app/core/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

String t(String key, [Map<String, Object>? params]) =>
    translate(AppLocale.en, key, params);

Map<String, dynamic> _shop({
  String? rating = '4.50',
  int ratings = 12,
  String? description = 'Hand made things.',
}) => {
  'id': 1,
  'slug': 'silk',
  'name': 'Silk Road',
  'description': description,
  'logo_url': null,
  'banner_url': 'http://i/banner.jpg',
  'rating_avg': rating,
  'rating_count': ratings,
  'created_at': '2026-01-15T00:00:00Z',
};

Map<String, dynamic> _card(int id) => {
  'id': id,
  'slug': 'p$id',
  'title': 'Shop thing $id',
  'price_min': '1000.00',
  'price_max': '1000.00',
  'in_stock': true,
  'has_variants': false,
  'image_url': null,
  'shop': {'id': 1, 'slug': 'silk', 'name': 'Silk Road', 'logo_url': null},
  'brand': null,
  'category_id': 2,
  'created_at': '2026-09-01T10:00:00Z',
};

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic> shop = _shop();
  int shopStatus = 200;
  final productQueries = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    (int, Object?) result = (404, {});
    if (key == 'GET /auth/me') {
      result = (401, {});
    } else if (key == 'GET /cart') {
      result = (
        200,
        {
          'id': 1,
          'status': 'active',
          'items': <Object>[],
          'item_count': 0,
          'subtotal': '0.00',
          'created_at': '2026-10-01T10:00:00Z',
          'updated_at': '2026-10-01T10:00:00Z',
        },
      );
    } else if (key == 'GET /shops/by-slug/silk') {
      result = shopStatus == 200
          ? (200, shop)
          : (shopStatus, {'detail': 'Shop not found'});
    } else if (key == 'GET /products') {
      productQueries.add(options.uri);
      result = (200, [_card(1), _card(2)]);
    }
    return ResponseBody.fromString(
      jsonEncode(result.$2),
      result.$1,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'x-total-count': ['2'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_Adapter> _pump(
  WidgetTester tester,
  _Adapter adapter,
  String path,
) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'locale': 'en'});
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
  c.read(routerProvider).go(path);
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  testWidgets(
    'shop page: name, rating, description, join date and its products',
    (tester) async {
      final adapter = await _pump(tester, _Adapter(), '/shops/silk');
      expect(find.text('Silk Road'), findsWidgets);
      expect(
        find.text('4.50 · ${t('shop.ratingCount', {'count': 12})}'),
        findsOneWidget,
      );
      expect(find.text('Hand made things.'), findsOneWidget);
      expect(
        find.text(
          t('shop.since', {'date': formatDate(DateTime.utc(2026, 1, 15))}),
        ),
        findsOneWidget,
      );
      expect(find.text('Shop thing 1'), findsOneWidget);
      // Only this shop's products are asked for.
      expect(adapter.productQueries.last.queryParameters['shop_id'], '1');
    },
  );

  testWidgets('a shop nobody rated shows no rating line', (tester) async {
    final adapter = _Adapter()
      ..shop = _shop(rating: null, ratings: 0, description: null);
    await _pump(tester, adapter, '/shops/silk');
    expect(
      find.textContaining(t('shop.ratingCount', {'count': 0})),
      findsNothing,
    );
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('an unknown or closed shop shows not found', (tester) async {
    final adapter = _Adapter()..shopStatus = 404;
    await _pump(tester, adapter, '/shops/silk');
    expect(find.text(t('notFound.body')), findsOneWidget);
  });

  testWidgets('a product card on the shop page opens the product', (
    tester,
  ) async {
    await _pump(tester, _Adapter(), '/shops/silk');
    await tester.tap(find.text('Shop thing 2'));
    await tester.pumpAndSettle();
    // The product page asks for this product by slugs; our fake answers 404.
    expect(find.text(t('notFound.body')), findsOneWidget);
  });
}
