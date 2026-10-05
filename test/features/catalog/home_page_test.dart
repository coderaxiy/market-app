import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/app.dart';
import 'package:market_app/core/api/providers.dart';
import 'package:market_app/core/i18n/i18n.dart';
import 'package:market_app/core/settings/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

String t(String key, [Map<String, Object>? params]) =>
    translate(AppLocale.en, key, params);

Map<String, dynamic> _node(int id, String slug, String name, int count) => {
  'id': id,
  'parent_id': null,
  'slug': slug,
  'icon_url': null,
  'sort_order': 0,
  'is_leaf': true,
  'product_count': count,
  'translations': [
    {'locale': 'en', 'name': name, 'description': null},
  ],
  'children': <Object>[],
};

Map<String, dynamic> _card(int id, String title) => {
  'id': id,
  'slug': 'p$id',
  'title': title,
  'price_min': '1000.00',
  'price_max': '1000.00',
  'in_stock': true,
  'has_variants': false,
  'image_url': null,
  'shop': {'id': 1, 'slug': 's', 'name': 'Shop', 'logo_url': null},
  'brand': null,
  'category_id': 2,
  'created_at': '2026-09-01T10:00:00Z',
};

class _Adapter implements HttpClientAdapter {
  _Adapter({this.catalogWorks = true});

  final bool catalogWorks;
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
    } else if (key == 'GET /categories' && catalogWorks) {
      result = (
        200,
        [
          _node(1, 'rugs', 'Rugs', 9),
          _node(2, 'mugs', 'Mugs', 30),
          _node(3, 'old', 'Old', 0),
          _node(4, 'a', 'Aa', 5),
          _node(5, 'b', 'Bb', 4),
        ],
      );
    } else if (key == 'GET /products' && catalogWorks) {
      productQueries.add(options.uri);
      final category = options.queryParameters['category_id'];
      final title = category == null ? 'New thing' : 'Cat $category thing';
      result = (
        200,
        [_card(category == null ? 100 : 200 + (category as int), title)],
      );
    }
    return ResponseBody.fromString(
      jsonEncode(result.$2),
      result.$1,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'x-total-count': ['1'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<_Adapter> _pump(WidgetTester tester, {bool catalogWorks = true}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'locale': 'en'});
  final adapter = _Adapter(catalogWorks: catalogWorks);
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
  return adapter;
}

void main() {
  testWidgets(
    'home shows the welcome, categories, new products and the steps',
    (tester) async {
      await _pump(tester);
      expect(find.text(t('home.heroTitle')), findsOneWidget);
      expect(find.text(t('home.categoriesTitle')), findsOneWidget);
      // Empty categories are left out.
      expect(find.text('Old'), findsNothing);
      expect(find.text('Rugs'), findsWidgets);
      expect(find.text(t('home.newArrivals')), findsOneWidget);
      expect(find.text('New thing'), findsOneWidget);
      expect(find.text(t('home.step1Title')), findsOneWidget);
    },
  );

  testWidgets('the three biggest categories get their own row, newest first', (
    tester,
  ) async {
    final adapter = await _pump(tester);
    final byCategory = adapter.productQueries
        .where((u) => u.queryParameters.containsKey('category_id'))
        .toList();
    // Mugs (30), Rugs (9), Aa (5): not Bb (4).
    expect(byCategory.map((u) => u.queryParameters['category_id']).toSet(), {
      '2',
      '1',
      '4',
    });
    expect(
      byCategory.every((u) => u.queryParameters['sort'] == 'newest'),
      isTrue,
    );
    expect(find.text('Cat 2 thing'), findsOneWidget);
  });

  testWidgets('the search box opens search; the button opens the catalog', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text(t('header.searchPlaceholder')));
    await tester.pumpAndSettle();
    expect(
      find
              .text(t('catalog.searchPromptTitle'), findRichText: true)
              .evaluate()
              .isNotEmpty ||
          find
              .textContaining(t('catalog.searchPromptTitle'))
              .evaluate()
              .isNotEmpty,
      isTrue,
    );
  });

  testWidgets('"Browse the catalog" goes to the catalog', (tester) async {
    await _pump(tester);
    await tester.tap(find.text(t('home.heroCta')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(t('nav.catalog')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a category chip opens that category', (tester) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(ActionChip, 'Mugs'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Mugs')),
      findsOneWidget,
    );
  });

  testWidgets(
    'if the catalog requests fail, the welcome and steps still show',
    (tester) async {
      await _pump(tester, catalogWorks: false);
      expect(find.text(t('home.heroTitle')), findsOneWidget);
      expect(find.text(t('home.categoriesTitle')), findsNothing);
      expect(find.text(t('home.newArrivals')), findsNothing);
      expect(find.text(t('home.step2Title')), findsOneWidget);
    },
  );
}
