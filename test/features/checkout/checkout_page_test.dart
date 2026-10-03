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
import 'package:market_app/features/checkout/presentation/checkout_page.dart';
import 'package:market_app/features/logistics/application/pickup_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

String t(String key, [Map<String, Object>? params]) =>
    translate(AppLocale.en, key, params);

Map<String, dynamic> _point(int id, String name, {int region = 1}) => {
  'id': id,
  'name': name,
  'address': {
    'street': 'Bunyodkor 1',
    'district': 'Chilonzor',
    'region': 'Toshkent',
    'landmark': 'Near the metro',
  },
  'latitude': '41.275',
  'longitude': '69.203',
  'type': 'platform_operated',
  'capacity_units': null,
  'status': 'active',
  'operating_hours': {
    'mon': '9-18',
    'tue': '9-18',
    'wed': '9-18',
    'thu': '9-18',
    'fri': '9-18',
    'sat': '10-16',
    'sun': '10-16',
  },
  'contact_phone': '+998901112233',
  'region_id': region,
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-01T10:00:00Z',
};

Map<String, dynamic> _line(
  int id, {
  String price = '100000.00',
  String? snapshot,
  bool available = true,
  int quantity = 1,
}) => {
  'id': id,
  'quantity': quantity,
  'added_at': '2026-10-01T10:00:00Z',
  'product': {
    'id': id + 100,
    'slug': 'p$id',
    'title': 'Product $id',
    'image_url': null,
  },
  'variant': null,
  'shop': {'id': 1, 'slug': 's', 'name': 'Shop', 'logo_url': null},
  'price_snapshot': snapshot ?? price,
  'unit_price': price,
  'line_total': (double.parse(price) * quantity).toStringAsFixed(2),
  'available': available,
  'in_stock': true,
};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.lines);

  List<Map<String, dynamic>> lines;
  Map<String, dynamic>? lastUsed;
  (int, Object?) checkout = (
    200,
    {'order_id': 9, 'order_number': 'ORD-9', 'payment_redirect_url': null},
  );
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
    (int, Object?) result = (404, {});
    if (key == 'GET /auth/me') {
      result = (
        200,
        {
          'id': 4,
          'email': 'a@b.uz',
          'full_name': 'Ali Valiyev',
          'is_active': true,
        },
      );
    } else if (key == 'GET /cart') {
      result = (
        200,
        {
          'id': 1,
          'status': 'active',
          'items': lines,
          'item_count': lines.fold<int>(
            0,
            (n, l) => n + (l['quantity'] as int),
          ),
          'subtotal': lines
              .where((l) => l['available'] as bool)
              .fold<double>(
                0,
                (n, l) => n + double.parse(l['line_total'] as String),
              )
              .toStringAsFixed(2),
          'created_at': '2026-10-01T10:00:00Z',
          'updated_at': '2026-10-01T10:00:00Z',
        },
      );
    } else if (key == 'GET /pickup-points/last-used') {
      result = (200, lastUsed);
    } else if (key == 'GET /regions') {
      result = (
        200,
        [
          {'id': 1, 'name': 'Toshkent', 'code': null},
          {'id': 2, 'name': 'Samarkand', 'code': null},
        ],
      );
    } else if (key == 'GET /pickup-points') {
      final region = options.queryParameters['region_id'];
      result = (
        200,
        [
          if (region == 1)
            _point(11, 'Chilonzor point')
          else
            _point(21, 'Registan point', region: 2),
        ],
      );
    } else if (key == 'POST /checkout') {
      result = checkout;
      if (checkout.$1 == 200) lines = [];
    } else if (key.startsWith('PATCH /cart/items/')) {
      final id = int.parse(options.path.split('/').last);
      final line = lines.firstWhere((l) => l['id'] == id);
      line['price_snapshot'] = line['unit_price'];
      result = (200, line);
    }
    return ResponseBody.fromString(
      jsonEncode(result.$2),
      result.$1,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ProviderContainer, _Adapter, SharedPreferences)> _pump(
  WidgetTester tester,
  List<Map<String, dynamic>> lines, {
  Map<String, dynamic>? lastUsed,
  Map<String, Object> prefs = const {},
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'locale': 'en', ...prefs});
  final store = await SharedPreferences.getInstance();
  final adapter = _Adapter(lines)..lastUsed = lastUsed;
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(store),
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
  c.read(routerProvider).go('/checkout');
  await tester.pumpAndSettle();
  return (c, adapter, store);
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('phone check mirrors the storefront: 9 to 15 digits', () {
    expect(isPlausiblePhone('+998 90 123-45-67'), isTrue);
    expect(isPlausiblePhone('+998 '), isFalse);
    expect(isPlausiblePhone('12345678'), isFalse);
    expect(isPlausiblePhone('1' * 16), isFalse);
  });

  test("today's hours from free-form JSON", () {
    final hours = {'mon': '9-18', 'sun': ' ', 'sat': 5, 'fri': '9-13'};
    expect(todaysHours(hours, DateTime(2026, 10, 5)), '9–18'); // Monday
    expect(todaysHours(hours, DateTime(2026, 10, 9)), '9–13'); // Friday
    expect(todaysHours(hours, DateTime(2026, 10, 4)), isNull); // Sunday: blank
    expect(
      todaysHours(hours, DateTime(2026, 10, 3)),
      isNull,
    ); // Saturday: not a string
    expect(
      todaysHours(hours, DateTime(2026, 10, 6)),
      isNull,
    ); // Tuesday: missing
  });

  testWidgets('pre-selects the last-used point and prefills the recipient', (
    tester,
  ) async {
    await _pump(tester, [_line(1)], lastUsed: _point(11, 'Chilonzor point'));
    expect(find.text('Chilonzor point'), findsOneWidget);
    expect(find.text(t('checkout.lastUsedNote')), findsOneWidget);
    expect(find.text('Ali Valiyev'), findsOneWidget);
    expect(find.text('+998 '), findsOneWidget);
    expect(find.text(t('checkout.cashAtPoint')), findsOneWidget);
    expect(find.text(formatMoney('100000.00', 'en-US')), findsWidgets);
  });

  testWidgets('without a last-used point: choose one by region', (
    tester,
  ) async {
    await _pump(tester, [_line(1)]);
    expect(find.text(t('checkout.lastUsedNote')), findsNothing);
    await _tap(tester, find.text(t('checkout.choosePoint')));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Samarkand').last);
    await tester.pumpAndSettle();
    expect(find.text('Registan point'), findsOneWidget);
    expect(
      find
              .text(t('checkout.todayHours', {'hours': '10–16'}))
              .evaluate()
              .length +
          find.text(t('checkout.hoursUnknown')).evaluate().length,
      1,
    );
    await tester.tap(find.text('Registan point'));
    await tester.pumpAndSettle();
    expect(find.text('Registan point'), findsOneWidget);
    expect(find.text(t('checkout.change')), findsOneWidget);
    expect(find.text(t('checkout.lastUsedNote')), findsNothing);
  });

  testWidgets('an empty form shows what is missing and sends nothing', (
    tester,
  ) async {
    final (_, adapter, _) = await _pump(
      tester,
      [_line(1)],
      prefs: {'checkout.recipient.name': ''},
    );
    await tester.enterText(_field(t('checkout.fullName')), '');
    await _tap(tester, find.text(t('checkout.placeOrder')));
    expect(find.text(t('checkout.nameRequired')), findsOneWidget);
    expect(find.text(t('checkout.phoneInvalid')), findsOneWidget);
    expect(find.text(t('checkout.pointRequired')), findsOneWidget);
    expect(adapter.calls, isNot(contains('POST /checkout')));
  });

  testWidgets(
    'placing the order sends the recipient and point, then opens the order',
    (tester) async {
      final (c, adapter, store) = await _pump(tester, [
        _line(1),
      ], lastUsed: _point(11, 'Chilonzor point'));
      await tester.enterText(_field(t('checkout.fullName')), '  Ali Valiyev ');
      await tester.enterText(_field(t('checkout.phone')), '+998 90 123-45-67');
      await tester.enterText(_field(t('checkout.notes')), '  after 6pm ');
      await _tap(tester, find.text(t('checkout.placeOrder')));
      expect(adapter.bodies['POST /checkout'], {
        'recipient': {
          'full_name': 'Ali Valiyev',
          'phone': '+998 90 123-45-67',
          'notes': 'after 6pm',
        },
        'pickup_point_id': 11,
        'payment_method': 'cash_on_delivery',
      });
      // The recipient is remembered for next time; the cart was reloaded (now empty).
      expect(store.getString('checkout.recipient.name'), 'Ali Valiyev');
      expect(store.getString('checkout.recipient.phone'), '+998 90 123-45-67');
      expect(
        adapter.calls.where((k) => k == 'GET /cart').length,
        greaterThan(1),
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(t('nav.orders')),
        ),
        findsOneWidget,
      );
      expect(
        c
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .toString(),
        '/orders/9?placed=1',
      );
    },
  );

  testWidgets(
    'a price change shows old and new; accepting re-saves the line and places',
    (tester) async {
      final (_, adapter, _) = await _pump(tester, [
        _line(1),
      ], lastUsed: _point(11, 'Chilonzor point'));
      adapter.checkout = (
        400,
        {
          'detail': {
            'error': 'price_changed',
            'items': [
              {
                'product_id': 101,
                'variant_id': null,
                'old_price': '100000.00',
                'new_price': '120000.00',
              },
            ],
          },
        },
      );
      adapter.lines = [_line(1, price: '120000.00', snapshot: '100000.00')];
      await tester.enterText(_field(t('checkout.phone')), '+998 90 123-45-67');
      await _tap(tester, find.text(t('checkout.placeOrder')));
      // Still on checkout: the first attempt was refused with price_changed.
      expect(find.text(t('checkout.pricesChanged')), findsOneWidget);
      expect(find.textContaining('Product 1'), findsWidgets);
      expect(
        find.textContaining(formatMoney('120000.00', 'en-US')),
        findsWidgets,
      );

      adapter.checkout = (200, {'order_id': 9, 'order_number': 'ORD-9'});
      await _tap(tester, find.text(t('checkout.acceptAndPlace')));
      expect(adapter.calls, contains('PATCH /cart/items/1'));
      expect(adapter.calls.where((k) => k == 'POST /checkout'), hasLength(2));
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text(t('nav.orders')),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a closed pickup point shows the backend message and stays', (
    tester,
  ) async {
    final (_, adapter, _) = await _pump(tester, [
      _line(1),
    ], lastUsed: _point(11, 'Chilonzor point'));
    adapter.checkout = (
      400,
      {'detail': "This pickup point isn't available — choose another one"},
    );
    await tester.enterText(_field(t('checkout.phone')), '+998 90 123-45-67');
    await _tap(tester, find.text(t('checkout.placeOrder')));
    expect(
      find.text("This pickup point isn't available — choose another one"),
      findsOneWidget,
    );
    expect(find.text(t('checkout.placeOrder')), findsOneWidget);
  });

  testWidgets('an unavailable line blocks placing the order', (tester) async {
    await _pump(tester, [
      _line(1),
      _line(2, available: false),
    ], lastUsed: _point(11, 'Chilonzor point'));
    expect(find.text(t('checkout.fixCart')), findsOneWidget);
    final place = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(t('checkout.placeOrder')),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(place.onPressed, isNull);
  });

  testWidgets('an empty cart has nothing to check out', (tester) async {
    await _pump(tester, []);
    expect(find.text(t('checkout.emptyBody')), findsOneWidget);
  });
}
