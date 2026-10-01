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

String money(String amount) => formatMoney(amount, 'en-US');

Map<String, dynamic> _line(
  int id, {
  int shop = 1,
  int quantity = 1,
  String price = '100000.00',
  String? snapshot,
  bool available = true,
  bool inStock = true,
  bool variant = false,
}) => {
  'id': id,
  'quantity': quantity,
  'added_at': '2026-10-01T10:00:00Z',
  'product': {
    'id': id,
    'slug': 'p$id',
    'title': 'Product $id',
    'image_url': null,
  },
  'variant': variant
      ? {
          'id': 9,
          'attributes': {'color': 'red', 'size': 'M'},
        }
      : null,
  'shop': {
    'id': shop,
    'slug': 'shop$shop',
    'name': 'Shop $shop',
    'logo_url': null,
  },
  'price_snapshot': snapshot ?? price,
  'unit_price': price,
  'line_total': (double.parse(price) * quantity).toStringAsFixed(2),
  'available': available,
  'in_stock': inStock,
};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.lines);

  List<Map<String, dynamic>> lines;
  var loggedIn = false;
  (int, Object?)? patchError;
  final calls = <String>[];
  final bodies = <String, Object?>{};

  Map<String, dynamic> get cart => {
    'id': 1,
    'status': 'active',
    'items': lines,
    'item_count': lines.fold<int>(0, (n, l) => n + (l['quantity'] as int)),
    'subtotal': lines
        .where((l) => l['available'] as bool)
        .fold<double>(0, (n, l) => n + double.parse(l['line_total'] as String))
        .toStringAsFixed(2),
    'created_at': '2026-10-01T10:00:00Z',
    'updated_at': '2026-10-01T10:00:00Z',
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    calls.add(key);
    bodies[key] = options.data;
    (int, Object?) result = (404, {});
    if (key == 'GET /auth/me') {
      result = loggedIn
          ? (200, {'id': 4, 'email': 'a@b.uz', 'is_active': true})
          : (401, {});
    } else if (key == 'GET /cart') {
      result = (200, cart);
    } else if (key.startsWith('PATCH /cart/items/')) {
      final id = int.parse(options.path.split('/').last);
      if (patchError != null) {
        result = patchError!;
      } else {
        final line = lines.firstWhere((l) => l['id'] == id);
        final q = (options.data as Map)['quantity'] as int;
        line['quantity'] = q;
        line['price_snapshot'] = line['unit_price'];
        line['line_total'] = (double.parse(line['unit_price'] as String) * q)
            .toStringAsFixed(2);
        result = (200, line);
      }
    } else if (key.startsWith('DELETE /cart/items/')) {
      final id = int.parse(options.path.split('/').last);
      lines.removeWhere((l) => l['id'] == id);
      result = (204, null);
    }
    return ResponseBody.fromString(
      result.$2 == null ? '' : jsonEncode(result.$2),
      result.$1,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ProviderContainer, _Adapter)> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> lines, {
  bool loggedIn = false,
}) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'locale': 'en'});
  final adapter = _Adapter(lines)..loggedIn = loggedIn;
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
  c.read(routerProvider).go('/cart');
  await tester.pumpAndSettle();
  return (c, adapter);
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

