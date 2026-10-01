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
import 'package:market_app/features/catalog/application/product_view_logic.dart';
import 'package:market_app/features/catalog/data/category.dart';
import 'package:market_app/features/catalog/data/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

String t(String key, [Map<String, Object>? params]) =>
    translate(AppLocale.en, key, params);

const _shop = {'id': 1, 'slug': 'silk', 'name': 'Silk', 'logo_url': null};

Map<String, dynamic> _variant(
  int id,
  String sku,
  String price,
  bool inStock,
  String color,
  String size,
  List<int> images,
) => {
  'id': id,
  'platform_sku': sku,
  'price': price,
  'in_stock': inStock,
  'attributes': {'color': color, 'size': size},
  'image_ids': images,
};

Map<String, dynamic> _product({
  bool variants = true,
  bool inStock = true,
  String slug = 'suzani',
}) => {
  'id': 7,
  'slug': slug,
  'title': 'Suzani',
  'description': 'Hand embroidered.',
  'platform_sku': variants ? null : 'PSK-SINGLE',
  'has_variants': variants,
  'price_min': variants ? '120000.00' : '90000.00',
  'price_max': variants ? '150000.00' : '90000.00',
  'in_stock': inStock,
  'shop': _shop,
  'brand': {'id': 3, 'name': 'Bukhara', 'logo_url': null, 'is_verified': true},
  'category': {
    'id': 2,
    'slug': 'rugs',
    'translations': [
      {'locale': 'en', 'name': 'Rugs', 'description': null},
    ],
    'ancestors': <Object>[],
  },
  'images': [
    {'id': 10, 'url': 'http://i/10.jpg', 'sort_order': 0, 'is_primary': true},
    {'id': 11, 'url': 'http://i/11.jpg', 'sort_order': 1, 'is_primary': false},
  ],
  'variants': variants
      ? [
          _variant(5, 'PSK-1', '120000.00', false, 'red', 'S', [10]),
          _variant(6, 'PSK-2', '150000.00', true, 'red', 'M', [11]),
          _variant(8, 'PSK-3', '150000.00', true, 'blue', 'M', []),
        ]
      : <Object>[],
  'attributes': [
    {
      'key': 'material',
      'label_translations': [
        {'locale': 'en', 'label': 'Material'},
      ],
      'data_type': 'text',
      'unit': null,
      'value': 'Silk',
      'is_variant_defining': false,
      'sort_order': 0,
    },
    {
      'key': 'handmade',
      'label_translations': [
        {'locale': 'en', 'label': 'Handmade'},
      ],
      'data_type': 'boolean',
      'unit': null,
      'value': true,
      'is_variant_defining': false,
      'sort_order': 1,
    },
    {
      'key': 'weight',
      'label_translations': [
        {'locale': 'en', 'label': 'Weight'},
      ],
      'data_type': 'number',
      'unit': 'g',
      'value': 1250,
      'is_variant_defining': false,
      'sort_order': 2,
    },
    {
      'key': 'color',
      'label_translations': <Object>[],
      'data_type': 'select',
      'unit': null,
      'value': 'red',
      'is_variant_defining': true,
      'sort_order': 3,
    },
  ],
  'created_at': '2026-09-01T10:00:00Z',
};

final _categoryAttributes = [
  {
    'id': 1,
    'key': 'size',
    'data_type': 'select',
    'options': ['S', 'M'],
    'unit': 'EU',
    'is_filterable': true,
    'is_variant_defining': true,
    'sort_order': 1,
    'translations': [
      {'locale': 'en', 'label': 'Size'},
    ],
  },
  {
    'id': 2,
    'key': 'color',
    'data_type': 'select',
    'options': ['red', 'blue'],
    'unit': null,
    'is_filterable': true,
    'is_variant_defining': true,
    'sort_order': 0,
    'translations': [
      {'locale': 'en', 'label': 'Color'},
    ],
  },
];

