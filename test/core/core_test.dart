import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_app/core/api/api_error.dart';
import 'package:market_app/core/api/endpoints.dart';
import 'package:market_app/core/format.dart';

DioException _error(int status, Object? data) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: data,
    ),
  );
}

void main() {
  group('format', () {
    test('money per locale', () {
      expect(formatMoney('15000.00', 'uz-Latn-UZ'), '15 000 soʻm');
      expect(formatMoney('15000.00', 'ru'), '15 000 сум');
      expect(formatMoney('1250000', 'en-US'), '1,250,000 UZS');
    });

    test('toTiyin has no float error', () {
      expect(toTiyin('125000.00'), 12500000);
      expect(toTiyin('0.29'), 29);
      expect(toTiyin('19.9'), 1990);
      expect(sumMoney(['0.10', '0.20']), 30);
    });

    test('small and negative numbers', () {
      expect(formatNumber(999, 'uz'), '999');
      expect(formatNumber(-1500, 'en'), '-1,500');
    });
  });

  group('api errors', () {
    test('string detail is shown, others fall back', () {
      expect(apiErrorMessage(_error(400, {'detail': 'Nope'}), 'fb'), 'Nope');
      expect(
        apiErrorMessage(
          _error(422, {
            'detail': [
              {'msg': 'x'},
            ],
          }),
          'fb',
        ),
        'fb',
      );
      expect(apiErrorMessage(StateError('x'), 'fb'), 'fb');
    });

    test('status helpers and retry policy', () {
      expect(isUnauthorized(_error(401, null)), isTrue);
      expect(isNotFound(_error(404, null)), isTrue);
      expect(isRetryable(_error(400, null)), isFalse);
      expect(isRetryable(_error(503, null)), isTrue);
    });
  });

  test('endpoints encode slugs', () {
    expect(CatalogEndpoints.shopBySlug('a b'), '/shops/by-slug/a%20b');
    expect(OrderEndpoints.cancelGroup(1, 2), '/orders/1/groups/2/cancel');
  });
}
