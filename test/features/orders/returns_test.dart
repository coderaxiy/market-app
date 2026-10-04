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
import 'package:market_app/features/orders/application/photo_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

String t(String key, [Map<String, Object>? params]) =>
    translate(AppLocale.en, key, params);

const _point = {
  'id': 5,
  'name': 'Chilonzor point',
  'address': {'street': 'Bunyodkor 1', 'district': 'Chilonzor'},
  'latitude': '41.275',
  'longitude': '69.203',
  'operating_hours': {'mon': '9-18'},
  'contact_phone': '+998901112233',
};

final _future = DateTime.now()
    .toUtc()
    .add(const Duration(days: 7))
    .toIso8601String();
final _past = DateTime.now()
    .toUtc()
    .subtract(const Duration(days: 7))
    .toIso8601String();

Map<String, dynamic> _request(
  String status, {
  String? escalatedAt,
  String? note,
  Map<String, dynamic>? point,
}) => {
  'id': 40,
  'status': status,
  'reason_code': 'defective',
  'created_at': '2026-09-05T10:00:00Z',
  'resolved_at': null,
  'escalated_at': escalatedAt,
  'resolution_note': note,
  'return_point': point,
  'point_received_at': null,
};

Map<String, dynamic> _order({
  String lineStatus = 'active',
  String? deadline,
  Map<String, dynamic>? request,
}) => {
  'id': 9,
  'buyer_id': 4,
  'order_number': 'ORD-9',
  'status': 'completed',
  'total_amount': '100000.00',
  'recipient': {'full_name': 'Ali', 'phone': '+998901234567', 'notes': null},
  'pickup_point': _point,
  'payment_method': 'cash_on_delivery',
  'payment_reference': null,
  'placed_at': '2026-10-01T10:00:00Z',
  'created_at': '2026-10-01T10:00:00Z',
  'updated_at': '2026-10-01T10:00:00Z',
  'groups': [
    {
      'id': 3,
      'order_id': 9,
      'shop_id': 1,
      'status': 'delivered',
      'subtotal': '100000.00',
      'shipping_fee': '0.00',
      'cancellation_reason': null,
      'warehouse_received_at': null,
      'delivered_at': '2026-10-03T10:00:00Z',
      'created_at': '2026-09-01T10:00:00Z',
      'updated_at': '2026-09-01T10:00:00Z',
      'shop': {'id': 1, 'slug': 's', 'name': 'Silk', 'logo_url': null},
      'lines': [
        {
          'id': 1,
          'product_id': 7,
          'variant_id': null,
          'product_title_snapshot': 'Suzani',
          'platform_sku_snapshot': 'PSK-1',
          'unit_price': '100000.00',
          'quantity': 1,
          'line_total': '100000.00',
          'status': lineStatus,
          'physical_return_received_at': null,
          'created_at': '2026-09-01T10:00:00Z',
          'image_url': null,
          'variant_attributes': null,
          'product_slug': 'suzani',
          'return_deadline': deadline,
          'refund_request': request,
        },
      ],
    },
  ],
};

Map<String, dynamic> _refund(String status, {String? escalatedAt}) => {
  'id': 40,
  'order_line_id': 1,
  'requested_by': 'buyer',
  'requester_user_id': 4,
  'reason_code': 'defective',
  'reason_text': null,
  'status': status,
  'refund_amount': '100000.00',
  'who_bears_cost': null,
  'evidence_urls': null,
  'resolved_by': null,
  'resolved_at': null,
  'escalated_at': escalatedAt,
  'resolution_note': null,
  'point_received_at': null,
  'created_at': '2026-09-05T10:00:00Z',
  'evidence': <Object>[],
};

