import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/features/checkout/data/checkout.dart';
import 'package:market_app/features/checkout/data/checkout_repository.dart';
import 'package:market_app/features/logistics/data/pickup_point.dart';
import 'package:market_app/features/logistics/data/pickup_repository.dart';

Map<String, dynamic> _point({double? distance}) => {
  'id': 5,
  'name': 'Chilonzor point',
  'address': {
    'region': 'Toshkent',
    'district': 'Chilonzor',
    'street': '  Bunyodkor 1 ',
    'landmark': '',
  },
  'latitude': '41.275000',
  'longitude': '69.203000',
  'type': 'platform_operated',
  'capacity_units': null,
  'status': 'active',
  'operating_hours': {'mon': '9-18'},
  'contact_phone': '+998901234567',
  'region_id': 2,
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-01T10:00:00Z',
  'distance_km': ?distance,
};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object? body;
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
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_Adapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = adapter;

const _recipient = Recipient(
  fullName: ' Ali Valiyev ',
  phone: ' +998901234567',
  notes: '  ',
);

void main() {
  group('pickup points', () {
    test('parse address, coordinates, hours and nearby distance', () async {
      final adapter = _Adapter(200, [_point(distance: 1.5)]);
      final points = await PickupRepository(_dio(adapter))
          .nearby(lat: 41.3, lng: 69.2, radiusKm: 5);
      final point = points.single;
      expect(adapter.request.path, '/pickup-points/nearby');
      expect(adapter.request.queryParameters, {
        'lat': 41.3,
        'lng': 69.2,
        'radius_km': 5.0,
      });
      expect(point.latitude, 41.275);
      expect(point.distanceKm, 1.5);
      expect(point.status, PickupPointStatus.active);
      expect(point.operatingHours['mon'], '9-18');
      expect(point.address.display, 'Bunyodkor 1, Chilonzor, Toshkent');
      expect(point.address.landmark, isNull);
    });

    test('last-used: a point, or null when there is none', () async {
      final repo = PickupRepository(_dio(_Adapter(200, _point())));
      expect((await repo.lastUsed())!.id, 5);
      expect(
        await PickupRepository(_dio(_Adapter(200, null))).lastUsed(),
        isNull,
      );
    });

    test('regions and points by region', () async {
      final adapter = _Adapter(200, [
        {'id': 2, 'name': 'Toshkent', 'code': null},
      ]);
      final regions = await PickupRepository(_dio(adapter)).regions();
      expect(regions.single.name, 'Toshkent');

      final adapter2 = _Adapter(200, [_point()]);
      await PickupRepository(_dio(adapter2)).pickupPoints(regionId: 2);
      expect(adapter2.request.queryParameters, {'region_id': 2});
    });
  });

  group('checkout', () {
    test('sends the trimmed recipient, point and payment method', () async {
      final adapter = _Adapter(200, {
        'order_id': 9,
        'order_number': 'ORD-9',
        'payment_redirect_url': null,
      });
      final result = await CheckoutRepository(_dio(adapter)).checkout(
        recipient: _recipient,
        pickupPointId: 5,
        paymentMethod: PaymentMethod.cashOnDelivery,
      );
      expect(adapter.request.data, {
        'recipient': {
          'full_name': 'Ali Valiyev',
          'phone': '+998901234567',
          'notes': null,
        },
        'pickup_point_id': 5,
        'payment_method': 'cash_on_delivery',
      });
      expect(result.orderId, 9);
      expect(result.paymentRedirectUrl, isNull);
    });

    test('price_changed becomes a typed exception with old and new', () async {
      final repo = CheckoutRepository(
        _dio(
          _Adapter(400, {
            'detail': {
              'error': 'price_changed',
              'items': [
                {
                  'product_id': 12,
                  'variant_id': null,
                  'old_price': '45000.00',
                  'new_price': '48000.00',
                },
              ],
            },
          }),
        ),
      );
      await expectLater(
        repo.checkout(
          recipient: _recipient,
          pickupPointId: 5,
          paymentMethod: PaymentMethod.payme,
        ),
        throwsA(
          isA<PriceChangedException>().having(
            (e) => e.items.single.newPrice,
            'newPrice',
            '48000.00',
          ),
        ),
      );
    });

    test('a string-detail 400 stays a DioException', () async {
      final repo = CheckoutRepository(
        _dio(
          _Adapter(400, {
            'detail': "This pickup point isn't available — choose another one",
          }),
        ),
      );
      await expectLater(
        repo.checkout(
          recipient: _recipient,
          pickupPointId: 5,
          paymentMethod: PaymentMethod.click,
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('recipient validation mirrors the spec limits', () {
      expect(_recipient.invalidFields, isEmpty);
      const bad = Recipient(fullName: ' ', phone: '123');
      expect(bad.invalidFields, {
        RecipientField.fullName,
        RecipientField.phone,
      });
      expect(PaymentMethod.parse('uzcard'), PaymentMethod.uzcard);
    });
  });
}
