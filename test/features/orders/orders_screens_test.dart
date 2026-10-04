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
import 'package:market_app/features/orders/application/orders_logic.dart';
import 'package:market_app/features/orders/data/order.dart';
import 'package:shared_preferences/shared_preferences.dart';

String t(String key, [Map<String, Object>? params]) =>
    translate(AppLocale.en, key, params);

const _point = {
  'id': 5,
  'name': 'Chilonzor point',
  'address': {
    'street': 'Bunyodkor 1',
    'district': 'Chilonzor',
    'region': 'Toshkent',
  },
  'latitude': '41.275',
  'longitude': '69.203',
  'operating_hours': {'mon': '9-18'},
  'contact_phone': '+998901112233',
};

Map<String, dynamic> _line(int id, String title, {int quantity = 1}) => {
  'id': id,
  'product_id': id,
  'variant_id': null,
  'product_title_snapshot': title,
  'platform_sku_snapshot': 'PSK-$id',
  'unit_price': '100000.00',
  'quantity': quantity,
  'line_total': '${100000 * quantity}.00',
  'status': 'active',
  'physical_return_received_at': null,
  'created_at': '2026-09-01T10:00:00Z',
  'image_url': null,
  'variant_attributes': null,
  'product_slug': 'p$id',
  'return_deadline': null,
  'refund_request': null,
};

Map<String, dynamic> _group(
  int id,
  String shop,
  String status,
  List<Map<String, dynamic>> lines, {
  String? reason,
}) => {
  'id': id,
  'order_id': 9,
  'shop_id': id,
  'status': status,
  'subtotal': '100000.00',
  'shipping_fee': '0.00',
  'cancellation_reason': reason,
  'warehouse_received_at': null,
  'delivered_at': null,
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-01T10:00:00Z',
  'shop': {'id': id, 'slug': 's$id', 'name': shop, 'logo_url': null},
  'lines': lines,
};

Map<String, dynamic> _order(
  int id,
  String status,
  List<Map<String, dynamic>> groups, {
  String payment = 'cash_on_delivery',
}) => {
  'id': id,
  'buyer_id': 4,
  'order_number': 'ORD-2026-00000$id',
  'status': status,
  'total_amount': '300000.00',
  'recipient': {
    'full_name': 'Ali Valiyev',
    'phone': '+998901234567',
    'notes': null,
  },
  'pickup_point': _point,
  'payment_method': payment,
  'payment_reference': null,
  'placed_at': '2026-10-01T10:00:00Z',
  'created_at': '2026-10-01T10:00:00Z',
  'updated_at': '2026-10-01T10:00:00Z',
  'groups': groups,
};

class _Adapter implements HttpClientAdapter {
  _Adapter();