Map<String, dynamic> _card(int id) => {
  'id': id,
  'slug': 'p$id',
  'title': 'Rail product $id',
  'price_min': '1000.00',
  'price_max': '1000.00',
  'in_stock': true,
  'has_variants': false,
  'image_url': null,
  'shop': _shop,
  'brand': null,
  'category_id': 2,
  'created_at': '2026-09-01T10:00:00Z',
};

Map<String, dynamic> _cartItem() => {
  'id': 1,
  'quantity': 1,
  'added_at': '2026-10-01T10:00:00Z',
  'product': {'id': 7, 'slug': 'suzani', 'title': 'Suzani', 'image_url': null},
  'variant': null,
  'shop': _shop,
  'price_snapshot': '150000.00',
  'unit_price': '150000.00',
  'line_total': '150000.00',
  'available': true,
  'in_stock': true,
};

class _Adapter implements HttpClientAdapter {
  Map<String, dynamic> product = _product();
  var productStatus = 200;
  (int, Object?) cartAdd = (201, _cartItem());
  final bodies = <String, Object?>{};
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    bodies[key] = options.data;
    final (int, Object?) result = switch (key) {
      'GET /auth/me' => (401, {}),
      'GET /cart' => (
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
      ),
      'GET /shops/by-slug/silk/products/suzani' => (
        productStatus,
        productStatus == 200 ? product : {'detail': 'Product not found'},
      ),
      'GET /shops/by-slug/silk/products/old-name' => (200, product),
      'GET /categories/2/attributes' => (200, _categoryAttributes),
      'GET /products' => (200, [_card(7), _card(21), _card(22)]),
      'POST /cart/items' => cartAdd,
      _ => (404, {}),
    };
    return ResponseBody.fromString(
      jsonEncode(result.$2),
      result.$1,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        'x-total-count': ['3'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ProviderContainer, _Adapter)> _pump(
  WidgetTester tester,
  _Adapter adapter,
  String path,
) async {
  tester.view.physicalSize = const Size(800, 2600);
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
  return (c, adapter);
}

void main() {
  final product = ProductPublicRead.fromJson(_product());
  final attributes = [
    for (final a in _categoryAttributes)
      CategoryAttributePublicRead.fromJson(a),
  ];

  group('variant logic', () {
    test(
      'axes: labelled, ordered by category sort order, options by option order',
      () {
        final axes = buildAxes(product, attributes, AppLocale.en);
        expect(axes.map((a) => a.key), ['color', 'size']);
        expect(axes.map((a) => a.label), ['Color', 'Size, EU']);
        expect(axes[0].options, ['red', 'blue']);
        expect(axes[1].options, ['S', 'M']);
      },
    );

    test('without category attributes: raw keys, alphabetical', () {
      final axes = buildAxes(product, const [], AppLocale.en);
      expect(axes.map((a) => a.label), ['color', 'size']);
    });

    final axes = buildAxes(product, attributes, AppLocale.en);

    test('opens on the first variant in stock', () {
      expect(initialSelection(product, axes), {'color': 'red', 'size': 'M'});
    });

    test('choosing an impossible combination jumps to a variant that has the value', () {
      final next = choose(
        {'color': 'red', 'size': 'S'},
        'color',
        'blue',
        product.variants,
        axes,
      );
      expect(next, {'color': 'blue', 'size': 'M'});
      expect(findVariant(product.variants, next, axes)!.id, 8);
    });

    test('option states: available, sold out, only with another choice', () {
      final sel = {'color': 'red', 'size': 'M'};
      OptionState state(String k, String v) =>
          optionState(k, v, sel, product.variants, axes);
      expect(state('size', 'M'), OptionState.available);
      expect(state('size', 'S'), OptionState.soldOut);
      expect(state('color', 'blue'), OptionState.available);
      expect(
        optionState(
          'color',
          'blue',
          {'color': 'red', 'size': 'S'},
          product.variants,
          axes,
        ),
        OptionState.other,
      );
    });

    test("the chosen variant's photos come first", () {
      final v6 = product.variants.firstWhere((v) => v.id == 6);
      expect(orderedImages(product, v6).map((i) => i.id), [11, 10]);
      expect(orderedImages(product, null).map((i) => i.id), [10, 11]);
    });

    test('specs skip variant-defining attributes and format values', () {
      final rows = specRows(product, AppLocale.en, createT(AppLocale.en));
      expect(rows.map((r) => '${r.label}=${r.value}'), [
        'Material=Silk',
        'Handmade=Yes',
        'Weight=1,250 g',
      ]);
    });
  });

  testWidgets(
    'variant product: opens on an in-stock variant; picking a sold-out one disables buying',
    (tester) async {
      final (_, _) = await _pump(tester, _Adapter(), '/shops/silk/suzani');
      expect(find.text('Suzani'), findsWidgets);
      expect(find.text('Bukhara'), findsOneWidget);
      expect(find.text('${t('product.article')}: PSK-2'), findsOneWidget);
      expect(find.text(formatMoney('150000.00', 'en-US')), findsWidgets);
      expect(find.text('Color'), findsOneWidget);
      expect(find.text('Size, EU'), findsOneWidget);
      expect(find.text('Hand embroidered.'), findsOneWidget);
      expect(find.text('Material'), findsOneWidget);
      // Rails leave the product itself out.
      expect(find.text('Rail product 21'), findsWidgets);
      expect(find.text('Rail product 7'), findsNothing);

      await tester.tap(find.text('S'));
      await tester.pumpAndSettle();
      expect(find.text('${t('product.article')}: PSK-1'), findsOneWidget);
      expect(find.text(formatMoney('120000.00', 'en-US')), findsWidgets);
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(t('catalog.outOfStock')).last,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'add to cart sends product, variant and quantity, then offers the cart',
    (tester) async {
      final adapter = _Adapter();
      await _pump(tester, adapter, '/shops/silk/suzani');
      await tester.tap(find.byTooltip(t('product.increase')));
      await tester.pump();
      await tester.tap(find.text(t('product.addToCart')));
      await tester.pumpAndSettle();
      expect(adapter.bodies['POST /cart/items'], {
        'product_id': 7,
        'variant_id': 6,
        'quantity': 2,
      });
      expect(find.textContaining(t('product.addedToCart')), findsOneWidget);
      expect(find.text(t('nav.cart')), findsWidgets);
    },
  );

  testWidgets("a refused add shows the backend's message", (tester) async {
    final adapter = _Adapter()
      ..cartAdd = (
        400,
        {'detail': 'Not enough stock for the requested quantity'},
      );
    await _pump(tester, adapter, '/shops/silk/suzani');
    await tester.tap(find.text(t('product.addToCart')));
    await tester.pumpAndSettle();
    expect(
      find.text('Not enough stock for the requested quantity'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a product without variants buys directly and shows its article',
    (tester) async {
      final adapter = _Adapter()..product = _product(variants: false);
      await _pump(tester, adapter, '/shops/silk/suzani');
      expect(find.text('${t('product.article')}: PSK-SINGLE'), findsOneWidget);
      expect(find.text('Size, EU'), findsNothing);
      await tester.tap(find.text(t('product.addToCart')));
      await tester.pumpAndSettle();
      expect(adapter.bodies['POST /cart/items'], {
        'product_id': 7,
        'variant_id': null,
        'quantity': 1,
      });
    },
  );

  testWidgets('an old slug is replaced by the canonical route', (tester) async {
    final adapter = _Adapter();
    await _pump(tester, adapter, '/shops/silk/old-name');
    // The page for the canonical slug was opened (`replace` doesn't move the router's
    // base location, so check what it fetched).
    expect(adapter.calls, contains('GET /shops/by-slug/silk/products/suzani'));
  });

  testWidgets('an unknown product shows not found', (tester) async {
    final adapter = _Adapter()..productStatus = 404;
    await _pump(tester, adapter, '/shops/silk/suzani');
    expect(find.text(t('notFound.body')), findsOneWidget);
  });
}
