import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/endpoints.dart';
import '../../../core/api/providers.dart';
import '../../catalog/data/common.dart';
import 'checkout.dart';

/// Login required. One order per checkout, collected at one pickup point. Errors other
/// than `price_changed` are `DioException`s: show them with `apiErrorMessage` (a string
/// `detail`, e.g. "This pickup point isn't available - choose another one", is safe to
/// show as is).
class CheckoutRepository {
  const CheckoutRepository(this._dio);

  final Dio _dio;

  /// Throws [PriceChangedException] on the structured `price_changed` 400.
  Future<CheckoutResponse> checkout({
    required Recipient recipient,
    required int pickupPointId,
    required PaymentMethod paymentMethod,
  }) async {
    try {
      final response = await _dio.post<Json>(
        OrderEndpoints.checkout,
        data: {
          'recipient': recipient.toJson(),
          'pickup_point_id': pickupPointId,
          'payment_method': paymentMethod.wire,
        },
      );
      return CheckoutResponse.fromJson(response.data!);
    } on DioException catch (error) {
      final changes = _priceChanges(error);
      if (changes != null) throw PriceChangedException(changes);
      rethrow;
    }
  }

  List<PriceChange>? _priceChanges(DioException error) {
    final data = error.response?.data;
    final detail = data is Map<String, dynamic> ? data['detail'] : null;
    if (error.response?.statusCode != 400 ||
        detail is! Map<String, dynamic> ||
        detail['error'] != 'price_changed') {
      return null;
    }
    return readList(detail['items'], PriceChange.fromJson);
  }
}

final checkoutRepositoryProvider = Provider<CheckoutRepository>(
  (ref) => CheckoutRepository(ref.watch(dioProvider)),
);