  final orders = <Map<String, dynamic>>[];
  int total = 0;
  Map<String, dynamic>? detail;
  (int, Object?) cancel = (
    200,
    _group(3, 'Silk', 'cancelled', [
      _line(1, 'Suzani'),
    ], reason: 'I changed my mind'),
  );
  (int, Object?) pickupStatus = (404, {'detail': 'not yet'});
  final calls = <String>[];
  final queries = <Uri>[];
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
    var headers = <String, List<String>>{};
    (int, Object?) result = (404, {});
    if (key == 'GET /auth/me') {
      result = (200, {'id': 4, 'email': 'a@b.uz', 'is_active': true});
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
    } else if (key == 'GET /orders') {
      queries.add(options.uri);
      final skip = options.queryParameters['skip'] as int? ?? 0;
      final limit = options.queryParameters['limit'] as int? ?? 50;
      final end = (skip + limit).clamp(0, orders.length);
      result = (200, orders.sublist(skip.clamp(0, orders.length), end));
      headers = {
        'x-total-count': ['${total == 0 ? orders.length : total}'],
      };
    } else if (key == 'GET /orders/9') {
      result = detail == null
          ? (404, {'detail': 'Order not found'})
          : (200, detail);
    } else if (key == 'POST /orders/9/groups/3/cancel') {
      result = cancel;
      if (cancel.$1 == 200) {
        detail = _order(9, 'cancelled', [
          _group(3, 'Silk', 'cancelled', [
            _line(1, 'Suzani'),
          ], reason: 'I changed my mind'),
        ]);
      }
    } else if (key == 'GET /orders/9/groups/3/pickup-status') {
      result = pickupStatus;
    }
    return ResponseBody.fromString(
      jsonEncode(result.$2),
      result.$1,
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
  return (c, adapter);
}

void main() {
  group('logic', () {
    test(
      'tabs: completed, cancelled (incl. payment failed), the rest active',
      () {
        expect(orderTab(OrderStatus.completed), OrderTab.completed);
        expect(orderTab(OrderStatus.cancelled), OrderTab.cancelled);
        expect(orderTab(OrderStatus.paymentFailed), OrderTab.cancelled);
        expect(orderTab(OrderStatus.paid), OrderTab.active);
        expect(orderTab(OrderStatus.pendingPayment), OrderTab.active);
        expect(statusesForTab(OrderTab.all), isEmpty);
        expect(statusesForTab(OrderTab.cancelled), [
          OrderStatus.cancelled,
          OrderStatus.paymentFailed,
        ]);
      },
    );

    test(
      'group progress follows the delivery path; off-path groups have none',
      () {
        expect(groupProgress(OrderShopGroupStatus.pending), 0);
        expect(groupProgress(OrderShopGroupStatus.atWarehouse), 3);
        expect(groupProgress(OrderShopGroupStatus.arrivedAtPoint), 5);
        expect(groupProgress(OrderShopGroupStatus.delivered), 6);
        expect(groupProgress(OrderShopGroupStatus.refunded), 6);
        expect(groupProgress(OrderShopGroupStatus.cancelled), isNull);
        expect(groupProgress(OrderShopGroupStatus.unknown), isNull);
        expect(trackerStep(0, 2), TrackerStep.done);
        expect(trackerStep(2, 2), TrackerStep.current);
        expect(trackerStep(3, 2), TrackerStep.upcoming);
      },
    );

    test('every status has a label that exists in all languages', () {
      for (final status in OrderStatus.values) {
        for (final locale in AppLocale.values) {
          final key = orderStatusInfo(status).label;
          expect(translate(locale, key), isNot(key), reason: '$locale $key');
        }
      }
      for (final status in OrderShopGroupStatus.values) {
        for (final locale in AppLocale.values) {
          final key = groupStatusInfo(status).label;
          expect(translate(locale, key), isNot(key), reason: '$locale $key');
        }
      }
    });

    test('date formats', () {
      final moment = DateTime(2026, 10, 4, 9, 5);
      expect(formatDateTime(moment), '04.10.2026 09:05');
      expect(formatDate(moment), '04.10.2026');
    });
  });

  testWidgets('orders list: cards, tabs filter on the server, empty tab', (
    tester,
  ) async {
    final adapter = _Adapter()
      ..orders.addAll([
        _order(9, 'paid', [
          _group(3, 'Silk', 'confirmed', [
            _line(1, 'Suzani', quantity: 2),
            _line(2, 'Rug'),
            _line(3, 'Mug'),
            _line(4, 'Plate'),
          ]),
        ]),
      ]);
    await _pump(tester, adapter, '/orders');
    expect(find.text('ORD-2026-000009'), findsOneWidget);
    expect(find.text(t('order.statusConfirmed')), findsOneWidget);
    expect(find.text(t('order.groupConfirmed')), findsOneWidget);
    expect(find.text('Suzani × 2'), findsOneWidget);
    expect(find.text(t('orders.moreItems', {'count': 1})), findsOneWidget);
    expect(find.text(t('cart.itemCount', {'count': 5})), findsOneWidget);
    expect(find.text(formatMoney('300000.00', 'en-US')), findsOneWidget);

    adapter.orders.clear();
    await tester.tap(find.text(t('orders.tabCompleted')));
    await tester.pumpAndSettle();
    expect(adapter.queries.last.query, contains('status=completed'));
    expect(find.text(t('orders.tabEmpty')), findsOneWidget);
  });

  testWidgets('no orders at all: message and a way to shop', (tester) async {
    await _pump(tester, _Adapter(), '/orders');
    expect(find.textContaining(t('orders.emptyTitle')), findsOneWidget);
    expect(find.text(t('order.continueShopping')), findsOneWidget);
  });

  testWidgets('scrolling loads the next page of orders', (tester) async {
    final adapter = _Adapter();
    for (var i = 0; i < 25; i++) {
      adapter.orders.add({
        ..._order(9, 'paid', [
          _group(3, 'Silk', 'confirmed', [_line(1, 'Item $i')]),
        ]),
        'id': 100 + i,
        'order_number': 'ORD-$i',
      });
    }
    await _pump(tester, adapter, '/orders');
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await tester.pumpAndSettle();
    }
    final skips = adapter.queries
        .map((u) => u.queryParameters['skip'] ?? '0')
        .toList();
    expect(skips, ['0', '20']);
    expect(find.text('ORD-24'), findsOneWidget);
  });

  testWidgets(
    'order detail: point, recipient, shipments with tracker, lines, total',
    (tester) async {
      final adapter = _Adapter()
        ..detail = _order(9, 'paid', [
          _group(3, 'Silk', 'shipped', [_line(1, 'Suzani', quantity: 2)]),
          _group(4, 'Wood', 'pending', [_line(2, 'Spoon')]),
        ]);
      await _pump(tester, adapter, '/orders/9');
      expect(find.text('Chilonzor point'), findsOneWidget);
      expect(find.text('Ali Valiyev, +998901234567'), findsOneWidget);
      expect(
        find.text('Silk · ${t('order.shipmentOf', {'index': 1, 'total': 2})}'),
        findsOneWidget,
      );
      expect(find.text(t('order.groupShipped')), findsOneWidget);
      expect(find.text(t('order.stepOnTheWay')), findsNWidgets(2));
      expect(
        find.text('2 × ${formatMoney('100000.00', 'en-US')}'),
        findsOneWidget,
      );
      expect(find.text(t('order.cashNote')), findsOneWidget);
      expect(find.text(t('order.placedTitle')), findsNothing);
      // Only the shipment the shop hasn't started yet can be cancelled.
      expect(find.text(t('cancel.button')), findsOneWidget);
      // Not at the point yet: its status is not even requested.
      expect(
        adapter.calls,
        isNot(contains('GET /orders/9/groups/3/pickup-status')),
      );
    },
  );

