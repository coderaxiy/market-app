import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/features/orders/data/order.dart';
import 'package:market_app/features/orders/data/order_repository.dart';
import 'package:market_app/features/orders/data/refund.dart';
import 'package:market_app/features/uploads/data/upload_repository.dart';

const _point = {
  'id': 5,
  'name': 'Chilonzor point',
  'address': {'street': 'Bunyodkor 1'},
  'latitude': '41.275000',
  'longitude': '69.203000',
  'operating_hours': {'mon': '9-18'},
  'contact_phone': '+998901234567',
};

Map<String, dynamic> _line({
  int id = 1,
  String status = 'active',
  String? deadline,
  Map<String, dynamic>? request,
}) => {
  'id': id,
  'product_id': 7,
  'variant_id': null,
  'product_title_snapshot': 'Suzani',
  'platform_sku_snapshot': 'PSK-8F3K2Q',
  'unit_price': '100000.00',
  'quantity': 2,
  'line_total': '200000.00',
  'status': status,
  'physical_return_received_at': null,
  'created_at': '2026-09-01T10:00:00Z',
  'image_url': null,
  'variant_attributes': {'color': 'red', 'size': 2},
  'product_slug': 'suzani',
  'return_deadline': deadline,
  'refund_request': request,
};

Map<String, dynamic> _request(
  String status, {
  String? escalatedAt,
  String? note,
}) => {
  'id': 40,
  'status': status,
  'reason_code': 'defective',
  'created_at': '2026-09-05T10:00:00Z',
  'resolved_at': null,
  'escalated_at': escalatedAt,
  'resolution_note': note,
  'return_point': null,
  'point_received_at': null,
};

Map<String, dynamic> _group(
  List<Map<String, dynamic>> lines, {
  String status = 'delivered',
}) => {
  'id': 3,
  'order_id': 9,
  'shop_id': 1,
  'status': status,
  'subtotal': '200000.00',
  'shipping_fee': '0.00',
  'cancellation_reason': null,
  'warehouse_received_at': null,
  'delivered_at': null,
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-01T10:00:00Z',
  'shop': {'id': 1, 'slug': 'silk', 'name': 'Silk', 'logo_url': null},
  'lines': lines,
};

Map<String, dynamic> _order(List<Map<String, dynamic>> groups) => {
  'id': 9,
  'buyer_id': 4,
  'order_number': 'ORD-2026-000009',
  'status': 'paid',
  'total_amount': '200000.00',
  'recipient': {'full_name': 'Ali', 'phone': '+998901234567', 'notes': null},
  'pickup_point': _point,
  'payment_method': 'cash_on_delivery',
  'payment_reference': null,
  'placed_at': '2026-09-01T10:00:00Z',
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-01T10:00:00Z',
  'groups': groups,
};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body, {this.headers = const {}});

  final int status;
  final Object? body;
  final Map<String, List<String>> headers;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
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

Dio _dio(_Adapter a) =>
    Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = a;

final _now = DateTime.utc(2026, 10, 1);
const _future = '2026-10-10T00:00:00Z';
const _past = '2026-09-20T00:00:00Z';

OrderLineRead _read(Map<String, dynamic> json) => OrderLineRead.fromJson(json);