void main() {
  testWidgets('empty cart: message and a way to the catalog', (tester) async {
    await _pump(tester, []);
    expect(find.textContaining(t('cart.emptyTitle')), findsOneWidget);
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

  testWidgets(
    'lines are grouped by shop; summary has count and total; guest note',
    (tester) async {
      await _pump(tester, [
        _line(1, shop: 1, quantity: 2),
        _line(2, shop: 2, variant: true),
        _line(3, shop: 1),
      ]);
      expect(find.text('Shop 1'), findsOneWidget);
      expect(find.text('Shop 2'), findsOneWidget);
      expect(find.text('red / M'), findsOneWidget);
      expect(
        find.text(t('cart.perItem', {'price': money('100000.00')})),
        findsNWidgets(3),
      );
      expect(find.text(t('cart.itemCount', {'count': 4})), findsOneWidget);
      expect(find.text(money('400000.00')), findsOneWidget);
      expect(find.text(t('cart.guestNote')), findsOneWidget);
      expect(find.text(t('cart.signInToCheckout')), findsOneWidget);
    },
  );

  testWidgets('quantity buttons PATCH and the new total shows', (tester) async {
    final (_, adapter) = await _pump(tester, [_line(1)]);
    await tester.tap(find.byTooltip(t('product.increase')));
    await tester.pumpAndSettle();
    expect(adapter.bodies['PATCH /cart/items/1'], {'quantity': 2});
    expect(find.text(t('cart.itemCount', {'count': 2})), findsOneWidget);
    await tester.tap(find.byTooltip(t('product.decrease')));
    await tester.pumpAndSettle();
    expect(adapter.bodies['PATCH /cart/items/1'], {'quantity': 1});
  });

  testWidgets('quantity cannot go below one', (tester) async {
    await _pump(tester, [_line(1)]);
    final minus = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove),
    );
    expect(minus.onPressed, isNull);
  });

  testWidgets('remove deletes the line', (tester) async {
    final (_, adapter) = await _pump(tester, [_line(1), _line(2)]);
    await tester.tap(find.byTooltip(t('cart.remove')).first);
    await tester.pumpAndSettle();
    expect(adapter.calls, contains('DELETE /cart/items/1'));
    expect(find.text('Product 1'), findsNothing);
    expect(find.text('Product 2'), findsOneWidget);
  });

  testWidgets(
    'a changed price shows old and new; accepting PATCHes the same quantity',
    (tester) async {
      final (_, adapter) = await _pump(tester, [
        _line(1, quantity: 3, price: '120000.00', snapshot: '100000.00'),
      ]);
      expect(
        find.text(
          t('cart.priceChanged', {
            'old': money('100000.00'),
            'price': money('120000.00'),
          }),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(t('cart.acceptPrice')));
      await tester.pumpAndSettle();
      expect(adapter.bodies['PATCH /cart/items/1'], {'quantity': 3});
      expect(find.text(t('cart.acceptPrice')), findsNothing);
    },
  );

  testWidgets('an unavailable line blocks checkout and says why', (
    tester,
  ) async {
    await _pump(tester, [_line(1), _line(2, available: false)], loggedIn: true);
    expect(find.text(t('cart.unavailable')), findsOneWidget);
    expect(find.text(t('cart.removeUnavailable')), findsOneWidget);
    final checkout = tester.widget<ButtonStyleButton>(
      _button(t('cart.checkout')),
    );
    expect(checkout.onPressed, isNull);
  });

  testWidgets('a line short on stock blocks checkout with its own hint', (
    tester,
  ) async {
    await _pump(tester, [_line(1, inStock: false)], loggedIn: true);
    expect(find.text(t('cart.notEnoughStock')), findsOneWidget);
    expect(find.text(t('cart.fixStock')), findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(_button(t('cart.checkout'))).onPressed,
      isNull,
    );
  });

  testWidgets('a refused update shows the backend message and keeps the line', (
    tester,
  ) async {
    final (_, adapter) = await _pump(tester, [_line(1)]);
    adapter.patchError = (
      400,
      {'detail': 'Not enough stock for the requested quantity'},
    );
    await tester.tap(find.byTooltip(t('product.increase')));
    await tester.pumpAndSettle();
    expect(
      find.text('Not enough stock for the requested quantity'),
      findsOneWidget,
    );
    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets('signed in: checkout opens the checkout screen', (tester) async {
    await _pump(tester, [_line(1)], loggedIn: true);
    expect(find.text(t('cart.guestNote')), findsNothing);
    await tester.tap(find.text(t('cart.checkout')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(t('checkout.title')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('guest: checkout goes through sign in', (tester) async {
    await _pump(tester, [_line(1)]);
    await tester.tap(find.text(t('cart.signInToCheckout')));
    await tester.pumpAndSettle();
    expect(find.text(t('auth.loginSubtitle')), findsOneWidget);
  });
}