  testWidgets('right after checkout the page opens with the thank-you banner', (
    tester,
  ) async {
    final adapter = _Adapter()
      ..detail = _order(9, 'paid', [
        _group(3, 'Silk', 'pending', [_line(1, 'Suzani')]),
      ]);
    await _pump(tester, adapter, '/orders/9?placed=1');
    expect(find.text(t('order.placedTitle')), findsOneWidget);
    expect(find.text(t('order.placedBody')), findsOneWidget);
  });

  testWidgets('a group at the pickup point shows its collection deadline', (
    tester,
  ) async {
    final adapter = _Adapter()
      ..detail = _order(9, 'paid', [
        _group(3, 'Silk', 'arrived_at_point', [_line(1, 'Suzani')]),
      ])
      ..pickupStatus = (
        200,
        {
          'order_shop_group_id': 3,
          'pickup_point_id': 5,
          'holding_status': 'holding',
          'arrived_at': '2026-10-02T08:00:00Z',
          'collection_deadline': '2026-10-09T08:00:00Z',
          'items': [
            {
              'order_line_id': 1,
              'quantity': 1,
              'quantity_collected': 0,
              'status': 'holding',
            },
          ],
        },
      );
    await _pump(tester, adapter, '/orders/9');
    expect(find.text(t('order.groupReady')), findsOneWidget);
    expect(
      find.text(
        t('order.readyUntil', {
          'date': formatDateTime(DateTime.utc(2026, 10, 9, 8)),
        }),
      ),
      findsOneWidget,
    );
    expect(find.text(t('cancel.button')), findsNothing);
  });

  testWidgets(
    'cancelling a shipment sends the chosen reason and reloads the order',
    (tester) async {
      final adapter = _Adapter()
        ..detail = _order(9, 'paid', [
          _group(3, 'Silk', 'pending', [_line(1, 'Suzani')]),
        ]);
      await _pump(tester, adapter, '/orders/9');
      await tester.tap(find.text(t('cancel.button')));
      await tester.pumpAndSettle();
      expect(find.text(t('cancel.title')), findsOneWidget);
      await tester.tap(find.text(t('cancel.confirm')));
      await tester.pumpAndSettle();
      expect(adapter.bodies['POST /orders/9/groups/3/cancel'], {
        'reason': t('cancel.reasonChangedMind'),
      });
      // The order was re-fetched: it is cancelled now, with its reason.
      expect(find.text(t('order.statusCancelled')), findsWidgets);
      expect(
        find.text(t('order.cancelReason', {'reason': 'I changed my mind'})),
        findsOneWidget,
      );
      expect(find.text(t('cancel.button')), findsNothing);
    },
  );

  testWidgets('"Other" needs the buyer to say why', (tester) async {
    final adapter = _Adapter()
      ..detail = _order(9, 'paid', [
        _group(3, 'Silk', 'pending', [_line(1, 'Suzani')]),
      ]);
    await _pump(tester, adapter, '/orders/9');
    await tester.tap(find.text(t('cancel.button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('cancel.reasonOther')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('cancel.confirm')));
    await tester.pumpAndSettle();
    expect(adapter.calls, isNot(contains('POST /orders/9/groups/3/cancel')));
    await tester.enterText(find.byType(TextField), '  too slow ');
    await tester.tap(find.text(t('cancel.confirm')));
    await tester.pumpAndSettle();
    expect(adapter.bodies['POST /orders/9/groups/3/cancel'], {
      'reason': 'too slow',
    });
  });

  testWidgets('a refused cancel shows the backend message', (tester) async {
    final adapter = _Adapter()
      ..detail = _order(9, 'paid', [
        _group(3, 'Silk', 'pending', [_line(1, 'Suzani')]),
      ])
      ..cancel = (
        400,
        {'detail': 'The shop already started preparing this shipment'},
      );
    await _pump(tester, adapter, '/orders/9');
    await tester.tap(find.text(t('cancel.button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('cancel.confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('The shop already started preparing this shipment'),
      findsOneWidget,
    );
  });

  testWidgets('an unknown order shows not found', (tester) async {
    await _pump(tester, _Adapter(), '/orders/9');
    expect(find.text(t('notFound.body')), findsOneWidget);
  });
}