class _Picker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick(PhotoSource source) async =>
      PickedPhoto(bytes: Uint8List.fromList([1, 2, 3]), filename: 'p.jpg');
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.order);

  Map<String, dynamic> order;
  (int, Object?) upload = (
    201,
    {
      'id': 1,
      'key': 'refunds/evidence/4/abc.webp',
      'url': 'http://signed/abc',
      'purpose': 'refund_evidence',
      'content_type': 'image/webp',
      'size_bytes': 10,
      'width': 10,
      'height': 10,
      'created_at': '2026-10-04T10:00:00Z',
    },
  );
  (int, Object?) refund = (201, _refund('pending'));
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
    } else if (key == 'GET /orders/9') {
      result = (200, order);
    } else if (key == 'POST /uploads') {
      result = upload;
    } else if (key == 'POST /order-lines/1/refund-request') {
      result = refund;
    } else if (key == 'POST /refund-requests/40/escalate') {
      result = (
        200,
        _refund('escalated_to_admin', escalatedAt: '2026-10-04T10:00:00Z'),
      );
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

Future<_Adapter> _pump(WidgetTester tester, Map<String, dynamic> order) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'locale': 'en'});
  final adapter = _Adapter(order);
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      dioProvider.overrideWithValue(
        Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
          ..httpClientAdapter = adapter,
      ),
      photoPickerProvider.overrideWithValue(_Picker()),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const MarketApp()),
  );
  await tester.pumpAndSettle();
  c.read(routerProvider).go('/orders/9');
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  testWidgets(
    'inside the return window: deadline and button; after it: nothing',
    (tester) async {
      await _pump(tester, _order(deadline: _future));
      expect(find.text(t('return.button')), findsOneWidget);
      expect(
        find.text(
          t('return.deadline', {'date': formatDate(DateTime.parse(_future))}),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a closed window offers nothing', (tester) async {
    await _pump(tester, _order(deadline: _past));
    expect(find.text(t('return.button')), findsNothing);
  });

  testWidgets(
    'sending a request uploads the photo first, then sends the keys',
    (tester) async {
      final adapter = await _pump(tester, _order(deadline: _future));
      await tester.tap(find.text(t('return.button')));
      await tester.pumpAndSettle();
      expect(find.text(t('return.title')), findsOneWidget);
      expect(find.text(t('return.refundNote')), findsOneWidget);

      await tester.tap(find.text(t('return.reasonNotAsDescribed')));
      await tester.enterText(
        find.widgetWithText(TextField, t('return.details')),
        '  stained ',
      );
      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t('return.gallery')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(t('return.submit')));
      await tester.tap(find.text(t('return.submit')));
      await tester.pumpAndSettle();

      expect(
        adapter.calls.indexOf('POST /uploads'),
        lessThan(adapter.calls.indexOf('POST /order-lines/1/refund-request')),
      );
      expect(adapter.bodies['POST /order-lines/1/refund-request'], {
        'reason_code': 'not_as_described',
        'reason_text': 'stained',
        'evidence_keys': ['refunds/evidence/4/abc.webp'],
      });
      expect(find.text(t('return.sent')), findsOneWidget);
      // The order was reloaded after the request.
      expect(
        adapter.calls.where((k) => k == 'GET /orders/9').length,
        greaterThan(1),
      );
    },
  );

  testWidgets('"Other" needs a few words', (tester) async {
    final adapter = await _pump(tester, _order(deadline: _future));
    await tester.tap(find.text(t('return.button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('return.reasonOther')));
    await tester.ensureVisible(find.text(t('return.submit')));
    await tester.tap(find.text(t('return.submit')));
    await tester.pumpAndSettle();
    expect(find.text(t('return.detailsRequired')), findsOneWidget);
    expect(
      adapter.calls,
      isNot(contains('POST /order-lines/1/refund-request')),
    );
  });

  testWidgets('a failed photo upload stops the request and says why', (
    tester,
  ) async {
    final adapter = await _pump(tester, _order(deadline: _future));
    adapter.upload = (
      400,
      {'detail': 'Too many uploads today — try again tomorrow'},
    );
    await tester.tap(find.text(t('return.button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t('return.camera')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(t('return.submit')));
    await tester.tap(find.text(t('return.submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Too many uploads today — try again tomorrow'),
      findsOneWidget,
    );
    expect(
      adapter.calls,
      isNot(contains('POST /order-lines/1/refund-request')),
    );
  });

  testWidgets('a pending request blocks a new one', (tester) async {
    await _pump(
      tester,
      _order(deadline: _future, request: _request('pending')),
    );
    expect(find.text(t('return.requested')), findsOneWidget);
    expect(find.text(t('return.button')), findsNothing);
  });

  testWidgets('a rejected request shows the reason and can be escalated once', (
    tester,
  ) async {
    final adapter = await _pump(
      tester,
      _order(
        deadline: _future,
        request: _request('rejected', note: 'Item was used'),
      ),
    );
    expect(find.text(t('return.rejected')), findsOneWidget);
    expect(
      find.text(t('return.rejectedReason', {'reason': 'Item was used'})),
      findsOneWidget,
    );
    await tester.tap(find.text(t('return.escalate')));
    await tester.pumpAndSettle();
    expect(adapter.calls, contains('POST /refund-requests/40/escalate'));
    expect(find.text(t('return.escalated')), findsOneWidget);
  });

  testWidgets('an escalated rejection is final', (tester) async {
    await _pump(
      tester,
      _order(
        deadline: _past,
        request: _request(
          'rejected',
          escalatedAt: '2026-10-02T10:00:00Z',
          note: 'No',
        ),
      ),
    );
    expect(find.text(t('return.final')), findsOneWidget);
    expect(find.text(t('return.escalate')), findsNothing);
  });

  testWidgets('approved: bring the item to the point', (tester) async {
    await _pump(
      tester,
      _order(
        lineStatus: 'return_pending',
        deadline: _future,
        request: _request('approved', point: _point),
      ),
    );
    expect(
      find.text(t('return.bringTo', {'name': 'Chilonzor point'})),
      findsOneWidget,
    );
    expect(find.text(t('return.bringHint')), findsOneWidget);
    expect(find.text(t('return.button')), findsNothing);
  });

  testWidgets('handed in, and refunded', (tester) async {
    await _pump(
      tester,
      _order(
        lineStatus: 'returned_to_point',
        deadline: _future,
        request: _request('approved'),
      ),
    );
    expect(find.text(t('return.handedIn')), findsOneWidget);
  });

  testWidgets('refunded shows it', (tester) async {
    await _pump(
      tester,
      _order(
        lineStatus: 'refunded',
        deadline: _future,
        request: _request('approved'),
      ),
    );
    expect(find.text(t('return.refunded')), findsOneWidget);
    expect(formatMoney('100000.00', 'en-US').isNotEmpty, isTrue);
  });
}
