import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/core/api/providers.dart';
import 'package:market_app/features/auth/data/auth_repository.dart';
import 'package:market_app/features/cart/application/cart_controller.dart';
import 'package:market_app/features/cart/data/cart.dart';

const _shop = {'id': 1, 'slug': 'silk', 'name': 'Silk', 'logo_url': null};

Map<String, dynamic> _item(
  int id, {
  int quantity = 1,
  String snapshot = '100.00',
  String unit = '100.00',
  bool available = true,
}) => {
  'id': id,
  'quantity': quantity,
  'added_at': '2026-09-01T10:00:00Z',
  'product': {'id': 7, 'slug': 'p', 'title': 'P', 'image_url': null},
  'variant': id == 2
      ? {
          'id': 9,
          'attributes': {'color': 'red', 'size': 2},
        }
      : null,
  'shop': _shop,
  'price_snapshot': snapshot,
  'unit_price': unit,
  'line_total': '${quantity * 100}.00',
  'available': available,
  'in_stock': true,
};

Map<String, dynamic> _cart(List<Map<String, dynamic>> items) => {
  'id': 1,
  'status': 'active',
  'items': items,
  'item_count': items.fold<int>(0, (sum, i) => sum + (i['quantity'] as int)),
  'subtotal': '100.00',
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-01T10:00:00Z',
};

class _Adapter implements HttpClientAdapter {
  var cart = _cart([_item(1)]);
  var loggedIn = false;
  final calls = <String>[];
  final bodies = <String, Object?>{};

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
      'GET /auth/me' =>
        loggedIn
            ? (
                200,
                {
                  'id': 4,
                  'email': 'a@b.uz',
                  'full_name': null,
                  'is_active': true,
                },
              )
            : (401, {'detail': 'Not authenticated'}),
      'POST /auth/login' => () {
        loggedIn = true;
        cart = _cart([_item(1), _item(2)]); // guest lines merged
        return (200, {'message': 'ok'});
      }(),
      'GET /cart' => (200, cart),
      'POST /cart/items' => (201, _item(3)),
      'DELETE /cart/items/1' => (204, null),
      _ when key.startsWith('PATCH /cart/items/') => (
        200,
        _item(int.parse(options.path.split('/').last)),
      ),
      _ => (404, {'detail': 'nope'}),
    };
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

(ProviderContainer, _Adapter) _setup() {
  final adapter = _Adapter();
  final dio = Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
    ..httpClientAdapter = adapter;
  final c = ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
  addTearDown(c.dispose);
  return (c, adapter);
}

void main() {
  test('parses the reshaped cart: nested product, variant, shop', () async {
    final (c, _) = _setup();
    final cart = await c.read(cartProvider.future);
    expect(cart.status, CartStatus.active);
    expect(cart.items.single.product.title, 'P');
    expect(cart.items.single.shop.slug, 'silk');
    expect(cart.items.single.variant, isNull);
    expect(cart.itemCount, 1);
    expect(c.read(cartItemCountProvider), 1);
  });

  test(
    'cart loads only after the session check (guest: 401 is fine)',
    () async {
      final (c, adapter) = _setup();
      await c.read(cartProvider.future);
      expect(
        adapter.calls.indexOf('GET /auth/me'),
        lessThan(adapter.calls.indexOf('GET /cart')),
      );
    },
  );

  test('add posts the body and refetches the whole cart', () async {
    final (c, adapter) = _setup();
    await c.read(cartProvider.future);
    await c
        .read(cartProvider.notifier)
        .add(productId: 7, variantId: 9, quantity: 2);
    expect(adapter.bodies['POST /cart/items'], {
      'product_id': 7,
      'variant_id': 9,
      'quantity': 2,
    });
    expect(adapter.calls.where((k) => k == 'GET /cart'), hasLength(2));
  });

  test('remove and setQuantity hit the item paths', () async {
    final (c, adapter) = _setup();
    await c.read(cartProvider.future);
    await c.read(cartProvider.notifier).setQuantity(1, 3);
    await c.read(cartProvider.notifier).remove(1);
    expect(adapter.bodies['PATCH /cart/items/1'], {'quantity': 3});
    expect(adapter.calls, contains('DELETE /cart/items/1'));
  });

  test('a failed mutation throws and keeps the last cart', () async {
    final (c, adapter) = _setup();
    await c.read(cartProvider.future);
    await expectLater(
      c.read(cartProvider.notifier).remove(99),
      throwsA(isA<DioException>()),
    );
    expect(c.read(cartProvider).value!.items, hasLength(1));
    expect(adapter.calls.where((k) => k == 'GET /cart'), hasLength(1));
  });

  test('acceptPriceChanges patches only changed, available lines', () async {
    final (c, adapter) = _setup();
    adapter.cart = _cart([
      _item(1, quantity: 2, snapshot: '100.00', unit: '120.00'),
      _item(
        2,
        snapshot: '100.00',
        unit: '100.0',
      ), // same price, different spelling
      _item(3, snapshot: '100.00', unit: '90.00', available: false),
    ]);
    final cart = await c.read(cartProvider.future);
    expect(cart.priceChangedItems.map((i) => i.id), [1]);
    expect(cart.hasUnavailableItems, isTrue);

    await c.read(cartProvider.notifier).acceptPriceChanges();
    final patches = adapter.calls.where((k) => k.startsWith('PATCH'));
    expect(patches, ['PATCH /cart/items/1']);
    expect(adapter.bodies['PATCH /cart/items/1'], {'quantity': 2});
  });

  test('login reloads the cart with the merged guest lines', () async {
    final (c, adapter) = _setup();
    expect((await c.read(cartProvider.future)).items, hasLength(1));
    await c
        .read(sessionProvider.notifier)
        .login(email: 'a@b.uz', password: 'pw');
    final cart = await c.read(cartProvider.future);
    expect(cart.items, hasLength(2));
    expect(cart.items.last.variant!.attributes['size'], 2);
    expect(adapter.calls.where((k) => k == 'GET /cart'), hasLength(2));
  });
}