void main() {
  test(
    'order parses recipient, pickup point, groups, lines, snapshot SKU',
    () async {
      final adapter = _Adapter(
        200,
        _order([
          _group([_line()]),
        ]),
      );
      final order = await OrderRepository(_dio(adapter)).order(9);
      expect(order.status, OrderStatus.paid);
      expect(order.recipient.fullName, 'Ali');
      expect(order.pickupPoint!.latitude, 41.275);
      final group = order.groups.single;
      expect(group.shop.slug, 'silk');
      expect(group.status, OrderShopGroupStatus.delivered);
      final line = group.lines.single;
      expect(line.platformSkuSnapshot, 'PSK-8F3K2Q');
      expect(line.variantAttributes!['size'], 2);
      expect(line.productSlug, 'suzani');
    },
  );

  test('unknown statuses degrade instead of failing', () async {
    final json = _order([
      _group([_line(status: 'teleported')], status: 'lost'),
    ])..['status'] = 'mystery';
    final order = OrderRead.fromJson(json);
    expect(order.status, OrderStatus.unknown);
    expect(order.groups.single.status, OrderShopGroupStatus.unknown);
    expect(order.groups.single.lines.single.status, OrderLineStatus.unknown);
  });

  test('orders list: status filter, paging and total header', () async {
    final adapter = _Adapter(
      200,
      [_order([])],
      headers: {
        'x-total-count': ['37'],
      },
    );
    final page = await OrderRepository(_dio(adapter)).orders(
      statuses: [OrderStatus.paid, OrderStatus.completed],
      skip: 50,
      limit: 25,
    );
    expect(page.total, 37);
    expect(adapter.request.uri.query, contains('status=paid&status=completed'));
    expect(adapter.request.uri.query, contains('skip=50'));
    expect(adapter.request.uri.query, contains('limit=25'));
  });

  test('cancel: only pending/confirmed groups can be cancelled', () async {
    expect(
      OrderShopGroupRead.fromJson(_group([], status: 'pending')).canCancel,
      isTrue,
    );
    expect(
      OrderShopGroupRead.fromJson(_group([], status: 'confirmed')).canCancel,
      isTrue,
    );
    expect(
      OrderShopGroupRead.fromJson(_group([], status: 'preparing')).canCancel,
      isFalse,
    );

    final adapter = _Adapter(200, _group([], status: 'cancelled'));
    final group = await OrderRepository(_dio(adapter))
        .cancelGroup(9, 3, reason: ' changed my mind ');
    expect(adapter.request.data, {'reason': 'changed my mind'});
    expect(group.status, OrderShopGroupStatus.cancelled);
  });

  test('pickup status: parsed, and a 404 means still on the way', () async {
    final ok = await OrderRepository(
      _dio(
        _Adapter(200, {
          'order_shop_group_id': 3,
          'pickup_point_id': 5,
          'holding_status': 'partially_collected',
          'arrived_at': '2026-09-10T08:00:00Z',
          'collection_deadline': '2026-09-17T08:00:00Z',
          'items': [
            {
              'order_line_id': 1,
              'quantity': 2,
              'quantity_collected': 1,
              'status': 'holding',
            },
          ],
        }),
      ),
    ).pickupStatus(9, 3);
    expect(ok!.holdingStatus, PickupHoldingStatus.partiallyCollected);
    expect(ok.collectionDeadline, DateTime.utc(2026, 9, 17, 8));
    expect(ok.items.single.quantityCollected, 1);

    final missing = await OrderRepository(
      _dio(_Adapter(404, {'detail': 'Not at the point yet'})),
    ).pickupStatus(9, 3);
    expect(missing, isNull);

    await expectLater(
      OrderRepository(_dio(_Adapter(500, {}))).pickupStatus(9, 3),
      throwsA(isA<DioException>()),
    );
  });

  group('return state per line', () {
    test('no deadline (not delivered): nothing to offer', () {
      expect(_read(_line()).returnState(_now), ReturnState.none);
    });

    test('inside the window: can request; after it: none', () {
      expect(
        _read(_line(deadline: _future)).returnState(_now),
        ReturnState.canRequest,
      );
      expect(_read(_line(deadline: _past)).returnState(_now), ReturnState.none);
    });

    test('pending and escalated requests block a new one', () {
      for (final status in ['pending', 'escalated_to_admin']) {
        final line = _read(_line(deadline: _future, request: _request(status)));
        expect(line.returnState(_now), ReturnState.requested, reason: status);
      }
    });

    test(
      'rejected: escalate once, then final; a new request stays possible',
      () {
        final note = _request('rejected', note: 'Used item');
        expect(
          _read(_line(deadline: _future, request: note)).returnState(_now),
          ReturnState.rejectedCanEscalate,
        );
        final done = _request('rejected', escalatedAt: '2026-09-07T00:00:00Z');
        expect(
          _read(_line(deadline: _future, request: done)).returnState(_now),
          ReturnState.canRequest,
        );
        expect(
          _read(_line(deadline: _past, request: done)).returnState(_now),
          ReturnState.rejectedFinal,
        );
      },
    );

    test('line status drives the refund journey', () {
      expect(
        _read(_line(status: 'return_pending', deadline: _future))
            .returnState(_now),
        ReturnState.returnPending,
      );
      expect(
        _read(_line(status: 'returned_to_point')).returnState(_now),
        ReturnState.returnedToPoint,
      );
      expect(
        _read(_line(status: 'refunded')).returnState(_now),
        ReturnState.refunded,
      );
    });

    test('return point shows only while return_pending', () {
      final line = _read(
        _line(
          status: 'return_pending',
          request: {..._request('approved'), 'return_point': _point},
        ),
      );
      expect(line.refundRequest!.returnPoint!.name, 'Chilonzor point');
    });
  });

  group('refund request', () {
    test('body has no amount; blank text and no photos become null', () async {
      final adapter = _Adapter(201, _full(status: 'pending'));
      final refund = await OrderRepository(_dio(adapter)).requestRefund(
        1,
        reasonCode: RefundReasonCode.notAsDescribed,
        reasonText: '  ',
      );
      expect(adapter.request.path, '/order-lines/1/refund-request');
      expect(adapter.request.data, {
        'reason_code': 'not_as_described',
        'reason_text': null,
        'evidence_keys': null,
      });
      expect(refund.refundAmount, '200000.00');
      expect(refund.evidence.single.url, 'http://signed/1');
    });

    test(
      'photo keys are sent; more than five is refused before the call',
      () async {
        final adapter = _Adapter(201, _full(status: 'pending'));
        final repo = OrderRepository(_dio(adapter));
        await repo.requestRefund(
          1,
          reasonCode: RefundReasonCode.defective,
          reasonText: ' cracked ',
          evidenceKeys: ['a', 'b'],
        );
        expect(adapter.request.data, {
          'reason_code': 'defective',
          'reason_text': 'cracked',
          'evidence_keys': ['a', 'b'],
        });
        expect(
          () => repo.requestRefund(
            1,
            reasonCode: RefundReasonCode.other,
            evidenceKeys: List.filled(6, 'k'),
          ),
          throwsArgumentError,
        );
      },
    );

    test('get and escalate hit the refund paths', () async {
      final adapter = _Adapter(
        200,
        _full(
          status: 'escalated_to_admin',
          escalatedAt: '2026-09-07T00:00:00Z',
        ),
      );
      final repo = OrderRepository(_dio(adapter));
      final r = await repo.escalate(40);
      expect(adapter.request.method, 'POST');
      expect(adapter.request.path, '/refund-requests/40/escalate');
      expect(r.status, RefundStatus.escalatedToAdmin);
      expect(r.escalatedAt, isNotNull);
      await repo.refund(40);
      expect(adapter.request.path, '/refund-requests/40');
    });
  });

  test('upload: purpose in the query, multipart file field', () async {
    final adapter = _Adapter(201, {
      'id': 1,
      'key': 'refunds/evidence/4/abc.webp',
      'url': 'http://signed/abc',
      'purpose': 'refund_evidence',
      'content_type': 'image/webp',
      'size_bytes': 1234,
      'width': 800,
      'height': 600,
      'created_at': '2026-10-01T10:00:00Z',
    });
    final upload = await UploadRepository(_dio(adapter)).uploadRefundEvidence(
      Uint8List.fromList([1, 2, 3]),
      filename: 'photo.jpg',
    );
    expect(adapter.request.path, '/uploads');
    expect(adapter.request.queryParameters, {'purpose': 'refund_evidence'});
    expect(adapter.request.data, isA<FormData>());
    expect((adapter.request.data as FormData).files.single.key, 'file');
    expect(upload.key, 'refunds/evidence/4/abc.webp');
    expect(upload.width, 800);
  });
}

Map<String, dynamic> _full({required String status, String? escalatedAt}) => {
  'id': 40,
  'order_line_id': 1,
  'requested_by': 'buyer',
  'requester_user_id': 4,
  'reason_code': 'not_as_described',
  'reason_text': null,
  'status': status,
  'refund_amount': '200000.00',
  'who_bears_cost': null,
  'evidence_urls': null,
  'resolved_by': null,
  'resolved_at': null,
  'escalated_at': escalatedAt,
  'resolution_note': null,
  'point_received_at': null,
  'created_at': '2026-09-05T10:00:00Z',
  'evidence': [
    {'key': 'k1', 'url': 'http://signed/1'},
  ],
};
